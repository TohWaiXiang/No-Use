import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and manages the app's real local device reminders (period,
/// ovulation, daily wellness check-in and daily AI insight tip), persists
/// which of them the user has enabled, and mirrors each one into
/// users/{uid}/alerts so the in-app Alerts tab reflects real reminders
/// instead of a mock list.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _defaults = {
    'notif_period': true,
    'notif_wellness': true,
    'notif_ovulation': true,
    'notif_ai': false,
  };

  static const _idPeriod = 1;
  static const _idOvulation = 2;
  static const _idWellness = 3;
  static const _idAi = 4;

  static const _keyPeriodDate = 'predicted_period_date';
  static const _keyOvulationDate = 'predicted_ovulation_date';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Sets up the plugin and timezone database. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  /// Requests OS-level notification permission (Android 13+ runtime
  /// permission and exact-alarm permission). No-op on platforms that
  /// don't require it.
  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<Map<String, bool>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final entry in _defaults.entries)
        entry.key: prefs.getBool(entry.key) ?? entry.value,
    };
  }

  Future<void> setPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await _applyPreference(key, value);
  }

  Future<void> _applyPreference(String key, bool value) async {
    switch (key) {
      case 'notif_period':
        value ? await _reschedulePeriodReminder() : await _plugin.cancel(_idPeriod);
        break;
      case 'notif_ovulation':
        value ? await _rescheduleOvulationReminder() : await _plugin.cancel(_idOvulation);
        break;
      case 'notif_wellness':
        value ? await scheduleDailyWellnessReminder() : await _plugin.cancel(_idWellness);
        break;
      case 'notif_ai':
        value ? await scheduleDailyAiTip() : await _plugin.cancel(_idAi);
        break;
    }
  }

  /// Call whenever a new cycle prediction is computed so the period and
  /// ovulation reminders track the latest predicted dates.
  Future<void> updatePredictedDates({
    required DateTime periodStart,
    required DateTime ovulationDay,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPeriodDate, periodStart.toIso8601String());
    await prefs.setString(_keyOvulationDate, ovulationDay.toIso8601String());

    final active = await getPreferences();
    if (active['notif_period'] == true) await _reschedulePeriodReminder();
    if (active['notif_ovulation'] == true) await _rescheduleOvulationReminder();
  }

  /// Re-applies whichever reminders are currently enabled. Call at app
  /// startup so schedules survive app restarts / cleared alarm state.
  Future<void> rescheduleEnabledReminders() async {
    final active = await getPreferences();
    for (final entry in active.entries) {
      if (entry.value) await _applyPreference(entry.key, true);
    }
  }

  Future<void> _reschedulePeriodReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final periodStart = DateTime.tryParse(
      prefs.getString(_keyPeriodDate) ?? '',
    );
    if (periodStart == null) return;
    final reminderDate = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day - 2,
      9,
    );
    const title = 'Period starting soon';
    const body =
        'Your period is estimated to begin in 2 days. Stock up on supplies and take it easy.';
    final scheduled = await _scheduleAt(
      id: _idPeriod,
      title: title,
      body: body,
      date: reminderDate,
    );
    if (scheduled) {
      await _recordAlert(
        id: 'period_${_dateKey(periodStart)}',
        title: title,
        body: body,
        tag: 'Cycle',
        time: reminderDate,
      );
    }
  }

  Future<void> _rescheduleOvulationReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final ovulation = DateTime.tryParse(
      prefs.getString(_keyOvulationDate) ?? '',
    );
    if (ovulation == null) return;
    final reminderDate = DateTime(
      ovulation.year,
      ovulation.month,
      ovulation.day - 1,
      9,
    );
    const title = 'Fertile window alert';
    const body =
        'Your ovulation day is approaching — your fertile window is closing soon.';
    final scheduled = await _scheduleAt(
      id: _idOvulation,
      title: title,
      body: body,
      date: reminderDate,
    );
    if (scheduled) {
      await _recordAlert(
        id: 'ovulation_${_dateKey(ovulation)}',
        title: title,
        body: body,
        tag: 'Cycle',
        time: reminderDate,
      );
    }
  }

  Future<void> scheduleDailyWellnessReminder() async {
    const title = 'Wellness check-in';
    const body = "Take a moment to log today's symptoms and mood.";
    final scheduled = await _scheduleDaily(
      id: _idWellness,
      title: title,
      body: body,
      hour: 19,
      minute: 30,
    );
    await _recordAlert(
      id: 'wellness_${_dateKey(scheduled)}',
      title: title,
      body: body,
      tag: 'Wellness',
      time: scheduled,
    );
  }

  Future<void> scheduleDailyAiTip() async {
    const title = 'Your daily insight';
    const body = 'Luna has a new personalised health tip ready for you.';
    final scheduled = await _scheduleDaily(
      id: _idAi,
      title: title,
      body: body,
      hour: 9,
      minute: 0,
    );
    await _recordAlert(
      id: 'ai_${_dateKey(scheduled)}',
      title: title,
      body: body,
      tag: 'Insight',
      time: scheduled,
    );
  }

  /// Returns true if a notification was actually (re)armed for [date]. False
  /// (and any stale alarm cancelled) if [date] has already passed — matches
  /// the OS notification, which likewise never fires for a past time.
  Future<bool> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    final scheduled = tz.TZDateTime.from(date, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      await _plugin.cancel(id);
      return false;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return true;
  }

  /// Returns the resolved fire time (today, or tomorrow if [hour]:[minute]
  /// has already passed today) so callers can mirror it into an alert.
  Future<DateTime> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return scheduled;
  }

  /// Upserts users/{uid}/alerts/{id} so the Alerts tab shows this reminder.
  /// [id] is deterministic per real event (e.g. the predicted period date),
  /// so re-scheduling the same event is idempotent and never spawns
  /// duplicates, and re-tapping doesn't reset a previously-read alert.
  /// Best-effort: not signed in, or a Firestore error, just skips silently —
  /// the OS-level reminder above is unaffected either way.
  Future<void> _recordAlert({
    required String id,
    required String title,
    required String body,
    required String tag,
    required DateTime time,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alerts')
          .doc(id);
      final snap = await ref.get();
      final content = {
        'title': title,
        'body': body,
        'tag': tag,
        'time': Timestamp.fromDate(time),
      };
      if (snap.exists) {
        await ref.update(content);
      } else {
        await ref.set({...content, 'read': false, 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      // Alerts tab just won't show this one; the device reminder still fires.
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'luna_reminders',
      'Luna Reminders',
      channelDescription:
          'Period, ovulation, wellness and AI insight reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
