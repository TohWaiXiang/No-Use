import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static String get userId => _auth.currentUser?.uid ?? '';

  // ── Register ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required int age,
    required double avgCycleLength,
    required double avgPeriodDuration,
    required int stressLevel,
    required double sleepHours,
    required int exerciseDays,
    required String fitnessLevel,
    double weightKg = 0.0,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(username);

      final data = {
        'uid': uid,
        'username': username.trim(),
        'email': email.trim(),
        'age': age,
        'avg_cycle_length': avgCycleLength,
        'avg_period_duration': avgPeriodDuration,
        'stress_level': stressLevel,
        'sleep_hours': sleepHours,
        'exercise_days': exerciseDays,
        'fitness_level': fitnessLevel,
        'weight_kg': weightKg,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _db.collection('users').doc(uid).set(data);

      // Cache locally
      await _cacheProfile({...data, 'uid': uid});

      return {'success': true, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _err(e.code)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Login ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      // Load profile from Firestore and cache locally
      final profile = await _loadFromFirestore(uid);
      if (profile != null) await _cacheProfile(profile);

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _err(e.code)};
    }
  }

  // ── Forgot password ──────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _err(e.code)};
    }
  }

  // ── Get profile — Firestore first, fallback to cache ─────────
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return _getCachedProfile();

      final profile = await _loadFromFirestore(uid);
      if (profile != null) {
        await _cacheProfile(profile);
        return profile;
      }
      return _getCachedProfile();
    } catch (_) {
      return _getCachedProfile();
    }
  }

  // ── Update profile — both Firestore and cache ────────────────
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final uid = currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update(data);
      }
      // Always update local cache too
      final prefs = await SharedPreferences.getInstance();
      for (final key in data.keys) {
        final v = data[key];
        if (v is String) prefs.setString(key, v);
        if (v is int) prefs.setInt(key, v);
        if (v is double) prefs.setDouble(key, v);
        if (v is bool) prefs.setBool(key, v);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Sign out ─────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Every users/{uid} subcollection written by the app. Firestore doesn't
  // cascade-delete subcollections when the parent doc is deleted, so each
  // one must be wiped explicitly before the account is considered gone.
  static const List<String> _userSubcollections = [
    'period_history',
    'symptom_logs',
    'cycle_logs',
    'medication_logs',
    'predictions',
    'chat_logs',
    'alerts',
    'profile_history',
  ];

  // ── Delete account ──────────────────────────────────────────
  // Firebase requires a recent login to delete the Auth user, so we
  // reauthenticate with the supplied password first. Firestore data must be
  // wiped *before* the Auth user is deleted, since the security rules key
  // off request.auth.uid and that stops existing the moment delete() runs.
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'No signed-in user.'};
    }
    final uid = user.uid;

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email ?? '', password: password),
      );

      final userDoc = _db.collection('users').doc(uid);
      for (final name in _userSubcollections) {
        await _deleteCollection(userDoc.collection(name));
      }
      await userDoc.delete();

      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _err(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'Failed to delete account: $e'};
    }
  }

  static Future<void> _deleteCollection(CollectionReference ref) async {
    const chunkSize = 400; // stay under Firestore's 500-write batch limit
    final docs = await ref.get();
    for (var i = 0; i < docs.docs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final doc in docs.docs.skip(i).take(chunkSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ── Private helpers ──────────────────────────────────────────
  static Future<Map<String, dynamic>?> _loadFromFirestore(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return doc.data();
    return null;
  }

  static Future<void> _cacheProfile(Map<String, dynamic> p) async {
    final prefs = await SharedPreferences.getInstance();
    if (p['uid'] != null) prefs.setString('uid', p['uid']);
    if (p['username'] != null) prefs.setString('username', p['username']);
    if (p['email'] != null) prefs.setString('user_email', p['email']);
    if (p['age'] != null) prefs.setInt('user_age', p['age']);
    if (p['avg_cycle_length'] != null) {
      prefs.setDouble(
        'avg_cycle_length',
        (p['avg_cycle_length'] as num).toDouble(),
      );
    }
    if (p['avg_period_duration'] != null) {
      prefs.setDouble(
        'avg_period_duration',
        (p['avg_period_duration'] as num).toDouble(),
      );
    }
    if (p['stress_level'] != null) {
      prefs.setInt('stress_level', p['stress_level']);
    }
    if (p['sleep_hours'] != null) {
      prefs.setDouble('sleep_hours', (p['sleep_hours'] as num).toDouble());
    }
    if (p['exercise_days'] != null) {
      prefs.setInt('exercise_days', p['exercise_days']);
    }
    if (p['fitness_level'] != null) {
      prefs.setString('fitness_level', p['fitness_level']);
    }
    if (p['weight_kg'] != null) {
      prefs.setDouble('weight_kg', (p['weight_kg'] as num).toDouble());
    }
  }

  static Future<Map<String, dynamic>?> _getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid == null || uid.isEmpty) return null;
    return {
      'uid': uid,
      'username': prefs.getString('username') ?? 'User',
      'email': prefs.getString('user_email') ?? '',
      'age': prefs.getInt('user_age') ?? 25,
      'avg_cycle_length': prefs.getDouble('avg_cycle_length') ?? 28.0,
      'avg_period_duration': prefs.getDouble('avg_period_duration') ?? 5.0,
      'stress_level': prefs.getInt('stress_level') ?? 2,
      'sleep_hours': prefs.getDouble('sleep_hours') ?? 7.0,
      'exercise_days': prefs.getInt('exercise_days') ?? 3,
      'fitness_level': prefs.getString('fitness_level') ?? 'Beginner',
      'weight_kg': prefs.getDouble('weight_kg') ?? 0.0,
    };
  }

  static String _err(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again, then retry.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
