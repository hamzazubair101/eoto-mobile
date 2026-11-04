import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';
import 'password_reset_success.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../services/emailjs_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Email, 2: OTP, 3: New Password
  bool _isLoading = false;
  String? _generatedOtp;

  // Step 1 Controllers
  final TextEditingController _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // Step 2 Controllers (6 OTP boxes)
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _timerSeconds = 60;
  Timer? _timer;

  // Step 3 Controllers
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _passwordStrength = 'Weak';
  Color _strengthColor = Colors.redAccent;

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  void _evaluatePasswordStrength(String value) {
    if (value.isEmpty) {
      setState(() {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.redAccent;
      });
      return;
    }

    bool hasLetters = value.contains(RegExp(r'[a-zA-Z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));
    bool hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (value.length >= 8 && hasLetters && hasDigits && hasSpecial) {
      setState(() {
        _passwordStrength = 'Strong';
        _strengthColor = AppTheme.primaryLime;
      });
    } else if (value.length >= 6 && hasLetters && hasDigits) {
      setState(() {
        _passwordStrength = 'Medium';
        _strengthColor = Colors.orangeAccent;
      });
    } else {
      setState(() {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.redAccent;
      });
    }
  }

  void _handleStep1() async {
    if (_isLoading) return;
    if (_emailFormKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      final email = _emailController.text.trim().toLowerCase();
      
      try {
        final fpDoc = await FirebaseFirestore.instance.collection('focal_persons').doc(email).get();
        bool emailExists = fpDoc.exists;
        
        if (!emailExists) {
          final teacherQuery = await FirebaseFirestore.instance.collection('teachers').where('email', isEqualTo: email).limit(1).get();
          if (teacherQuery.docs.isNotEmpty) {
            emailExists = true;
          }
        }

        if (!emailExists) {
          setState(() { _isLoading = false; });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This email address is not registered in EOTO.'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final random = Random();
        final code = (100000 + random.nextInt(900000)).toString();
        _generatedOtp = code;

        await FirebaseFirestore.instance.collection('password_resets').doc(email).set({
          'email': email,
          'otp': code,
          'status': 'otp_sent',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final bool emailSent = await EmailJsService.sendOtpEmail(recipientEmail: email, otpCode: code);
        setState(() { _isLoading = false; });

        if (emailSent) {
          setState(() {
            _step = 2;
          });
          _startTimer();
          if (mounted) {
            FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send verification code. Please check internet connection.'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        setState(() { _isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _handleStep2() {
    if (_isLoading) return;
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit code')),
      );
      return;
    }
    
    if (otp == _generatedOtp) {
      setState(() {
        _step = 3;
      });
      _timer?.cancel();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleStep3() async {
    if (_isLoading) return;
    if (_passwordFormKey.currentState!.validate()) {
      if (_passwordStrength == 'Weak') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password is too weak. Please meet complexity requirements.')),
        );
        return;
      }
      
      setState(() { _isLoading = true; });
      final email = _emailController.text.trim().toLowerCase();
      final newPassword = _passwordController.text;

      try {
        await FirebaseFirestore.instance.collection('password_resets').doc(email).update({
          'newPassword': newPassword,
          'status': 'pending',
        });

        StreamSubscription<DocumentSnapshot>? subscription;
        subscription = FirebaseFirestore.instance.collection('password_resets').doc(email).snapshots().listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final status = data?['status'];
            if (status == 'success') {
              subscription?.cancel();
              setState(() { _isLoading = false; });
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const PasswordResetSuccessScreen()),
              );
            } else if (status == 'error') {
              subscription?.cancel();
              setState(() { _isLoading = false; });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reset Error: ${data?['errorMessage'] ?? "Failed to update"}'), backgroundColor: Colors.red),
              );
            }
          }
        });

        Future.delayed(const Duration(seconds: 15), () {
          if (_isLoading) {
            subscription?.cancel();
            setState(() { _isLoading = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reset request timed out. Please verify that the reset listener script is active.'), backgroundColor: Colors.red),
            );
          }
        });

      } catch (e) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStep1() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot Password',
            style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter your registered email address to receive a secure recovery verification code.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 48),

          // Email Field
          const Text(
            'EMAIL ADDRESS',
            style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'e.g. volunteer@eoto.pk',
              hintStyle: TextStyle(color: Color(0xFFC7C7CC)),
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5EA), width: 1.5)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryLime, width: 2)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleStep1,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SEND RESET CODE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Code',
          style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'We have sent a 6-digit secure recovery verification code to ${_emailController.text.trim()}.',
          style: const TextStyle(color: Color(0xFF636366), fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 48),

        // OTP inputs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: 48,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryLime, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  if (_otpControllers.map((c) => c.text).join().length == 6) {
                    _handleStep2();
                  }
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Ticking Resend Timer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _timerSeconds > 0
                  ? 'Resend code in ${_timerSeconds}s'
                  : "Haven't received the code? ",
              style: const TextStyle(color: Color(0xFF636366), fontSize: 14),
            ),
            if (_timerSeconds == 0)
              GestureDetector(
                onTap: _startTimer,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),

        const SizedBox(height: 48),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleStep2,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('VERIFY CODE'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Password',
            style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create a strong new secure password to secure your volunteer dashboard data.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 40),

          // 1. Password Field
          const Text(
            'NEW PASSWORD',
            style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter strong password',
              hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8E8E93),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5EA), width: 1.5)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryLime, width: 2)),
            ),
            onChanged: _evaluatePasswordStrength,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) return 'Must be at least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Live Password Strength indicator bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _strengthColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_passwordStrength Strength',
                style: TextStyle(
                  color: _strengthColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 2. Confirm Password Field
          const Text(
            'CONFIRM NEW PASSWORD',
            style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Re-enter strong password',
              hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF8E8E93),
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5EA), width: 1.5)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryLime, width: 2)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm Password is required';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleStep3,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('RESET PASSWORD'),
            ),
          ),
        ],
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
          onPressed: () {
            if (_step > 1) {
              setState(() {
                _step--;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 1
                ? _buildStep1()
                : _step == 2
                    ? _buildStep2()
                    : _buildStep3(),
          ),
        ),
      ),
    );
  }
}
