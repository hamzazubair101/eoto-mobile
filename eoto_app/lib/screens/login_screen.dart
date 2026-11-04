import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/registration_controller.dart';
import '../utils/app_theme.dart';
import 'registration_role_screen.dart';
import 'focal_person_dashboard.dart';
import 'teacher_dashboard.dart';
import 'auth/forgot_password_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _handleLogin() async {
    // Basic validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final controller = Provider.of<RegistrationController>(context, listen: false);
      final uid = await controller.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (uid != null) {
        final emailInput = _emailController.text.trim().toLowerCase();

        // 1. First check if the user is a registered Focal Person or Field Officer in Firestore
        final fpDoc = await FirebaseFirestore.instance.collection('focal_persons').doc(emailInput).get();
        final bool isFocalPerson = fpDoc.exists || emailInput.contains('focal') || emailInput.endsWith('@eoto.pk');

        if (isFocalPerson) {
          final data = fpDoc.data();
          final String focalStatus = (data?['status'] ?? 'active').toString().toLowerCase();

          if (focalStatus == 'suspended') {
            setState(() { _isLoading = false; });
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.cardLight,
                  title: const Text(
                    'Account Suspended',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'Your official Focal Person account has been suspended by the Super Admin.\n\nPlease contact central program administration.',
                    style: TextStyle(color: AppTheme.textBlack),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK', style: TextStyle(color: AppTheme.primaryLime)),
                    ),
                  ],
                ),
              );
            }
            return;
          }

          final bool isFirstLogin = data == null || data['isFirstLogin'] != false;

          if (isFirstLogin) {
            setState(() { _isLoading = false; });
            if (mounted) {
              _showChangePasswordDialog(context, emailInput);
            }
          } else {
            setState(() { _isLoading = false; });
            if (mounted) {
              AppTheme.showSuccessSnackBar(
                context,
                'Logged in successfully as Focal Person.',
                duration: const Duration(seconds: 1),
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => FocalPersonDashboard(focalEmail: emailInput)),
              );
            }
          }
        } else {
          setState(() { _isLoading = false; });
          final String status = controller.teacherStatus ?? 'pending';

          if (status == 'approved') {
            AppTheme.showSuccessSnackBar(
              context,
              'Logged in successfully as Volunteer Teacher.',
              duration: const Duration(seconds: 1),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const TeacherDashboard()),
            );
          } else if (status == 'rejected') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppTheme.cardLight,
                title: const Text(
                  'Application Rejected',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Your volunteer application has been rejected by the Focal Person.\n\nReason: ${controller.rejectionRemarks ?? "Documents unverified"}.\n\nPlease register again or contact support.',
                  style: const TextStyle(color: AppTheme.textBlack),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: AppTheme.primaryLime)),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppTheme.cardLight,
                title: const Text(
                  'Application Pending',
                  style: TextStyle(color: AppTheme.statusPending, fontWeight: FontWeight.bold),
                ),
                content: const Text(
                  'Your application is currently under review by your assigned university Focal Person.\n\nYou will be able to access the teaching dashboard once verification is complete.',
                  style: TextStyle(color: AppTheme.textBlack),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: AppTheme.primaryLime)),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed: Invalid email or password'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication Error: ${e.toString().split(']').last.trim()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context, String email) {
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isUpdating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Change Password Required',
                style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This is your first login. To secure your account, please set a new password.',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'NEW PASSWORD',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textGrey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter new password',
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textGrey),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CONFIRM NEW PASSWORD',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textGrey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Re-enter new password',
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textGrey),
                      ),
                      validator: (value) {
                        if (value != newPassController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                if (isUpdating)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryLime))
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLime,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() { isUpdating = true; });
                        try {
                          // Update password in Firebase Authentication
                          await FirebaseAuth.instance.currentUser?.updatePassword(newPassController.text.trim());
                          
                          // Mark first login as false in Firestore
                          await FirebaseFirestore.instance.collection('focal_persons').doc(email).set({
                            'isFirstLogin': false,
                          }, SetOptions(merge: true));

                          if (context.mounted) {
                            Navigator.pop(context); // Pop dialog
                            
                            AppTheme.showSuccessSnackBar(
                              context,
                              'Password updated successfully! Welcome to EOTO.',
                              duration: const Duration(seconds: 2),
                            );

                            // Proceed to Dashboard
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => FocalPersonDashboard(focalEmail: email)),
                            );
                          }
                        } catch (e) {
                          setDialogState(() { isUpdating = false; });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update password: ${e.toString().split(']').last.trim()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Header
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue your EOTO journey.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),

              // Email Field
              Text(
                'EMAIL ADDRESS',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your registered email',
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textGrey),
                ),
              ),
              const SizedBox(height: 24),

              // Password Field
              Text(
                'PASSWORD',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, color: AppTheme.textGrey, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textGrey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textGrey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black) 
                      : const Text('LOG IN'),
                ),
              ),
              
              const SizedBox(height: 24),
              // Sign Up Route
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account? ', style: TextStyle(color: AppTheme.textGrey)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RegistrationRoleScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
