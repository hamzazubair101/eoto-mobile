import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/districts_data.dart';
import '../controllers/registration_controller.dart';

/// Auto-formats numeric input into 11-digit identification with automatic hyphens:
/// User enters only digits (up to 11 digits total).
/// Automatically inserts dashes: XXXXX-XXXXX-X (yielding 13 characters total).
class CnicAutoDashInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 4 || i == 9) && i != digits.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AddLearnerScreen extends StatefulWidget {
  const AddLearnerScreen({Key? key}) : super(key: key);

  @override
  State<AddLearnerScreen> createState() => _AddLearnerScreenState();
}

class _AddLearnerScreenState extends State<AddLearnerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _parentageController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  
  // Dropdown states
  String _idType = 'CNIC'; // 'CNIC', 'B-Form', 'Does Not Have Either'
  String _gender = 'Male';
  DateTime? _dateOfBirth;
  int? _calculatedAge;
  String _province = 'Punjab';
  late String _district;
  String _occupation = 'Domestic Help';
  String _literacyLevel = 'Illiterate (No prior schooling)';

  Future<void> _pickDateOfBirth() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _dateOfBirth ?? DateTime(now.year - 20, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryLime,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      int age = now.year - picked.year;
      if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
        age--;
      }
      setState(() {
        _dateOfBirth = picked;
        _calculatedAge = age;
      });
    }
  }

  // Static options for dynamic dropdowns
  final List<String> _occupations = ['Domestic Help', 'Agriculture Labor', 'Unemployed', 'Factory Worker', 'Street Vendor', 'Other'];
  final List<String> _literacyLevels = [
    'Illiterate (No prior schooling)',
    'Semi-Literate (Can recognize alphabets)',
    'Can sign name only'
  ];

  @override
  void initState() {
    super.initState();
    final districts = DistrictsData.getDistricts(_province);
    _district = districts.contains('Lahore') ? 'Lahore' : districts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentageController.dispose();
    _idNumberController.dispose();
    _originController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the learner\'s Date of Birth'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final controller = Provider.of<RegistrationController>(context, listen: false);
    
    // Generate a clean mock learner ID (e.g. L-1234)
    final random = Random();
    final String learnerId = 'L-${1000 + random.nextInt(9000)}';

    final Map<String, dynamic> newLearner = {
      'id': learnerId,
      'name': _nameController.text.trim(),
      'parentage': _parentageController.text.trim(),
      'gender': _gender,
      'dateOfBirth': '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
      'dob': '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
      'age': _calculatedAge ?? 0,
      'idType': _idType,
      'idNumber': _idType != 'Does Not Have Either' ? _idNumberController.text.trim() : '',
      'province': _province,
      'district': _district,
      'origin': _originController.text.trim(),
      'occupation': _occupation,
      'startingLiteracy': _literacyLevel,
      'status': 'Awaiting Baseline', // Needs baseline upload to begin calendar
      'progress': 0.0,
      'classesTaught': 0,
      'totalClasses': 36,
      'lastSession': 'N/A',
      'remarks': '',
    };

    controller.addLearner(newLearner);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Learner "${_nameController.text.trim()}" added successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildFieldLabel(String text, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 11,
                color: AppTheme.textGrey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
        if (isRequired)
          const Padding(
            padding: EdgeInsets.only(left: 3.0),
            child: Text(
              '*',
              style: TextStyle(
                color: Color(0xFFEF4444), // Vibrant crimson red
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showIdField = _idType != 'Does Not Have Either';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register New Learner',
          style: TextStyle(color: AppTheme.textBlack, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Input
                _buildFieldLabel('LEARNER FULL NAME', isRequired: true),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppTheme.textBlack),
                  decoration: const InputDecoration(
                    hintText: 'Enter full name of the learner',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.textGrey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Learner name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // Parentage/Spouse Input
                _buildFieldLabel('PARENTAGE / SPOUSE NAME', isRequired: true),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _parentageController,
                  style: const TextStyle(color: AppTheme.textBlack),
                  decoration: const InputDecoration(
                    hintText: 'Father or husband name',
                    prefixIcon: Icon(Icons.people_outline, color: AppTheme.textGrey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Parentage/Spouse name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // Gender Selection (Male, Female, Others)
                _buildFieldLabel('GENDER', isRequired: true),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: _gender,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_pin_circle_outlined, color: AppTheme.textGrey),
                  ),
                  items: ['Male', 'Female', 'Others'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _gender = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                // Date of Birth & Automatic Age Calculation
                _buildFieldLabel('DATE OF BIRTH (AUTO-CALCULATES AGE)', isRequired: true),
                const SizedBox(height: 8.0),
                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _dateOfBirth == null ? Colors.grey.shade300 : AppTheme.primaryLime,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined, color: AppTheme.textGrey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dateOfBirth == null
                                ? 'Tap to select Date of Birth'
                                : '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}',
                            style: TextStyle(
                              color: _dateOfBirth == null ? AppTheme.textGrey : AppTheme.textBlack,
                              fontWeight: _dateOfBirth == null ? FontWeight.normal : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (_calculatedAge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLime.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryLime),
                            ),
                            child: Text(
                              'Age: $_calculatedAge Years',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // ID Type Toggle
                _buildFieldLabel('OFFICIAL IDENTIFICATION'),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: _idType,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textGrey),
                  ),
                  items: ['CNIC', 'B-Form', 'Does Not Have Either'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _idType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                // ID Number Field (Conditional)
                if (showIdField) ...[
                  _buildFieldLabel('$_idType NUMBER', isRequired: true),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: _idNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CnicAutoDashInputFormatter(),
                    ],
                    style: const TextStyle(color: AppTheme.textBlack),
                    decoration: InputDecoration(
                      hintText: 'XXXXX-XXXXX-X',
                      prefixIcon: const Icon(Icons.credit_card_outlined, color: AppTheme.textGrey),
                    ),
                    validator: (value) {
                      if (showIdField) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide $_idType details';
                        }
                        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length != 11) {
                          return '$_idType must be 11 digits (XXXXX-XXXXX-X)';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),
                ],

                // Province Dropdown (7 Provinces of Pakistan)
                _buildFieldLabel('PROVINCE / REGION', isRequired: true),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: _province,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.domain_outlined, color: AppTheme.textGrey),
                  ),
                  items: DistrictsData.provinces.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _province = value;
                        final districts = DistrictsData.getDistricts(_province);
                        _district = districts.contains(_district) ? _district : districts.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                // District Dropdown (Cascaded strictly for selected Province)
                _buildFieldLabel('CURRENT DISTRICT (${DistrictsData.getDistricts(_province).length} AVAILABLE)', isRequired: true),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: DistrictsData.getDistricts(_province).contains(_district)
                      ? _district
                      : DistrictsData.getDistricts(_province).first,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.map_outlined, color: AppTheme.textGrey),
                  ),
                  items: DistrictsData.getDistricts(_province).map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _district = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                // Real Belonging/Origin
                _buildFieldLabel('PERMANENT ORIGIN / REAL BELONGING', isRequired: true),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _originController,
                  style: const TextStyle(color: AppTheme.textBlack),
                  decoration: const InputDecoration(
                    hintText: 'E.g., Swat, KP',
                    prefixIcon: Icon(Icons.home_outlined, color: AppTheme.textGrey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Permanent origin is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // Occupation
                _buildFieldLabel('CURRENT OCCUPATION', isRequired: true),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: _occupation,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.work_outline, color: AppTheme.textGrey),
                  ),
                  items: _occupations.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _occupation = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20.0),

                // Starting Literacy
                _buildFieldLabel('STARTING LITERACY LEVEL', isRequired: true),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  value: _literacyLevel,
                  dropdownColor: AppTheme.cardLight,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.history_edu_outlined, color: AppTheme.textGrey),
                  ),
                  items: _literacyLevels.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val, style: const TextStyle(color: AppTheme.textBlack)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _literacyLevel = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 40.0),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    child: const Text('ENROLL LEARNER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
