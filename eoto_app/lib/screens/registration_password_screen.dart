import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';
import 'login_screen.dart';

class RegistrationPasswordScreen extends StatefulWidget {
  final String role; // 'student' or 'not_student'

  const RegistrationPasswordScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RegistrationPasswordScreen> createState() => _RegistrationPasswordScreenState();
}

class _RegistrationPasswordScreenState extends State<RegistrationPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isRegistering = false;

  int _passwordStrength = 0; // 0 to 4 blocks

  void _checkPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]')) || password.contains(RegExp(r'[!@#\$&*~]'))) strength++;
    
    setState(() {
      _passwordStrength = strength;
    });
  }

  void _handleCompleteSignUp() async {
    if (!_formKey.currentState!.validate() || !_agreeToTerms) return;

    setState(() {
      _isRegistering = true;
    });

    final controller = Provider.of<RegistrationController>(context, listen: false);
    
    // Save to Firestore!
    bool success = await controller.saveToFirestore(_passwordController.text);

    setState(() {
      _isRegistering = false;
    });

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ApplicationReviewDialog(),
      );
    } else if (mounted) {
      final errorMsg = controller.registrationErrorMessage ?? 'Registration failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildStrengthSegment(int index) {
    final active = index < _passwordStrength;
    Color segmentColor = const Color(0xFFE5E5EA);
    if (active) {
      if (_passwordStrength <= 1) {
        segmentColor = Colors.redAccent;
      } else if (_passwordStrength <= 3) {
        segmentColor = Colors.orangeAccent;
      } else {
        segmentColor = AppTheme.primaryLime;
      }
    }

    return Expanded(
      child: Container(
        height: 6,
        margin: EdgeInsets.only(
          left: index == 0 ? 0 : 4,
          right: index == 3 ? 0 : 4,
        ),
        decoration: BoxDecoration(
          color: segmentColor,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5500), size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Bar (Step 4 of 4)
                const Text(
                  'STEP 4 OF 4',
                  style: TextStyle(
                    color: Color(0xFF8E8E93), 
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                  ],
                ),
                const SizedBox(height: 36),

                // Headers
                const Text(
                  'Secure Your Account',
                  style: TextStyle(
                    color: Colors.black, 
                    fontSize: 34, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Create a strong password to protect your volunteer profile and learner data.',
                  style: TextStyle(
                    color: Color(0xFF636366), 
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // 1. Create Password Field
                const Text(
                  'CREATE PASSWORD',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    onChanged: _checkPasswordStrength,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF8E8E93),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password is required';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Password Strength Indicator Row
                Row(
                  children: List.generate(4, (index) => _buildStrengthSegment(index)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _passwordStrength >= 3 ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _passwordStrength >= 3 ? Colors.green : const Color(0xFF8E8E93),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _passwordStrength <= 1
                          ? 'Strength: Weak'
                          : (_passwordStrength <= 3 ? 'Strength: Medium' : 'Strength: Strong'),
                      style: TextStyle(
                        color: _passwordStrength >= 3 ? Colors.green : const Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 2. Confirm Password Field
                const Text(
                  'CONFIRM PASSWORD',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Repeat your password',
                      hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF8E8E93),
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Terms & Conditions Checkbox
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _agreeToTerms ? AppTheme.primaryLime : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _agreeToTerms ? AppTheme.primaryLime : const Color(0xFFD1D1D6),
                            width: 1.5,
                          ),
                        ),
                        child: _agreeToTerms
                            ? const Icon(Icons.check, color: Colors.black, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: Color(0xFF636366), fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'NCHD EOTO Terms &\nPrivacy Policy',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Pill Complete Sign Up Button
                if (_isRegistering) ...[
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime))
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_agreeToTerms && _passwordStrength >= 2) ? _handleCompleteSignUp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_agreeToTerms && _passwordStrength >= 2) ? AppTheme.primaryLime : const Color(0xFFE5E5EA),
                        foregroundColor: (_agreeToTerms && _passwordStrength >= 2) ? Colors.black : const Color(0xFF8E8E93),
                        minimumSize: const Size(double.infinity, 58),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(29),
                        ),
                      ),
                      child: const Text(
                        'Complete Sign Up',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ApplicationReviewDialog extends StatelessWidget {
  const ApplicationReviewDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 72, color: AppTheme.statusPending),
            const SizedBox(height: 24),
            const Text(
              'Application Under Review',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your application has been successfully routed to your Focal Person. Standard verification takes 3-5 working days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF636366), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('RETURN TO LOGIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
