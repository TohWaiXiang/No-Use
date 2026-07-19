import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification toggles
  bool _notifPeriod = true;
  bool _notifWellness = true;
  bool _notifOvulation = true;
  bool _notifAi = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notifPrefs = await NotificationService.instance.getPreferences();
    setState(() {
      _notifPeriod = notifPrefs['notif_period'] ?? true;
      _notifWellness = notifPrefs['notif_wellness'] ?? true;
      _notifOvulation = notifPrefs['notif_ovulation'] ?? true;
      _notifAi = notifPrefs['notif_ai'] ?? false;
    });
  }

  Future<void> _setNotif(String key, bool value) async {
    setState(() {
      if (key == 'notif_period') _notifPeriod = value;
      if (key == 'notif_wellness') _notifWellness = value;
      if (key == 'notif_ovulation') _notifOvulation = value;
      if (key == 'notif_ai') _notifAi = value;
    });
    await NotificationService.instance.setPreference(key, value);
    _showSnack(value ? 'Reminder enabled' : 'Reminder disabled');
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

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account and all your data (cycle logs, symptoms, predictions, chat history, reminders). This action cannot be undone.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                enabled: !loading,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Confirm your password',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        setDialogState(
                          () => error = 'Enter your password to confirm.',
                        );
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        error = null;
                      });
                      final result = await AuthService.deleteAccount(
                        password: passwordController.text,
                      );
                      if (result['success'] != true) {
                        setDialogState(() {
                          loading = false;
                          error = result['error'] as String;
                        });
                        return;
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                color: const Color(0xFFEEEDFE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3C3489),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your preferences',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── NOTIFICATIONS ──────────────────────────────
                    _sectionTitle('NOTIFICATIONS'),
                    _settingsCard([
                      _toggleTile(
                        icon: Icons.water_drop_outlined,
                        iconBg: const Color(0xFFEEEDFE),
                        iconColor: const Color(0xFF7F77DD),
                        title: 'Period Reminder',
                        subtitle: 'Get notified 2 days before your period',
                        value: _notifPeriod,
                        onChanged: (v) => _setNotif('notif_period', v),
                      ),
                      _divider(),
                      _toggleTile(
                        icon: Icons.wb_sunny_outlined,
                        iconBg: const Color(0xFFEEEDFE),
                        iconColor: const Color(0xFF7F77DD),
                        title: 'Ovulation Reminder',
                        subtitle: 'Alert before your fertile window',
                        value: _notifOvulation,
                        onChanged: (v) => _setNotif('notif_ovulation', v),
                      ),
                      _divider(),
                      _toggleTile(
                        icon: Icons.self_improvement,
                        iconBg: const Color(0xFFE6F1FB),
                        iconColor: const Color(0xFF378ADD),
                        title: 'Wellness Check-in',
                        subtitle: 'Daily reminder to log symptoms',
                        value: _notifWellness,
                        onChanged: (v) => _setNotif('notif_wellness', v),
                      ),
                      _divider(),
                      _toggleTile(
                        icon: Icons.auto_awesome,
                        iconBg: const Color(0xFFEEEDFE),
                        iconColor: const Color(0xFF7F77DD),
                        title: 'AI Insight Tips',
                        subtitle: 'Daily personalised health tips',
                        value: _notifAi,
                        onChanged: (v) => _setNotif('notif_ai', v),
                      ),
                    ]),

                    // ── PRIVACY & ACCOUNT ──────────────────────────
                    _sectionTitle('PRIVACY & ACCOUNT'),
                    _settingsCard([
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.privacy_tip_outlined,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C2C2A),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(
                              title: 'Privacy Policy',
                              body: LegalScreen.privacyPolicy,
                            ),
                          ),
                        ),
                      ),
                      _divider(),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          'Terms of Service',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C2C2A),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(
                              title: 'Terms of Service',
                              body: LegalScreen.termsOfService,
                            ),
                          ),
                        ),
                      ),
                      _divider(),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delete_forever_outlined,
                            color: Color(0xFFE24B4A),
                            size: 18,
                          ),
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE24B4A),
                          ),
                        ),
                        subtitle: Text(
                          'Permanently remove all your data',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.red,
                          size: 18,
                        ),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ]),

                    // ── ABOUT ──────────────────────────────────────
                    _sectionTitle('ABOUT'),
                    _settingsCard([
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          'App Version',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C2C2A),
                          ),
                        ),
                        trailing: Text(
                          '1.0.0',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      _divider(),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.favorite_outline,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          'Made with ♥ by Luna Health',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C2C2A),
                          ),
                        ),
                        subtitle: Text(
                          'Your cycle, your data, your control',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEEEDFE)),
    ),
    child: Column(children: children),
  );

  Widget _toggleTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    secondary: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF2C2C2A),
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(fontSize: 11, color: Colors.grey),
    ),
    value: value,
    activeThumbColor: const Color(0xFF7F77DD),
    activeTrackColor: const Color(0xFFAFA9EC),
    onChanged: onChanged,
  );

  Widget _divider() => Divider(
    height: 1,
    color: const Color(0xFFEEEDFE),
    indent: 16,
    endIndent: 16,
  );
}
