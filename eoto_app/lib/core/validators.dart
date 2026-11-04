/// Single Responsibility Principle (SRP) validators utility.
/// Encapsulates all domain input validation rules, decoupling business logic from UI widgets.
class EotoValidators {
  /// Regular expression to match valid names (letters and spaces only)
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s]+$');

  /// Regular expression for general email matching
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  /// Regular expression for Pakistani mobile phone numbers (11 digits starting with 03)
  static final RegExp _phoneRegex = RegExp(r'^03[0-9]{9}$');

  /// Validates a full name or father's name.
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (!_nameRegex.hasMatch(value.trim())) {
      return '$fieldName must contain letters and spaces only';
    }
    return null;
  }

  /// Validates a CNIC or B-Form number.
  /// Expects exactly 13 digits (raw input numeric representation).
  static String? validateCNIC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CNIC/B-Form is required';
    }
    // Remove dashes if any were somehow entered, although digit limiters are applied in TextField
    final cleanValue = value.replaceAll('-', '').trim();
    if (cleanValue.length != 13) {
      return 'Must be exactly 13 digits';
    }
    if (int.tryParse(cleanValue) == null) {
      return 'Must contain digits only';
    }
    return null;
  }

  /// Validates a Pakistani mobile number.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleanValue = value.trim();
    if (!_phoneRegex.hasMatch(cleanValue)) {
      return 'Must be 11 digits starting with 03';
    }
    return null;
  }

  /// Validates an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final cleanValue = value.trim();
    if (!_emailRegex.hasMatch(cleanValue)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates standard required fields (e.g. drop downs or textual entries).
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
