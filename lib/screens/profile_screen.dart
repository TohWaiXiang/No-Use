import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = 'User';
  String _email = '—';
  String _age = '—';
  String _cycleLength = '28';
  String _periodDur = '5';
  String _fitness = 'Beginner';
  int _stressLevel = 2;
  double _sleepHours = 7.0;
  int _exerciseDays = 3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final profile = await AuthService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _username = profile['username'] ?? 'User';
        _email = profile['email'] ?? '—';
        _age = (profile['age'] ?? '—').toString();
        _cycleLength = (profile['avg_cycle_length'] ?? 28).toString();
        _periodDur = (profile['avg_period_duration'] ?? 5).toString();
        _fitness = profile['fitness_level'] ?? 'Beginner';
        _stressLevel = profile['stress_level'] ?? 2;
        _sleepHours = (profile['sleep_hours'] ?? 7.0).toDouble();
        _exerciseDays = profile['exercise_days'] ?? 3;
      });
    }
    setState(() => _loading = false);
  }

  void _showEditField(
    String title,
    String current,
    ValueChanged<String> onSave, {
    TextInputType keyboard = TextInputType.text,
  }) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit $title',
          style: const TextStyle(
            color: Color(0xFF3C3489),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter $title',
            filled: true,
            fillColor: const Color(0xFFF4F5FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF7F77DD)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSave(ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F77DD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveField(String key, dynamic value) async {
    // Update the current profile value (existing behaviour)
    await AuthService.updateProfile({key: value});
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);

    // Also save as a new historical record in Firestore
    await _saveProfileHistory(key, value);

    _showSnack('$key updated successfully.');
  }

  /// Saves every profile field change as a new dated record under
  /// users/{uid}/profile_history so changes over time can be tracked.
  Future<void> _saveProfileHistory(String key, dynamic value) async {
    final uid = AuthService.userId;
    if (uid.isEmpty) return;
    try {
      final now = DateTime.now();
      final dateStr = now.toIso8601String().split('T')[0];
      final docId = '${dateStr}_$key';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile_history')
          .doc(docId)
          .set({
            'field': key,
            'value': value,
            'date': dateStr,
            'recorded_at': now.toIso8601String(),
            // Snapshot of all related health metrics at the time of this change,
            // useful for tracking trends in the ML model later.
            'snapshot': {
              'cycle_length': double.tryParse(_cycleLength) ?? 28.0,
              'period_duration': double.tryParse(_periodDur) ?? 5.0,
              'stress_level': _stressLevel,
              'sleep_hours': _sleepHours,
              'exercise_days': _exerciseDays,
              'fitness_level': _fitness,
            },
          });
      print('profile_history saved: $docId');
    } catch (e) {
      print('Firestore profile_history save error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF7F77DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _stressLabel(int v) {
    switch (v) {
      case 1:
        return 'Very Low';
      case 2:
        return 'Low';
      case 3:
        return 'Moderate';
      case 4:
        return 'High';
      case 5:
        return 'Very High';
      default:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F5FB),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7F77DD)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Avatar header ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                color: const Color(0xFFEEEDFE),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F77DD),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showEditField('Name', _username, (v) {
                              setState(() => _username = v);
                              _saveField('username', v);
                              SharedPreferences.getInstance().then(
                                (p) => p.setString('username', v),
                              );
                            }),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF378ADD),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C3489),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statBox('$_cycleLength d', 'Cycle'),
                        _vDivider(),
                        _statBox('$_periodDur d', 'Period'),
                        _vDivider(),
                        _statBox(_fitness, 'Fitness'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Personal Info ─────────────────────────────────────
              _sectionLabel('Personal Information'),
              _editRow(
                Icons.person_outline,
                'Name',
                _username,
                onTap: () => _showEditField('Name', _username, (v) {
                  setState(() => _username = v);
                  _saveField('username', v);
                  SharedPreferences.getInstance().then(
                    (p) => p.setString('username', v),
                  );
                }),
              ),
              _editRow(
                Icons.cake_outlined,
                'Age',
                _age,
                onTap: () => _showEditField('Age', _age, (v) {
                  setState(() => _age = v);
                  _saveField('age', int.tryParse(v) ?? 25);
                }, keyboard: TextInputType.number),
              ),

              const SizedBox(height: 8),

              // ── Cycle Settings ────────────────────────────────────
              _sectionLabel('Cycle Settings'),
              _editRow(
                Icons.loop,
                'Cycle Length',
                '$_cycleLength days',
                onTap: () => _showEditField('Cycle Length', _cycleLength, (v) {
                  setState(() => _cycleLength = v);
                  _saveField('avg_cycle_length', double.tryParse(v) ?? 28.0);
                }, keyboard: TextInputType.number),
              ),
              _editRow(
                Icons.water_drop_outlined,
                'Period Duration',
                '$_periodDur days',
                onTap: () => _showEditField('Period Duration', _periodDur, (v) {
                  setState(() => _periodDur = v);
                  _saveField('avg_period_duration', double.tryParse(v) ?? 5.0);
                }, keyboard: TextInputType.number),
              ),

              const SizedBox(height: 8),

              // ── Health Profile ────────────────────────────────────
              _sectionLabel('Health Profile'),

              // Stress level
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.psychology_outlined,
                            color: Color(0xFF7F77DD),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Stress Level',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _stressLabel(_stressLevel),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7F77DD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _stressLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: const Color(0xFF7F77DD),
                      inactiveColor: const Color(0xFFEEEDFE),
                      onChanged: (v) {
                        setState(() => _stressLevel = v.round());
                      },
                      onChangeEnd: (v) {
                        _saveField('stress_level', v.round());
                      },
                    ),
                  ],
                ),
              ),

              // Sleep hours
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.bedtime_outlined,
                            color: Color(0xFF7F77DD),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Sleep Hours / Night',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_sleepHours.toStringAsFixed(1)} hrs',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7F77DD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _sleepHours,
                      min: 4,
                      max: 12,
                      divisions: 16,
                      activeColor: const Color(0xFF378ADD),
                      inactiveColor: const Color(0xFFE6F1FB),
                      onChanged: (v) {
                        setState(
                          () =>
                              _sleepHours = double.parse(v.toStringAsFixed(1)),
                        );
                      },
                      onChangeEnd: (v) {
                        _saveField(
                          'sleep_hours',
                          double.parse(v.toStringAsFixed(1)),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Exercise days
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.directions_run,
                            color: Color(0xFF7F77DD),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Exercise Days / Week',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(8, (i) {
                        final sel = i == _exerciseDays;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _exerciseDays = i);
                            _saveField('exercise_days', i);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF7F77DD)
                                  : const Color(0xFFF4F5FB),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF7F77DD)
                                    : const Color(0xFFEEEDFE),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: sel ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Fitness level
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.self_improvement,
                            color: Color(0xFF7F77DD),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Fitness Level',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C2C2A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Beginner', 'Intermediate', 'Advanced'].map((
                        f,
                      ) {
                        final sel = _fitness == f;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _fitness = f);
                              _saveField('fitness_level', f);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF7F77DD)
                                    : const Color(0xFFF4F5FB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF7F77DD)
                                      : const Color(0xFFEEEDFE),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: sel ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Account ───────────────────────────────────────────
              _sectionLabel('Account'),
              _navRow(
                Icons.settings_outlined,
                'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _navRow(Icons.help_outline, 'Help & Support', onTap: () {}),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await AuthService.signOut();
                      if (!mounted) return;
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFAFA9EC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(color: Color(0xFF7F77DD), fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3C3489),
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );

  Widget _vDivider() =>
      Container(height: 32, width: 0.5, color: const Color(0xFFAFA9EC));

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _editRow(
    IconData icon,
    String title,
    String value, {
    required VoidCallback onTap,
  }) => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 1),
    child: ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEDFE),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: const Color(0xFF7F77DD), size: 17),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: Color(0xFF2C2C2A)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined, color: Colors.grey, size: 15),
        ],
      ),
      onTap: onTap,
    ),
  );

  Widget _navRow(IconData icon, String title, {required VoidCallback onTap}) =>
      Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        child: ListTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDFE),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFF7F77DD), size: 17),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2C2C2A)),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.grey,
            size: 18,
          ),
          onTap: onTap,
        ),
      );
}
