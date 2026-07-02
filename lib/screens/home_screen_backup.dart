import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _username = 'User';

  DateTime? _periodStart;
  DateTime? _periodEnd;
  bool _isSelectingPeriod = false;
  List<Map<String, dynamic>> _periodHistory = [];

  List<Map<String, dynamic>> _symptomLogs = [];
  List<Map<String, dynamic>> _medicationLogs = [];

  // ── ML prediction results ─────────────────────────────────────────
  String _nextPeriod = '—';
  String _fertileWindow = '—';
  String _ovulationDay = '—';
  String _cycleLength = '—';
  String _currentPhase = '—';
  String _phaseDesc = 'Log your period to generate AI predictions.';
  int _daysUntilPeriod = -1;
  bool _loadingPrediction = false;
  List<DateTime> _predictedDays = [];

  static final List<Map<String, dynamic>> _availableSymptoms = [
    {'name': 'Cramps', 'icon': Icons.sick_outlined},
    {'name': 'Headache', 'icon': Icons.psychology_outlined},
    {'name': 'Bloating', 'icon': Icons.bubble_chart_outlined},
    {'name': 'Fatigue', 'icon': Icons.battery_alert_outlined},
    {'name': 'Mood swings', 'icon': Icons.mood_bad_outlined},
    {'name': 'Back pain', 'icon': Icons.accessibility_outlined},
    {'name': 'Breast tenderness', 'icon': Icons.favorite_border},
    {'name': 'Nausea', 'icon': Icons.sick},
    {'name': 'Spotting', 'icon': Icons.water_drop_outlined},
    {'name': 'Insomnia', 'icon': Icons.bedtime_outlined},
    {'name': 'Anxiety', 'icon': Icons.warning_amber_outlined},
    {'name': 'Heavy flow', 'icon': Icons.opacity},
    {'name': 'Light flow', 'icon': Icons.water_outlined},
    {'name': 'Acne', 'icon': Icons.face_outlined},
    {'name': 'Food cravings', 'icon': Icons.restaurant_outlined},
  ];

  static const List<String> _moodOptions = [
    '😊Happy',
    '😢 Sad',
    '😤 Irritable',
    '😰 Anxious',
    '😌 Calm',
    '😴 Tired',
    '🤩 Energetic',
    '😔 Depressed',
  ];

  static const List<String> _flowOptions = [
    'Light',
    'Medium',
    'Heavy',
    'Spotting',
    'None',
  ];

  List<DateTime> get _periodDays {
    final List<DateTime> days = [];
    for (final entry in _periodHistory) {
      DateTime d = _parseDate(entry['start']);
      final end = _parseDate(entry['end']);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
    }
    if (_periodStart != null) {
      if (_periodEnd != null) {
        DateTime d = _periodStart!;
        while (!d.isAfter(_periodEnd!)) {
          days.add(d);
          d = d.add(const Duration(days: 1));
        }
      } else {
        days.add(_periodStart!);
      }
    }
    return days;
  }

  DateTime _parseDate(String s) => DateTime.parse(s);

  bool _dateAlreadySaved(DateTime d) {
    for (final entry in _periodHistory) {
      final start = _parseDate(entry['start']);
      final end = _parseDate(entry['end']);
      if (!d.isBefore(start) && !d.isAfter(end)) return true;
    }
    return false;
  }

  int? _findPeriodIndex(DateTime d) {
    for (int i = 0; i < _periodHistory.length; i++) {
      final start = _parseDate(_periodHistory[i]['start']);
      final end = _parseDate(_periodHistory[i]['end']);
      if (!d.isBefore(start) && !d.isAfter(end)) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? 'User';
    setState(() => _username = name);

    final uid = AuthService.userId;
    if (uid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;

      // Load period history from Firestore
      final periodSnap = await db
          .collection('users')
          .doc(uid)
          .collection('period_history')
          .orderBy('start')
          .get();
      final history = periodSnap.docs
          .map((d) => Map<String, dynamic>.from(d.data()..['id'] = d.id))
          .toList();

      // Load symptom logs from Firestore
      final symSnap = await db
          .collection('users')
          .doc(uid)
          .collection('symptom_logs')
          .orderBy('saved_at', descending: true)
          .get();
      final symLogs = symSnap.docs
          .map((d) => Map<String, dynamic>.from(d.data()))
          .toList();

      // Load medication logs from Firestore
      final medSnap = await db
          .collection('users')
          .doc(uid)
          .collection('medication_logs')
          .orderBy('saved_at', descending: true)
          .get();
      final medLogs = medSnap.docs
          .map((d) => Map<String, dynamic>.from(d.data()))
          .toList();

      setState(() {
        _periodHistory = history;
        _symptomLogs = symLogs;
        _medicationLogs = medLogs;
      });

      if (history.isNotEmpty) _fetchPrediction();
    } catch (e) {
      // Fallback to local cache
      final raw = prefs.getString('period_history_v2') ?? '[]';
      final List decoded = jsonDecode(raw);
      setState(() {
        _periodHistory = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
      if (_periodHistory.isNotEmpty) _fetchPrediction();
    }
  }

  // ── Save period history ───────────────────────────────────────────
  Future<void> _saveHistory() async {
    // Keep local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('period_history_v2', jsonEncode(_periodHistory));

    // Save to Firestore
    final uid = AuthService.userId;
    if (uid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final col = db.collection('users').doc(uid).collection('period_history');

      // Delete all existing docs first
      final existing = await col.get();
      final batch = db.batch();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      // Write all current entries
      for (final entry in _periodHistory) {
        // Use start date as document ID so updates overwrite correctly
        final docId = entry['start'].toString().replaceAll('-', '');
        batch.set(col.doc(docId), entry);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore save error: $e');
    }
  }

  Future<void> _saveSymptomLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('symptom_logs', jsonEncode(_symptomLogs));

    final uid = AuthService.userId;
    if (uid.isEmpty) return;
    final db = FirebaseFirestore.instance;

    if (_symptomLogs.isNotEmpty) {
      final latest = _symptomLogs.first;
      await db
          .collection('users')
          .doc(uid)
          .collection('symptom_logs')
          .add(latest);
    }
  }

  Future<void> _saveMedicationLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medication_logs', jsonEncode(_medicationLogs));

    final uid = AuthService.userId;
    if (uid.isEmpty) return;
    final db = FirebaseFirestore.instance;

    if (_medicationLogs.isNotEmpty) {
      final latest = _medicationLogs.first;
      await db
          .collection('users')
          .doc(uid)
          .collection('medication_logs')
          .add(latest);
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  PERIOD CRUD
  // ════════════════════════════════════════════════════════════════

  void _onDayTap(DateTime day) {
    final existingIndex = _findPeriodIndex(day);
    if (existingIndex != null && !_isSelectingPeriod) {
      _showPeriodEditDialog(existingIndex);
      return;
    }

    if (!_isSelectingPeriod) {
      if (_dateAlreadySaved(day)) {
        _showSnack('This date already has a period record.');
        return;
      }
      setState(() {
        _periodStart = day;
        _periodEnd = null;
        _isSelectingPeriod = true;
      });
      _showSnack('Start: ${_fmt(day)}  ·  Now tap the end date.');
    } else {
      DateTime start = _periodStart!;
      DateTime end = day;
      if (end.isBefore(start)) {
        final tmp = start;
        start = end;
        end = tmp;
      }

      // Check for duplicates in range
      DateTime check = start;
      bool hasDuplicate = false;
      while (!check.isAfter(end)) {
        if (_dateAlreadySaved(check)) {
          hasDuplicate = true;
          break;
        }
        check = check.add(const Duration(days: 1));
      }
      if (hasDuplicate) {
        _showSnack(
          'Range overlaps an existing record. Choose a different range.',
        );
        return;
      }
      setState(() {
        _periodStart = start;
        _periodEnd = end;
      });
      _confirmPeriodDialog();
    }
  }

  void _confirmPeriodDialog() {
    if (_periodStart == null || _periodEnd == null) return;
    final dur = _periodEnd!.difference(_periodStart!).inDays + 1;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Period',
          style: TextStyle(
            color: Color(0xFF3C3489),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dlgRow('Start', _fmt(_periodStart!)),
            const SizedBox(height: 6),
            _dlgRow('End', _fmt(_periodEnd!)),
            const SizedBox(height: 6),
            _dlgRow('Duration', '$dur days'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _periodStart = null;
                _periodEnd = null;
                _isSelectingPeriod = false;
              });
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _savePeriod();
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

  void _savePeriod() {
    final entry = {
      'start': _periodStart!.toIso8601String().split('T')[0],
      'end': _periodEnd!.toIso8601String().split('T')[0],
      'duration': _periodEnd!.difference(_periodStart!).inDays + 1,
      'notes': '',
    };
    setState(() {
      _periodHistory.add(entry);
      _periodHistory.sort(
        (a, b) => a['start'].toString().compareTo(b['start'].toString()),
      );
      _periodStart = null;
      _periodEnd = null;
      _isSelectingPeriod = false;
    });
    _saveHistory();
    _fetchPrediction();
    _showSnack('Period saved! Fetching AI prediction...');
  }

  void _showPeriodEditDialog(int index) {
    if (index < 0 || index >= _periodHistory.length) return;
    final entry = _periodHistory[index];
    DateTime start = _parseDate(entry['start']);
    DateTime end = _parseDate(entry['end']);
    final notesCtrl = TextEditingController(text: entry['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.edit_calendar,
                color: Color(0xFF7F77DD),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Edit Period Record',
                style: TextStyle(
                  color: Color(0xFF3C3489),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Start date
                _editDateTile(
                  label: 'Start date',
                  date: start,
                  onTap: () async {
                    final p = await _pickDate(
                      context,
                      start,
                      DateTime(2020),
                      DateTime.now(),
                    );
                    if (p != null) {
                      if (_isDateTakenByOther(p, index)) {
                        _showSnack('Overlaps another record.');
                        return;
                      }
                      setDlg(() {
                        start = p;
                        if (end.isBefore(start)) end = start;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                // End date
                _editDateTile(
                  label: 'End date',
                  date: end,
                  onTap: () async {
                    final p = await _pickDate(
                      context,
                      end,
                      start,
                      DateTime.now(),
                    );
                    if (p != null) {
                      if (_isRangeTakenByOther(start, p, index)) {
                        _showSnack('Overlaps another record.');
                        return;
                      }
                      setDlg(() => end = p);
                    }
                  },
                ),
                const SizedBox(height: 10),
                // Duration info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Duration: ${end.difference(start).inDays + 1} days',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF3C3489),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    hintText: 'e.g. heavy flow, cramps...',
                    filled: true,
                    fillColor: const Color(0xFFF4F5FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7F77DD)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _deletePeriodConfirm(index);
              },
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 16,
              ),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _periodHistory[index] = {
                    'start': start.toIso8601String().split('T')[0],
                    'end': end.toIso8601String().split('T')[0],
                    'duration': end.difference(start).inDays + 1,
                    'notes': notesCtrl.text.trim(),
                  };
                  _periodHistory.sort(
                    (a, b) =>
                        a['start'].toString().compareTo(b['start'].toString()),
                  );
                });
                _saveHistory();
                _fetchPrediction();
                _showSnack('Period updated.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePeriodConfirm(int index) {
    final entry = _periodHistory[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Period',
          style: TextStyle(
            color: Color(0xFF3C3489),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Delete the period from ${entry['start']} to ${entry['end']}?',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _periodHistory.removeAt(index));
              _saveHistory();
              if (_periodHistory.isEmpty) {
                setState(() {
                  _nextPeriod = '—';
                  _fertileWindow = '—';
                  _ovulationDay = '—';
                  _cycleLength = '—';
                  _currentPhase = '—';
                  _daysUntilPeriod = -1;
                  _predictedDays = [];
                  _phaseDesc = 'Log your period to generate AI predictions.';
                });
              } else {
                _fetchPrediction();
              }
              _showSnack('Period deleted.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMenstrualRecordsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'Menstrual Records',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C3489),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showSnack(
                          'Tap a date on the calendar to add a period.',
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F77DD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),
              Expanded(
                child: _periodHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No records yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap a date on the calendar to add your first period.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _periodHistory.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          // Show newest first
                          final idx = _periodHistory.length - 1 - i;
                          final entry = _periodHistory[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEDFE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF7F77DD),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${entry['start']}  →  ${entry['end']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C2C2A),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry['duration']} days',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7F77DD),
                                  ),
                                ),
                                if ((entry['notes'] ?? '').isNotEmpty)
                                  Text(
                                    entry['notes'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF7F77DD),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showPeriodEditDialog(idx);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deletePeriodConfirm(idx);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  LOG SYMPTOMS
  // ════════════════════════════════════════════════════════════════
  void _showLogSymptomsDialog() {
    final today = DateTime.now();
    List<String> selected = [];
    String selectedMood = '';
    String selectedFlow = '';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Log Symptoms',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmtShortFull(today),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
                Expanded(
                  child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Symptoms grid
                      const Text(
                        'Symptoms',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSymptoms.map((s) {
                          final isSelected = selected.contains(s['name']);
                          return GestureDetector(
                            onTap: () => setDlg(() {
                              if (isSelected) {
                                selected.remove(s['name']);
                              } else {
                                selected.add(s['name'] as String);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7F77DD)
                                    : const Color(0xFFF4F5FB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7F77DD)
                                      : const Color(0xFFEEEDFE),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    s['icon'] as IconData,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF7F77DD),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s['name'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF5F5E5A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Mood
                      const Text(
                        'Mood',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _moodOptions.map((m) {
                          final isSel = selectedMood == m;
                          return GestureDetector(
                            onTap: () => setDlg(() => selectedMood = m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF378ADD)
                                    : const Color(0xFFF4F5FB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF378ADD)
                                      : const Color(0xFFEEEDFE),
                                ),
                              ),
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSel
                                      ? Colors.white
                                      : const Color(0xFF5F5E5A),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Flow
                      const Text(
                        'Flow level',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: _flowOptions.map((f) {
                          final isSel = selectedFlow == f;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setDlg(() => selectedFlow = f),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF7F77DD)
                                      : const Color(0xFFF4F5FB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF7F77DD)
                                        : const Color(0xFFEEEDFE),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSel ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      const Text(
                        'Additional notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Any other symptoms or notes...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF4F5FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF7F77DD),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selected.isEmpty &&
                                selectedMood.isEmpty &&
                                selectedFlow.isEmpty) {
                              _showSnack(
                                'Please select at least one symptom, mood or flow.',
                              );
                              return;
                            }
                            Navigator.pop(context);
                            _saveSymptomLog(
                              date: today,
                              symptoms: selected,
                              mood: selectedMood,
                              flow: selectedFlow,
                              notes: notesCtrl.text.trim(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F77DD),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Symptoms',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveSymptomLog({
    required DateTime date,
    required List<String> symptoms,
    required String mood,
    required String flow,
    required String notes,
  }) async {
    final log = {
      'date': date.toIso8601String().split('T')[0],
      'symptoms': symptoms,
      'mood': mood,
      'flow': flow,
      'notes': notes,
      'saved_at': DateTime.now().toIso8601String(),
    };
    setState(() => _symptomLogs.insert(0, log));
    _saveSymptomLogs();

    // Save directly to Firestore under user's collection
    final uid = AuthService.userId;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cycle_logs')
            .add({
              'user_id': uid,
              'date': date.toIso8601String().split('T')[0],
              'symptoms': symptoms,
              'mood': mood,
              'flow': flow,
              'notes': notes,
              'stress_level': 2,
              'sleep_hours': 7.0,
              'saved_at': DateTime.now().toIso8601String(),
            });
      } catch (e) {
        debugPrint('Cycle log save error: $e');
      }
    }

    _showSnack('Symptoms saved for ${_fmtShortFull(date)}');
  }

  // ════════════════════════════════════════════════════════════════
  //  MEDICATION
  // ════════════════════════════════════════════════════════════════
  void _showMedicationDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    TimeOfDay? reminderTime;
    DateTime today = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Medication',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3489),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Medication name
                _medInput(
                  controller: nameCtrl,
                  hint: 'Medication name (e.g. Ibuprofen)',
                  icon: Icons.medication_outlined,
                ),
                const SizedBox(height: 10),

                // Dosage
                _medInput(
                  controller: dosageCtrl,
                  hint: 'Dosage (e.g. 400mg, 1 tablet)',
                  icon: Icons.science_outlined,
                ),
                const SizedBox(height: 10),

                // Reminder time
                GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (_, child) => Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF7F77DD),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (t != null) setDlg(() => reminderTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alarm_outlined,
                          color: Color(0xFF7F77DD),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          reminderTime == null
                              ? 'Set reminder time (optional)'
                              : 'Reminder: ${reminderTime!.format(context)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: reminderTime == null
                                ? Colors.grey
                                : const Color(0xFF3C3489),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Remarks
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Remarks (e.g. take after meals, for cramps)',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.notes_outlined,
                      color: Color(0xFF7F77DD),
                      size: 18,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4F5FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7F77DD)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) {
                        _showSnack('Please enter a medication name.');
                        return;
                      }
                      Navigator.pop(context);
                      _saveMedication(
                        date: today,
                        name: nameCtrl.text.trim(),
                        dosage: dosageCtrl.text.trim(),
                        reminderTime: reminderTime == null
                            ? ''
                            : reminderTime!.format(context),
                        remarks: remarksCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF378ADD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Medication',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveMedication({
    required DateTime date,
    required String name,
    required String dosage,
    required String reminderTime,
    required String remarks,
  }) {
    final log = {
      'date': date.toIso8601String().split('T')[0],
      'name': name,
      'dosage': dosage,
      'reminder': reminderTime,
      'remarks': remarks,
      'saved_at': DateTime.now().toIso8601String(),
    };
    setState(() => _medicationLogs.insert(0, log));
    _saveMedicationLogs();
    _showSnack('$name saved for ${_fmtShortFull(date)}');
  }

  // ════════════════════════════════════════════════════════════════
  //  BACKEND + ML
  // ════════════════════════════════════════════════════════════════
  Future<void> _postToBackend(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      await http
          .post(
            Uri.parse('http://192.168.0.10:8000$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> _fetchPrediction() async {
    if (_periodHistory.isEmpty) return;
    setState(() => _loadingPrediction = true);

    try {
      double totalCycle = 0, totalDuration = 0;
      for (int i = 0; i < _periodHistory.length; i++) {
        final s = _parseDate(_periodHistory[i]['start']);
        final e = _parseDate(_periodHistory[i]['end']);
        totalDuration += e.difference(s).inDays + 1;
        if (i > 0) {
          totalCycle += s
              .difference(_parseDate(_periodHistory[i - 1]['start']))
              .inDays;
        }
      }
      final avgDuration = totalDuration / _periodHistory.length;
      final avgCycle = _periodHistory.length > 1
          ? totalCycle / (_periodHistory.length - 1)
          : 28.0;

      final prefs = await SharedPreferences.getInstance();
      final age = prefs.getInt('user_age') ?? 25;
      final stress = prefs.getInt('stress_level') ?? 2;
      final sleep = prefs.getDouble('sleep_hours') ?? 7.0;
      final exercise = prefs.getInt('exercise_days') ?? 3;
      final lastStart = _periodHistory.last['start'] as String;

      final response = await http
          .post(
            Uri.parse('http://192.168.0.10:8000/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': prefs.getString('uid') ?? AuthService.userId,
              'avg_cycle_length': avgCycle,
              'avg_period_duration': avgDuration,
              'age': age,
              'stress_level': stress,
              'sleep_hours': sleep,
              'exercise_days': exercise,
              'last_period_start': lastStart,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applyPrediction(data, avgCycle, avgDuration);
      } else {
        _useFallback(avgCycle, avgDuration);
      }
    } catch (_) {
      double totalCycle = 0, totalDuration = 0;
      for (int i = 0; i < _periodHistory.length; i++) {
        final s = _parseDate(_periodHistory[i]['start']);
        final e = _parseDate(_periodHistory[i]['end']);
        totalDuration += e.difference(s).inDays + 1;
        if (i > 0) {
          totalCycle += s
              .difference(_parseDate(_periodHistory[i - 1]['start']))
              .inDays;
        }
      }
      final avg = _periodHistory.length > 1
          ? totalCycle / (_periodHistory.length - 1)
          : 28.0;
      _useFallback(avg, totalDuration / _periodHistory.length);
    }
  }

  void _applyPrediction(
    Map<String, dynamic> data,
    double avgCycle,
    double avgDuration,
  ) async {
    try {
      final isoKey = data['next_period_start_iso'] as String?;
      DateTime? nextStart;
      if (isoKey != null && isoKey.isNotEmpty) {
        nextStart = DateTime.parse(isoKey);
      } else {
        nextStart = _parseDate(
          _periodHistory.last['start'],
        ).add(Duration(days: avgCycle.round()));
      }
      final nextEnd = nextStart.add(Duration(days: avgDuration.round() - 1));
      final predicted = _buildRange(nextStart, nextEnd);
      final days = nextStart.difference(DateTime.now()).inDays;

      final nextPeriod =
          data['next_period_start']?.toString() ?? _fmt(nextStart);
      final fertileWindow = data['fertile_window']?.toString() ?? '—';
      final ovulationDay = data['ovulation_day']?.toString() ?? '—';
      final cycleLength =
          '${(data['predicted_cycle_length'] ?? avgCycle).toStringAsFixed(0)} days';
      final currentPhase = data['current_phase']?.toString() ?? '—';
      final phaseDesc =
          data['phase_description']?.toString() ?? 'Prediction updated.';

      setState(() {
        _nextPeriod = nextPeriod;
        _fertileWindow = fertileWindow;
        _ovulationDay = ovulationDay;
        _cycleLength = cycleLength;
        _currentPhase = currentPhase;
        _phaseDesc = phaseDesc;
        _daysUntilPeriod = days;
        _predictedDays = predicted;
        _loadingPrediction = false;
      });

      // Save to Firestore
      final uid = AuthService.userId;
      if (uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('predictions')
            .doc('latest')
            .set({
              'next_period': nextPeriod,
              'fertile_window': fertileWindow,
              'ovulation_day': ovulationDay,
              'cycle_length': cycleLength,
              'current_phase': currentPhase,
              'phase_description': phaseDesc,
              'days_until_period': days,
              'next_period_start_iso': nextStart.toIso8601String(),
              'next_period_end_iso': nextEnd.toIso8601String(),
              'avg_cycle_length': avgCycle,
              'avg_period_duration': avgDuration,
              'source': 'ml_backend',
              'updated_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (_) {
      _useFallback(avgCycle, avgDuration);
    }
  }

  void _useFallback(double avgCycle, double avgDuration) async {
    final lastStart = _parseDate(_periodHistory.last['start']);
    final nextStart = lastStart.add(Duration(days: avgCycle.round()));
    final nextEnd = nextStart.add(Duration(days: avgDuration.round() - 1));
    final ovulation = nextStart.subtract(const Duration(days: 14));
    final fertileStart = ovulation.subtract(const Duration(days: 5));
    final fertileEnd = ovulation.add(const Duration(days: 1));
    final today = DateTime.now();
    final cycleDay = today.difference(lastStart).inDays + 1;
    final days = nextStart.difference(today).inDays;

    String phase = 'Luteal';
    String desc = 'Progesterone rising. Prefer low-impact exercise.';
    if (cycleDay <= 5) {
      phase = 'Menstrual';
      desc = 'Your period is active. Rest and stay hydrated.';
    } else if (cycleDay <= 13) {
      phase = 'Follicular';
      desc = 'Energy rising. Good time for strength training.';
    } else if (cycleDay <= 16) {
      phase = 'Ovulation';
      desc = 'Peak fertility. Energy is at its highest.';
    }

    final nextPeriod = _fmt(nextStart);
    final fertileWindow = '${_fmtShort(fertileStart)} – ${_fmt(fertileEnd)}';
    final ovulationDay = _fmt(ovulation);
    final cycleLength = '${avgCycle.round()} days';

    setState(() {
      _nextPeriod = nextPeriod;
      _fertileWindow = fertileWindow;
      _ovulationDay = ovulationDay;
      _cycleLength = cycleLength;
      _currentPhase = phase;
      _phaseDesc = desc;
      _daysUntilPeriod = days;
      _predictedDays = _buildRange(nextStart, nextEnd);
      _loadingPrediction = false;
    });

    // Save fallback prediction to Firestore
    final uid = AuthService.userId;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('predictions')
            .doc('latest')
            .set({
              'next_period': nextPeriod,
              'fertile_window': fertileWindow,
              'ovulation_day': ovulationDay,
              'cycle_length': cycleLength,
              'current_phase': phase,
              'phase_description': desc,
              'days_until_period': days,
              'next_period_start_iso': nextStart.toIso8601String(),
              'next_period_end_iso': nextEnd.toIso8601String(),
              'avg_cycle_length': avgCycle,
              'avg_period_duration': avgDuration,
              'source': 'fallback',
              'updated_at': DateTime.now().toIso8601String(),
            });
      } catch (e) {
        debugPrint('Fallback prediction save error: $e');
      }
    }
  }

  List<DateTime> _buildRange(DateTime start, DateTime end) {
    final list = <DateTime>[];
    DateTime d = start;
    while (!d.isAfter(end)) {
      list.add(d);
      d = d.add(const Duration(days: 1));
    }
    return list;
  }

  // ════════════════════════════════════════════════════════════════
  //  CALENDAR HELPERS
  // ════════════════════════════════════════════════════════════════
  bool _isPeriod(DateTime d) => _periodDays.any(
    (p) => p.year == d.year && p.month == d.month && p.day == d.day,
  );

  bool _isPredicted(DateTime d) => _predictedDays.any(
    (p) => p.year == d.year && p.month == d.month && p.day == d.day,
  );

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isInSelection(DateTime d) {
    if (_periodStart == null) return false;
    if (_periodEnd == null) return _isSameDay(d, _periodStart!);
    return !d.isBefore(_periodStart!) && !d.isAfter(_periodEnd!);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isDateTakenByOther(DateTime d, int exclude) {
    for (int i = 0; i < _periodHistory.length; i++) {
      if (i == exclude) continue;
      final s = _parseDate(_periodHistory[i]['start']);
      final e = _parseDate(_periodHistory[i]['end']);
      if (!d.isBefore(s) && !d.isAfter(e)) return true;
    }
    return false;
  }

  bool _isRangeTakenByOther(DateTime start, DateTime end, int exclude) {
    DateTime c = start;
    while (!c.isAfter(end)) {
      if (_isDateTakenByOther(c, exclude)) return true;
      c = c.add(const Duration(days: 1));
    }
    return false;
  }

  void _prevMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  List<DateTime?> _buildCalendarDays() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final startWd = first.weekday % 7;
    final days = <DateTime?>[];
    for (int i = 0; i < startWd; i++) {
      days.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }
    return days;
  }

  Future<DateTime?> _pickDate(
    BuildContext ctx,
    DateTime init,
    DateTime first,
    DateTime last,
  ) async {
    return showDatePicker(
      context: ctx,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      builder: (_, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7F77DD),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
  }

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];

  // ── Formatters ────────────────────────────────────────────────────
  String _fmt(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtShort(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]}';
  }

  String _fmtShortFull(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF7F77DD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final calDays = _buildCalendarDays();

    // Greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                color: const Color(0xFFEEEDFE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $_username',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C3489),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSelectingPeriod
                          ? '📍 Tap the end date to complete logging'
                          : 'Tap a date to log · Tap a logged date to edit',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isSelectingPeriod
                            ? const Color(0xFF7F77DD)
                            : Colors.grey,
                      ),
                    ),
                    if (_daysUntilPeriod >= 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F77DD),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Period in ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$_daysUntilPeriod',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              ' days',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Selection banner ─────────────────────────────────
              if (_isSelectingPeriod)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F77DD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _periodEnd == null
                              ? 'Start: ${_fmt(_periodStart!)}  ·  Tap end date'
                              : 'Start: ${_fmt(_periodStart!)}  →  ${_fmt(_periodEnd!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _periodStart = null;
                          _periodEnd = null;
                          _isSelectingPeriod = false;
                        }),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Calendar ─────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEDFE)),
                ),
                child: Column(
                  children: [
                    // Month nav
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF7F77DD),
                            ),
                            onPressed: _prevMonth,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3C3489),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF7F77DD),
                            ),
                            onPressed: _nextMonth,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Day labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                            .map(
                              (d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Grid
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                        itemCount: calDays.length,
                        itemBuilder: (_, i) {
                          final day = calDays[i];
                          if (day == null) return const SizedBox();

                          final isPeriodDay = _isPeriod(day);
                          final isPredDay = _isPredicted(day);
                          final isTodayDay = _isToday(day);
                          final isInSel = _isInSelection(day);
                          final isStart =
                              _periodStart != null &&
                              _isSameDay(day, _periodStart!);
                          final isEnd =
                              _periodEnd != null &&
                              _isSameDay(day, _periodEnd!);
                          final isSaved = _dateAlreadySaved(day);

                          // Has symptom log
                          final dateStr = day.toIso8601String().split('T')[0];
                          final hasSymptom = _symptomLogs.any(
                            (s) => s['date'] == dateStr,
                          );

                          Color bgColor = Colors.transparent;
                          Color textColor = const Color(0xFF2C2C2A);
                          BoxBorder? border;

                          if (isPeriodDay) {
                            bgColor = const Color(0xFF7F77DD);
                            textColor = Colors.white;
                          } else if (isInSel) {
                            bgColor = isStart || isEnd
                                ? const Color(0xFF7F77DD)
                                : const Color(0xFFAFA9EC);
                            textColor = Colors.white;
                          } else if (isPredDay) {
                            bgColor = const Color(0xFFEEEDFE);
                            textColor = const Color(0xFF7F77DD);
                          }

                          if (isTodayDay) {
                            border = Border.all(
                              color: const Color(0xFF3C3489),
                              width: 2,
                            );
                            if (!isPeriodDay && !isInSel && !isPredDay) {
                              textColor = const Color(0xFF7F77DD);
                            }
                          }

                          return GestureDetector(
                            onTap: () => _onDayTap(day),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    shape: BoxShape.circle,
                                    border: border,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            (isPeriodDay ||
                                                isTodayDay ||
                                                isStart ||
                                                isEnd)
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                                // Edit dot on saved days
                                if (isSaved && !_isSelectingPeriod)
                                  Positioned(
                                    bottom: 1,
                                    right: 1,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF7F77DD),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Green dot = symptom logged
                                if (hasSymptom && !isPeriodDay)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF97C459),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Legend
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _legend(const Color(0xFF7F77DD), 'Period'),
                          _legend(
                            const Color(0xFFEEEDFE),
                            'Predicted',
                            textColor: const Color(0xFF7F77DD),
                          ),
                          _legend(const Color(0xFFAFA9EC), 'Selecting'),
                          _legend(const Color(0xFF97C459), 'Symptom'),
                          _legendOutline(const Color(0xFF3C3489), 'Today'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Menstrual Record CRUD card ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: GestureDetector(
                  onTap: _showMenstrualRecordsList,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEDFE)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEDFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.history_outlined,
                          color: Color(0xFF7F77DD),
                          size: 18,
                        ),
                      ),
                      title: const Text(
                        'Menstrual Records',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _periodHistory.isEmpty
                            ? 'No records yet — tap a calendar date to add'
                            : '${_periodHistory.length} record${_periodHistory.length == 1 ? '' : 's'} · tap to view & edit',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_periodHistory.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEDFE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_periodHistory.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7F77DD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Log buttons ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  children: [
                    _buildActionCard(
                      Icons.favorite_outline,
                      const Color(0xFFEEEDFE),
                      '+ Log Symptoms',
                      _symptomLogs.isEmpty
                          ? 'Track cramps, mood, flow & more'
                          : '${_symptomLogs.length} log${_symptomLogs.length == 1 ? '' : 's'} recorded',
                      _showLogSymptomsDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionCard(
                      Icons.medical_services_outlined,
                      const Color(0xFFE6F1FB),
                      '+ Medication',
                      _medicationLogs.isEmpty
                          ? 'Add medication with remarks'
                          : '${_medicationLogs.length} medication${_medicationLogs.length == 1 ? '' : 's'} logged',
                      _showMedicationDialog,
                    ),
                  ],
                ),
              ),

              // ── AI Prediction Result ──────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEDFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEDFE),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7F77DD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'AI Prediction Result',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C3489),
                            ),
                          ),
                          const Spacer(),
                          if (_loadingPrediction)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7F77DD),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (_periodHistory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5FB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEEEDFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Color(0xFF7F77DD),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Log at least one period on the calendar to see AI predictions.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F77DD),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _predRow(
                        Icons.calendar_today_outlined,
                        const Color(0xFFEEEDFE),
                        'Next Period',
                        _nextPeriod,
                        const Color(0xFF7F77DD),
                      ),
                      _divider(),
                      _predRow(
                        Icons.favorite_border,
                        const Color(0xFFE6F1FB),
                        'Fertile Window',
                        _fertileWindow,
                        const Color(0xFF378ADD),
                      ),
                      _divider(),
                      _predRow(
                        Icons.wb_sunny_outlined,
                        const Color(0xFFEEEDFE),
                        'Ovulation Day',
                        _ovulationDay,
                        const Color(0xFF7F77DD),
                      ),
                      _divider(),
                      _predRow(
                        Icons.loop,
                        const Color(0xFFE6F1FB),
                        'Cycle Length',
                        _cycleLength,
                        const Color(0xFF378ADD),
                      ),
                      _divider(),

                      // Phase chips
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Phase',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _phaseChip(
                                  'Menstrual',
                                  _currentPhase == 'Menstrual',
                                ),
                                const SizedBox(width: 6),
                                _phaseChip(
                                  'Follicular',
                                  _currentPhase == 'Follicular',
                                ),
                                const SizedBox(width: 6),
                                _phaseChip(
                                  'Ovulation',
                                  _currentPhase == 'Ovulation',
                                ),
                                const SizedBox(width: 6),
                                _phaseChip('Luteal', _currentPhase == 'Luteal'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F1FB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '💡 $_phaseDesc',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0C447C),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(Color color, String label, {Color? textColor}) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: textColor ?? Colors.grey),
      ),
    ],
  );

  Widget _legendOutline(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ],
  );

  Widget _buildActionCard(
    IconData icon,
    Color iconBg,
    String title,
    String sub,
    VoidCallback onTap,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEEDFE)),
    ),
    child: ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF7F77DD), size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    ),
  );

  Widget _predRow(
    IconData icon,
    Color iconBg,
    String label,
    String value,
    Color valueColor,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: valueColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Divider(
    height: 1,
    thickness: 0.5,
    color: Colors.grey.shade100,
    indent: 16,
    endIndent: 16,
  );

  Widget _phaseChip(String label, bool active) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7F77DD) : const Color(0xFFF4F5FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFF7F77DD) : const Color(0xFFEEEDFE),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF888780),
          ),
        ),
      ),
    ),
  );

  Widget _dlgRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF3C3489),
        ),
      ),
    ],
  );

  Widget _editDateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEDFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 15, color: Color(0xFF7F77DD)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  _fmt(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3C3489),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit, size: 14, color: Colors.grey),
        ],
      ),
    ),
  );

  Widget _medInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) => TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      prefixIcon: Icon(icon, color: const Color(0xFF7F77DD), size: 18),
      filled: true,
      fillColor: const Color(0xFFF4F5FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF7F77DD)),
      ),
    ),
  );
}
