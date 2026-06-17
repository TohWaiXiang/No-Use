import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _periodReminder = true;
  bool _wellnessReminder = true;
  bool _aiInsights = false;
  bool _ovulationReminder = true;
  bool _darkMode = false;
  bool _appLock = false;
  bool _shareData = false;
  String _language = 'English';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _periodReminder = prefs.getBool('notif_period') ?? true;
      _wellnessReminder = prefs.getBool('notif_wellness') ?? true;
      _aiInsights = prefs.getBool('notif_ai') ?? false;
      _ovulationReminder = prefs.getBool('notif_ovulation') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _appLock = prefs.getBool('app_lock') ?? false;
      _shareData = prefs.getBool('share_data') ?? false;
      _language = prefs.getString('language') ?? 'English';
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
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

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will permanently delete your account and all data. This action cannot be undone.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
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

  void _exportData() {
    _showSnack('Data export will be sent to your email.');
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
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              color: const Color(0xFFEEEDFE),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 15,
                        color: Color(0xFF7F77DD),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3489),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Notifications
                    _sectionLabel('Notifications'),
                    _toggleRow(
                      Icons.notifications_outlined,
                      'Period reminders',
                      'Alert 2 days before your period',
                      _periodReminder,
                      (v) {
                        setState(() => _periodReminder = v);
                        _saveBool('notif_period', v);
                      },
                    ),
                    _toggleRow(
                      Icons.self_improvement,
                      'Wellness reminders',
                      'Daily exercise nudges',
                      _wellnessReminder,
                      (v) {
                        setState(() => _wellnessReminder = v);
                        _saveBool('notif_wellness', v);
                      },
                    ),
                    _toggleRow(
                      Icons.auto_awesome_outlined,
                      'AI insights',
                      'New personalised health tips',
                      _aiInsights,
                      (v) {
                        setState(() => _aiInsights = v);
                        _saveBool('notif_ai', v);
                      },
                    ),
                    _toggleRow(
                      Icons.favorite_border,
                      'Ovulation reminders',
                      'Fertility window alerts',
                      _ovulationReminder,
                      (v) {
                        setState(() => _ovulationReminder = v);
                        _saveBool('notif_ovulation', v);
                      },
                    ),

                    const SizedBox(height: 8),

                    // Appearance
                    _sectionLabel('Appearance'),
                    _toggleRow(
                      Icons.dark_mode_outlined,
                      'Dark mode',
                      'Follow system setting',
                      _darkMode,
                      (v) {
                        setState(() => _darkMode = v);
                        _saveBool('dark_mode', v);
                      },
                    ),
                    _dropdownRow(
                      Icons.language,
                      'Language',
                      _language,
                      ['English', 'Bahasa Malaysia', '中文'],
                      (v) {
                        setState(() => _language = v!);
                        _saveString('language', v!);
                      },
                    ),

                    const SizedBox(height: 8),

                    // Privacy
                    _sectionLabel('Privacy & Security'),
                    _toggleRow(
                      Icons.lock_outline,
                      'App lock',
                      'Require biometrics to open',
                      _appLock,
                      (v) {
                        setState(() => _appLock = v);
                        _saveBool('app_lock', v);
                      },
                    ),
                    _toggleRow(
                      Icons.bar_chart_outlined,
                      'Share anonymised data',
                      'Help improve the AI model',
                      _shareData,
                      (v) {
                        setState(() => _shareData = v);
                        _saveBool('share_data', v);
                      },
                    ),

                    const SizedBox(height: 8),

                    // Data
                    _sectionLabel('Data Management'),
                    _actionRow(
                      Icons.upload_outlined,
                      'Export my data',
                      const Color(0xFF7F77DD),
                      _exportData,
                    ),
                    _actionRow(
                      Icons.delete_outline,
                      'Delete account',
                      const Color(0xFFE24B4A),
                      _confirmDeleteAccount,
                    ),

                    // App version
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Luna Health v1.0.0',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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

  Widget _toggleRow(
    IconData icon,
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 1),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF7F77DD), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Color(0xFF2C2C2A)),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF7F77DD),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );

  Widget _dropdownRow(
    IconData icon,
    String title,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 1),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF7F77DD), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2C2C2A)),
          ),
        ),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          onChanged: onChanged,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
        ),
      ],
    ),
  );

  Widget _actionRow(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 1),
    child: ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      title: Text(title, style: TextStyle(fontSize: 13, color: color)),
      trailing: Icon(Icons.chevron_right, color: color, size: 18),
      onTap: onTap,
    ),
  );
}
