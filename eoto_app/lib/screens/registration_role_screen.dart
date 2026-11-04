import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';
import 'registration_details_screen.dart';

class RegistrationRoleScreen extends StatefulWidget {
  const RegistrationRoleScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationRoleScreen> createState() => _RegistrationRoleScreenState();
}

class _RegistrationRoleScreenState extends State<RegistrationRoleScreen> {
  String? _selectedRole; // 'student' or 'not_student'

  void _handleNext() {
    if (_selectedRole == null) return;
    
    Provider.of<RegistrationController>(context, listen: false).setRole(_selectedRole!);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrationDetailsScreen(role: _selectedRole!),
      ),
    );
  }

  Widget _buildRoleCard(String role, String title, IconData icon) {
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLime : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryLime.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFE5E5EA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : const Color(0xFF8E8E93),
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryLime, size: 24),
          ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar (Step 1 of 4)
              const Text(
                'STEP 1 OF 4',
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
                  Expanded(
                    child: Container(
                      height: 4, 
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLime,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 36),
              
              // Welcome Header
              const Text(
                'Welcome!',
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 42, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To get started, please tell us\nyour current status.',
                style: TextStyle(
                  color: Color(0xFF636366), 
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              
              // Role Cards
              _buildRoleCard(
                'student',
                'I am a Student',
                Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                'not_student',
                'I am not a Student',
                Icons.work_outline_rounded,
              ),
              
              const Spacer(),
              
              // Underlined Next Step Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedRole != null ? _handleNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole != null ? AppTheme.primaryLime : const Color(0xFFE5E5EA),
                    foregroundColor: _selectedRole != null ? Colors.black : const Color(0xFF8E8E93),
                    minimumSize: const Size(double.infinity, 58),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29),
                    ),
                  ),
                  child: Text(
                    'Next Step',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      decoration: _selectedRole != null ? TextDecoration.underline : TextDecoration.none,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Already have an account row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ', 
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.black, 
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
