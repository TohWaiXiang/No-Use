import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 1 controllers
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Page 2 controllers
  final _ageCtrl = TextEditingController();
  final _cycleLengthCtrl = TextEditingController(text: '28');
  final _periodDurCtrl = TextEditingController(text: '5');
  final _sleepCtrl = TextEditingController(text: '7');

  int _stressLevel = 2;
  int _exerciseDays = 3;
  String _fitnessLevel = 'Beginner';

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _ageCtrl.dispose();
    _cycleLengthCtrl.dispose();
    _periodDurCtrl.dispose();
    _sleepCtrl.dispose();
    super.dispose();
  }

  // ── Validate page 1 ──────────────────────────────────────────────
  String? _validatePage1() {
    if (_usernameCtrl.text.trim().isEmpty) {
      return 'Please enter your name.';
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      return 'Please enter a valid email.';
    }
    if (_passCtrl.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  // ── Validate page 2 ──────────────────────────────────────────────
  String? _validatePage2() {
    final age = int.tryParse(_ageCtrl.text);
    if (age == null || age < 10 || age > 60) {
      return 'Please enter a valid age (10–60).';
    }
    final cycle = double.tryParse(_cycleLengthCtrl.text);
    if (cycle == null || cycle < 21 || cycle > 40) {
      return 'Cycle length should be between 21–40 days.';
    }
    final dur = double.tryParse(_periodDurCtrl.text);
    if (dur == null || dur < 2 || dur > 10) {
      return 'Period duration should be between 2–10 days.';
    }
    return null;
  }

  void _nextPage() {
    final error = _validatePage1();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    _currentPage = 1;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _register() async {
    final error = _validatePage2();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.register(
      email: _emailCtrl.text,
      password: _passCtrl.text,
      username: _usernameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text),
      avgCycleLength: double.parse(_cycleLengthCtrl.text),
      avgPeriodDuration: double.parse(_periodDurCtrl.text),
      stressLevel: _stressLevel,
      sleepHours: double.tryParse(_sleepCtrl.text) ?? 7.0,
      exerciseDays: _exerciseDays,
      fitnessLevel: _fitnessLevel,
    );

    if (!mounted) return;

    if (result['success']) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameCtrl.text.trim());
      await prefs.setString('uid', result['uid']);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    } else {
      setState(() {
        _error = result['error'];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: const Color(0xFFEEEDFE),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_currentPage == 0) {
                            Navigator.pop(context);
                          } else {
                            setState(() {
                              _currentPage = 0;
                              _error = null;
                            });
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
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
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F77DD),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage >= 1
                                ? const Color(0xFF7F77DD)
                                : const Color(0xFFD3D1C7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPage == 0
                        ? 'Step 1 of 2 — Account details'
                        : 'Step 2 of 2 — Health profile',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildPage1(), _buildPage2()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1 — Account details ─────────────────────────────────────
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _errorBanner(),
          _label('Full name'),
          _input(
            controller: _usernameCtrl,
            hint: 'Adeline Tan',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _label('Email address'),
          _input(
            controller: _emailCtrl,
            hint: 'user@gmail.com',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _label('Password'),
          _input(
            controller: _passCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscurePass,
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: 14),
          _label('Confirm password'),
          _input(
            controller: _confirmCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2 — Health profile ───────────────────────────────────────
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _errorBanner(),

          _label('Age'),
          _input(
            controller: _ageCtrl,
            hint: 'eg: 25',
            icon: Icons.cake_outlined,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 14),

          _label('Average cycle length (days)'),
          _input(
            controller: _cycleLengthCtrl,
            hint: '28',
            icon: Icons.loop,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 6),
          const Text(
            'Normal range: 21–40 days. Default is 28.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 14),

          _label('Average period duration (days)'),
          _input(
            controller: _periodDurCtrl,
            hint: '5',
            icon: Icons.water_drop_outlined,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 6),
          const Text(
            'Normal range: 2–10 days. Default is 5.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 14),

          _label('Average sleep hours per night'),
          _input(
            controller: _sleepCtrl,
            hint: '7',
            icon: Icons.bedtime_outlined,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 14),

          // Stress level slider
          _label('Stress level'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEDFE)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Low',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _stressLabel(_stressLevel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Text(
                      'High',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  onChanged: (v) => setState(() => _stressLevel = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Exercise days
          _label('Exercise days per week'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEDFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(8, (i) {
                final selected = i == _exerciseDays;
                return GestureDetector(
                  onTap: () => setState(() => _exerciseDays = i),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF7F77DD)
                          : const Color(0xFFF4F5FB),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
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
                          color: selected ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Fitness level
          _label('Fitness level'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEDFE)),
            ),
            child: Row(
              children: ['Beginner', 'Intermediate', 'Advanced'].map((level) {
                final selected = _fitnessLevel == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _fitnessLevel = level),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF7F77DD)
                            : const Color(0xFFF4F5FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF7F77DD)
                              : const Color(0xFFEEEDFE),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(0xFFAFA9EC),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _stressLabel(int level) {
    switch (level) {
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

  Widget _errorBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFCEBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF09595)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFE24B4A), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFE24B4A)),
          ),
        ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.grey,
      ),
    ),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, color: const Color(0xFF7F77DD), size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7F77DD)),
      ),
    ),
  );
}
