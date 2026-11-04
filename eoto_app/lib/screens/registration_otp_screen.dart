import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../services/emailjs_service.dart';
import 'registration_password_screen.dart';

class RegistrationOtpScreen extends StatefulWidget {
  final String role; // 'student' or 'not_student'
  final String email;
  final String phone;

  const RegistrationOtpScreen({Key? key, required this.role, required this.email, required this.phone}) : super(key: key);

  @override
  State<RegistrationOtpScreen> createState() => _RegistrationOtpScreenState();
}

class _RegistrationOtpScreenState extends State<RegistrationOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isVerifying = false;
  int _secondsRemaining = 59;
  Timer? _timer;
  String _generatedOtp = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOtpCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 59;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _sendOtpCode() async {
    setState(() { _isVerifying = true; });
    
    // Generate a random 6-digit code
    final random = Random();
    _generatedOtp = List.generate(6, (index) => random.nextInt(10).toString()).join();
    print("DEBUG: Generated Email OTP = $_generatedOtp for ${widget.email}");

    try {
      bool success = await EmailJsService.sendOtpEmail(
        recipientEmail: widget.email,
        otpCode: _generatedOtp,
      );
      
      if (mounted) {
        setState(() { _isVerifying = false; });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Secure email code sent to ${widget.email}!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email send failed. Check console configurations or fallback dummy code."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isVerifying = false; });
        print("Phone verification catch block error: $e");
      }
    }
  }

  void _handleVerify() async {
    String enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    setState(() { _isVerifying = true; });

    // Verify entered code matches generated OTP or local testing bypass '123456'
    if (enteredCode == _generatedOtp || enteredCode == '123456') {
      if (mounted) {
        setState(() { _isVerifying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Colors.green),
        );
        _navigateToPasswordScreen();
      }
    } else {
      if (mounted) {
        setState(() { _isVerifying = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid verification code. Please check your email inbox."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToPasswordScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrationPasswordScreen(role: widget.role),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final bool hasFocus = _focusNodes[index].hasFocus;
    
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
              setState(() {}); // Rebuild for outline indicator
            },
          ),
          if (hasFocus || _controllers[index].text.isNotEmpty)
            Positioned(
              bottom: 4,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLime,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOtpComplete = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5500), size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF8E8E93)),
            onPressed: () {},
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Text(
                'English',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 34, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  text: "We've sent a secure 6-digit code to ",
                  style: const TextStyle(color: Color(0xFF636366), fontSize: 15, height: 1.4),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const TextSpan(
                      text: ". Please enter the code below to verify your account.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // OTP Segmented Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              
              const SizedBox(height: 36),
              
              // Resend code timer text
              Center(
                child: GestureDetector(
                  onTap: _secondsRemaining > 0
                      ? null
                      : () {
                          _startTimer();
                          _sendOtpCode();
                        },
                  child: Text.rich(
                    TextSpan(
                      text: "Didn't receive the email? ",
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      children: [
                        TextSpan(
                          text: _secondsRemaining > 0 
                              ? "Resend in 0:${_secondsRemaining.toString().padLeft(2, '0')}s"
                              : "Resend Code",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: _secondsRemaining > 0 ? Colors.grey : Colors.black,
                            decoration: _secondsRemaining > 0 ? TextDecoration.none : TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 60),

              // Verify Email & Continue button
              if (_isVerifying) ...[
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime))
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOtpComplete ? _handleVerify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOtpComplete ? AppTheme.primaryLime : const Color(0xFFE5E5EA),
                      foregroundColor: isOtpComplete ? Colors.black : const Color(0xFF8E8E93),
                      minimumSize: const Size(double.infinity, 58),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                    child: const Text(
                      'Verify Email & Continue',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
