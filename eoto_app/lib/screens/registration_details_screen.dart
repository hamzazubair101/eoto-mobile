import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/registration_controller.dart';
import '../core/validators.dart';
import 'registration_documents_screen.dart';
import 'registration/registration_address_screen.dart';

class RegistrationDetailsScreen extends StatefulWidget {
  final String role; // 'student' or 'not_student'
  
  const RegistrationDetailsScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RegistrationDetailsScreen> createState() => _RegistrationDetailsScreenState();
}

class _RegistrationDetailsScreenState extends State<RegistrationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildUnderlineField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: Colors.black, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: suffixIcon,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E5EA), width: 1.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryLime, width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.statusRejected, width: 1.5),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.statusRejected, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _handleDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryLime,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
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
                // Progress Bar (Step 2 of 5)
                const Text(
                  'STEP 2 OF 5',
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
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                  ],
                ),
                const SizedBox(height: 36),

                // Title Header
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    color: Colors.black, 
                    fontSize: 36, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter your information exactly as it appears on your CNIC.',
                  style: TextStyle(
                    color: Color(0xFF636366), 
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // 1. Full Name
                _buildUnderlineField(
                  label: 'FULL NAME',
                  hintText: 'e.g. Ali Khan',
                  controller: _nameController,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                  validator: (value) => EotoValidators.validateName(value, 'Full Name'),
                  isRequired: true,
                ),
                const SizedBox(height: 28),

                // 2. Father's Name
                _buildUnderlineField(
                  label: "FATHER'S NAME",
                  hintText: "Enter father's name",
                  controller: _fatherNameController,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                  validator: (value) => EotoValidators.validateName(value, "Father's Name"),
                  isRequired: true,
                ),
                const SizedBox(height: 28),

                // 3. CNIC / B-FORM
                _buildUnderlineField(
                  label: 'CNIC / B-FORM',
                  hintText: 'XXXXX-XXXXXXX-X',
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  suffixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF8E8E93)),
                  validator: EotoValidators.validateCNIC,
                ),
                const SizedBox(height: 28),

                // 4. Date of Birth
                GestureDetector(
                  onTap: _handleDatePicker,
                  child: AbsorbPointer(
                    child: _buildUnderlineField(
                      label: 'DATE OF BIRTH',
                      hintText: 'DD/MM/YYYY',
                      controller: _dobController,
                      suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF8E8E93)),
                      validator: (value) => EotoValidators.validateRequired(value, 'Date of Birth'),
                      isRequired: true,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 5. Phone Number
                _buildUnderlineField(
                  label: 'PHONE NUMBER',
                  hintText: '03XX-XXXXXXX',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  isRequired: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                  validator: EotoValidators.validatePhone,
                ),
                const SizedBox(height: 28),

                // 6. Email Address
                _buildUnderlineField(
                  label: 'EMAIL ADDRESS',
                  hintText: 'example@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: EotoValidators.validateEmail,
                  isRequired: true,
                ),
                const SizedBox(height: 48),

                // Pill next step button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Provider.of<RegistrationController>(context, listen: false).setDetails(
                          name: _nameController.text.trim(),
                          fatherName: _fatherNameController.text.trim(),
                          dob: _dobController.text.trim(),
                          emailAddress: _emailController.text.trim(),
                          phoneNumber: _phoneController.text.trim(),
                          cnicNumber: _cnicController.text.trim(),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RegistrationAddressScreen(role: widget.role),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 58),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                    child: const Text(
                      'Next Step',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationThickness: 2,
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
