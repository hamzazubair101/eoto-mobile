import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../core/validators.dart';
import '../../controllers/registration_controller.dart';
import '../registration_documents_screen.dart';

class RegistrationAddressScreen extends StatefulWidget {
  final String role; // 'student' or 'not_student'

  const RegistrationAddressScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RegistrationAddressScreen> createState() => _RegistrationAddressScreenState();
}

class _RegistrationAddressScreenState extends State<RegistrationAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _permanentAddressController = TextEditingController();
  final TextEditingController _mailingAddressController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  bool _sameAsPermanent = false;

  @override
  void dispose() {
    _permanentAddressController.dispose();
    _mailingAddressController.dispose();
    _postalCodeController.dispose();
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
                // Progress Bar (Step 3 of 5)
                const Text(
                  'STEP 3 OF 5',
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
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 6),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                  ],
                ),
                const SizedBox(height: 36),

                // Header
                const Text(
                  'Address Details',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter your residential addresses for institutional dynamic routing and certification logistics.',
                  style: TextStyle(
                    color: Color(0xFF636366),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),

                // 1. Permanent Address
                _buildUnderlineField(
                  label: 'PERMANENT ADDRESS',
                  hintText: 'e.g. House 12, Street 3, F-8/1, Islamabad',
                  controller: _permanentAddressController,
                  validator: (value) => EotoValidators.validateRequired(value, 'Permanent Address'),
                  isRequired: true,
                ),
                const SizedBox(height: 28),

                // Same as Permanent Checkbox
                Row(
                  children: [
                    Checkbox(
                      activeColor: AppTheme.primaryLime,
                      checkColor: Colors.black,
                      value: _sameAsPermanent,
                      onChanged: (bool? checked) {
                        setState(() {
                          _sameAsPermanent = checked ?? false;
                          if (_sameAsPermanent) {
                            _mailingAddressController.text = _permanentAddressController.text;
                          }
                        });
                      },
                    ),
                    const Text(
                      'Mailing Address same as Permanent',
                      style: TextStyle(color: Color(0xFF636366), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Mailing Address
                _buildUnderlineField(
                  label: 'MAILING ADDRESS',
                  hintText: 'e.g. House 12, Street 3, F-8/1, Islamabad',
                  controller: _mailingAddressController,
                  validator: (value) => EotoValidators.validateRequired(value, 'Mailing Address'),
                  isRequired: true,
                ),
                const SizedBox(height: 28),

                // 3. Postal Code
                _buildUnderlineField(
                  label: 'POSTAL CODE',
                  hintText: 'e.g. 44000',
                  controller: _postalCodeController,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Postal Code is required';
                    }
                    if (value.trim().length != 5) {
                      return 'Must be exactly 5 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 48),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Provider.of<RegistrationController>(context, listen: false).setAddresses(
                          permanentAddress: _permanentAddressController.text.trim(),
                          mailingAddress: _mailingAddressController.text.trim(),
                          postalCode: _postalCodeController.text.trim(),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RegistrationDocumentsScreen(role: widget.role),
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
