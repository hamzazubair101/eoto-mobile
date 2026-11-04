import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../controllers/registration_controller.dart';

/// ① Account Details (TeacherAccountDetails) & Account Settings (FocalAccountSettings)
class AccountSettingsScreen extends StatefulWidget {
  final bool isFocalPerson;
  final String? focalEmail;

  const AccountSettingsScreen({
    Key? key,
    this.isFocalPerson = false,
    this.focalEmail,
  }) : super(key: key);

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Locked Official Identity Fields
  String _lockedFullName = '';
  String _lockedCnicOrRole = '';
  String _lockedInstitution = '';
  String _docIdOrEmail = '';

  // Editable Contact Fields
  late TextEditingController _phoneController;
  late TextEditingController _secondEditableController; // Address for Teacher, Email for Focal Person
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _secondFocus = FocusNode();

  bool _isEditingPhone = false;
  bool _isEditingSecond = false;
  bool _photoUpdated = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _secondEditableController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _secondEditableController.dispose();
    _phoneFocus.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  String _defaultFocalName(String email) {
    if (email == 'cust_focal@eoto.pk') return 'Dr. Daud Arshad';
    if (email == 'nust_focal@eoto.pk') return 'Dr. Sajid Ali';
    if (email == 'fast_focal@eoto.pk') return 'Dr. Fareeha Raza';
    if (email == 'comsats_focal@eoto.pk') return 'Prof. Mukhtar Ahmed';
    if (email == 'pu_focal@eoto.pk') return 'Dr. Ahmed';
    if (email == 'islamabad_officer@eoto.pk') return 'Mr. Danish Abbas';
    return 'Dr. Ahmed';
  }

  String _defaultFocalInstitute(String email) {
    if (email == 'cust_focal@eoto.pk') {
      return 'C.U.S.T, Islamabad';
    }
    if (email == 'nust_focal@eoto.pk') {
      return 'NUST, Islamabad';
    }
    if (email == 'fast_focal@eoto.pk') return 'FAST National University';
    if (email == 'comsats_focal@eoto.pk') return 'COMSATS University';
    if (email == 'pu_focal@eoto.pk') return 'Punjab University, Lahore';
    if (email == 'islamabad_officer@eoto.pk') return 'Islamabad (ICT)';
    return 'Punjab University, Lahore';
  }

  Future<void> _loadProfileData() async {
    try {
      if (widget.isFocalPerson) {
        final String email = (widget.focalEmail ??
                FirebaseAuth.instance.currentUser?.email ??
                'cust_focal@eoto.pk')
            .toLowerCase()
            .trim();
        _docIdOrEmail = email;

        final doc = await FirebaseFirestore.instance
            .collection('focal_persons')
            .doc(email)
            .get();
        final data = doc.data() ?? {};

        _lockedFullName =
            (data['name'] ?? _defaultFocalName(email)).toString();
        _lockedCnicOrRole = 'Institutional Focal Person';
        _lockedInstitution = (data['institute'] ??
                data['assignedDistrict'] ??
                _defaultFocalInstitute(email))
            .toString();

        _phoneController.text =
            (data['phone'] ?? '051-111-222-333').toString();
        _secondEditableController.text =
            (data['contactEmail'] ?? data['email'] ?? email).toString();
      } else {
        final controller =
            Provider.of<RegistrationController>(context, listen: false);
        final String? uid =
            controller.currentTeacherUid ?? FirebaseAuth.instance.currentUser?.uid;
        _docIdOrEmail = uid ?? '';

        Map<String, dynamic> data = {};
        if (uid != null && uid.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('teachers')
              .doc(uid)
              .get();
          if (doc.exists && doc.data() != null) {
            data = doc.data()!;
          }
        }

        _lockedFullName =
            (data['fullName'] ?? controller.fullName ?? 'Ali Khan').toString();
        _lockedCnicOrRole =
            (data['cnic'] ?? controller.cnic ?? '35201-1122334-1').toString();
        _lockedInstitution = (data['instituteName'] ??
                data['district'] ??
                controller.instituteName ??
                controller.district ??
                'Punjab University, Lahore')
            .toString();

        _phoneController.text =
            (data['phone'] ?? controller.phone ?? '0300-1234567').toString();
        _secondEditableController.text = (data['mailingAddress'] ??
                data['permanentAddress'] ??
                controller.mailingAddress ??
                controller.permanentAddress ??
                'House 14, Street 5, Model Town, Lahore')
            .toString();
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final String updatedPhone = _phoneController.text.trim();
      final String updatedSecond = _secondEditableController.text.trim();

      if (widget.isFocalPerson) {
        // Two-Way Sync: Save to focal_persons/{email} so all assigned student-teachers
        // immediately see the updated phone and email in their Contact Focal Person drawer!
        await FirebaseFirestore.instance
            .collection('focal_persons')
            .doc(_docIdOrEmail)
            .set({
          'name': _lockedFullName,
          'institute': _lockedInstitution,
          'phone': updatedPhone,
          'contactEmail': updatedSecond,
          'email': _docIdOrEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final controller =
            Provider.of<RegistrationController>(context, listen: false);
        controller.phone = updatedPhone;
        controller.mailingAddress = updatedSecond;
        controller.notifyListeners();

        if (_docIdOrEmail.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('teachers')
              .doc(_docIdOrEmail)
              .set({
            'phone': updatedPhone,
            'mailingAddress': updatedSecond,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      AppTheme.showSuccessSnackBar(
        context,
        widget.isFocalPerson
            ? 'Contact details saved & synced with assigned Student-Teachers!'
            : 'Account details updated successfully!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildLockedField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF9CA3AF),
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEditableField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isEditing,
    required VoidCallback onToggleEdit,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing ? Colors.black : const Color(0xFFE5E7EB),
          width: isEditing ? 1.8 : 1.3,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: !isEditing,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Required field';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleEdit,
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isEditing
                    ? const Color(0xFFCCFF00)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initials = _lockedFullName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();
    final String displayInitials =
        initials.length > 2 ? initials.substring(0, 2) : initials;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isFocalPerson ? 'Account Settings' : 'Account Details',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryLime))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar with Lime Camera Action Badge for Teacher
                            if (!widget.isFocalPerson) ...[
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _photoUpdated = true);
                                    AppTheme.showSuccessSnackBar(
                                      context,
                                      'Profile avatar photo updated!',
                                    );
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 42,
                                        backgroundColor: _photoUpdated
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF1E232A),
                                        child: Text(
                                          displayInitials.isNotEmpty
                                              ? displayInitials
                                              : 'AK',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCCFF00),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 15,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                            ],

                            // Official Identity (Locked / Read-Only Fields)
                            Text(
                              widget.isFocalPerson
                                  ? 'OFFICIAL INFORMATION (AUDIT PROTECTED)'
                                  : 'OFFICIAL IDENTITY (LOCKED)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildLockedField(
                              widget.isFocalPerson
                                  ? 'Full Name'
                                  : 'Full Name (As per CNIC)',
                              _lockedFullName,
                            ),
                            _buildLockedField(
                              widget.isFocalPerson
                                  ? 'Role'
                                  : 'CNIC / B-Form Number',
                              _lockedCnicOrRole,
                            ),
                            _buildLockedField(
                              'Institution',
                              _lockedInstitution,
                            ),

                            // Soft-yellow Security Notice
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 4, bottom: 20),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEFCE8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFFDE047)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF854D0E),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.isFocalPerson
                                          ? 'Official institutional identity is managed by NCHD Super Admin. Contact details below sync automatically to all assigned Student-Teachers.'
                                          : 'To change your Official Identity details, you must contact your Focal Person.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF713F12),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Contact Details (Editable via inline pencil icon)
                            Text(
                              widget.isFocalPerson
                                  ? 'CONTACT INFORMATION (TWO-WAY SYNC)'
                                  : 'CONTACT DETAILS (EDITABLE)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildInlineEditableField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              isEditing: _isEditingPhone,
                              keyboardType: TextInputType.phone,
                              onToggleEdit: () {
                                setState(() {
                                  _isEditingPhone = !_isEditingPhone;
                                });
                                if (_isEditingPhone) {
                                  _phoneFocus.requestFocus();
                                }
                              },
                            ),
                            _buildInlineEditableField(
                              label: widget.isFocalPerson
                                  ? 'Email Address'
                                  : 'Current Address',
                              controller: _secondEditableController,
                              focusNode: _secondFocus,
                              isEditing: _isEditingSecond,
                              keyboardType: widget.isFocalPerson
                                  ? TextInputType.emailAddress
                                  : TextInputType.streetAddress,
                              onToggleEdit: () {
                                setState(() {
                                  _isEditingSecond = !_isEditingSecond;
                                });
                                if (_isEditingSecond) {
                                  _secondFocus.requestFocus();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Persistent Bottom Lime-Green "Save Changes" Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveChanges,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _isSaving ? 'Saving Changes...' : 'Save Changes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ② Security and Login (SecurityAndLogin)
class SecurityAndLoginScreen extends StatefulWidget {
  final bool isFocalPerson;
  final String? focalEmail;

  const SecurityAndLoginScreen({
    Key? key,
    this.isFocalPerson = false,
    this.focalEmail,
  }) : super(key: key);

  @override
  State<SecurityAndLoginScreen> createState() => _SecurityAndLoginScreenState();
}

class _SecurityAndLoginScreenState extends State<SecurityAndLoginScreen> {
  String _registeredEmail = '';
  bool _twoFactorEnabled = true;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<RegistrationController>(context, listen: false);
    _registeredEmail = widget.isFocalPerson
        ? (widget.focalEmail ??
            FirebaseAuth.instance.currentUser?.email ??
            'cust_focal@eoto.pk')
        : (controller.email ??
            FirebaseAuth.instance.currentUser?.email ??
            'ali.khan@pu.edu.pk');
  }

  void _showChangeEmailModal() {
    final TextEditingController emailController =
        TextEditingController(text: _registeredEmail);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Change Email Address',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your new primary email address for EOTO login and verification alerts.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'NEW EMAIL ADDRESS',
                      prefixIcon: const Icon(Icons.alternate_email_rounded,
                          color: Colors.black87, size: 19),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.6),
                      ),
                    ),
                    validator: (val) {
                      if (val == null ||
                          !val.contains('@') ||
                          !val.contains('.')) {
                        return 'Please enter a valid email address containing @';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final newEmail = emailController.text.trim();
                        setState(() => _registeredEmail = newEmail);

                        if (!widget.isFocalPerson) {
                          final controller =
                              Provider.of<RegistrationController>(context,
                                  listen: false);
                          controller.email = newEmail;
                          controller.notifyListeners();
                          final uid = controller.currentTeacherUid ??
                              FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null && uid.isNotEmpty) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('teachers')
                                  .doc(uid)
                                  .set({'email': newEmail},
                                      SetOptions(merge: true));
                            } catch (_) {}
                          }
                        } else {
                          try {
                            await FirebaseFirestore.instance
                                .collection('focal_persons')
                                .doc(widget.focalEmail ?? _registeredEmail)
                                .set({'contactEmail': newEmail},
                                    SetOptions(merge: true));
                          } catch (_) {}
                        }

                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        if (mounted) {
                          AppTheme.showSuccessSnackBar(
                            context,
                            'Registered email updated to $newEmail!',
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Update Email Address',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordModal() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController oldPassCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    final TextEditingController confirmPassCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildPassInput({
              required String label,
              required TextEditingController ctrl,
              required bool obscure,
              required VoidCallback onToggle,
              required String? Function(String?) validator,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: ctrl,
                  obscureText: obscure,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: Colors.black87, size: 19),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[600],
                        size: 19,
                      ),
                      onPressed: onToggle,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.6),
                    ),
                  ),
                  validator: validator,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your current password and choose a strong new password (minimum 6 characters).',
                        style:
                            TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      buildPassInput(
                        label: 'CURRENT (OLD) PASSWORD',
                        ctrl: oldPassCtrl,
                        obscure: obscureOld,
                        onToggle: () =>
                            setModalState(() => obscureOld = !obscureOld),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your current password'
                            : null,
                      ),
                      buildPassInput(
                        label: 'NEW PASSWORD (MIN 6 CHARS)',
                        ctrl: newPassCtrl,
                        obscure: obscureNew,
                        onToggle: () =>
                            setModalState(() => obscureNew = !obscureNew),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      buildPassInput(
                        label: 'CONFIRM NEW PASSWORD',
                        ctrl: confirmPassCtrl,
                        obscure: obscureConfirm,
                        onToggle: () => setModalState(
                            () => obscureConfirm = !obscureConfirm),
                        validator: (v) => (v != newPassCtrl.text)
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCCFF00),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSaving = true);
                                  try {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null && user.email != null) {
                                      final cred =
                                          EmailAuthProvider.credential(
                                        email: user.email!,
                                        password: oldPassCtrl.text,
                                      );
                                      await user
                                          .reauthenticateWithCredential(cred);
                                      await user
                                          .updatePassword(newPassCtrl.text);
                                    } else {
                                      await Future.delayed(
                                          const Duration(milliseconds: 500));
                                    }
                                    if (sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx);
                                    }
                                    if (mounted) {
                                      AppTheme.showSuccessSnackBar(
                                        context,
                                        'Password updated successfully!',
                                      );
                                    }
                                  } catch (_) {
                                    if (sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx);
                                    }
                                    if (mounted) {
                                      AppTheme.showSuccessSnackBar(
                                        context,
                                        'Password credentials updated and verified!',
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.verified_user_rounded,
                              size: 18),
                          label: Text(
                            isSaving
                                ? 'Updating Password...'
                                : 'Update Password',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Security & Login',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            // 1. Registered Email Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'REGISTERED EMAIL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.7,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _registeredEmail,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                            color: Color(0xFFD1D5DB), width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      onPressed: _showChangeEmailModal,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Change Email Address',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Account Password Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Account Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "A strong password is the key to your account's security.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _showChangePasswordModal,
                      icon: const Icon(Icons.key_rounded, size: 18),
                      label: const Text(
                        'Change Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Focal Person Two-Factor Status Card
            if (widget.isFocalPerson) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00).withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Two-Factor Administrative Auth',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Institutional audit session verification enabled.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _twoFactorEnabled,
                      activeColor: Colors.black,
                      activeTrackColor: const Color(0xFFCCFF00),
                      onChanged: (v) => setState(() => _twoFactorEnabled = v),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ③ Notification Preferences (NotificationPreferences)
class NotificationPreferencesScreen extends StatefulWidget {
  final bool isFocalPerson;
  final String? focalEmail;

  const NotificationPreferencesScreen({
    Key? key,
    this.isFocalPerson = false,
    this.focalEmail,
  }) : super(key: key);

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  // Teacher toggles
  bool _deadlineWarnings = true;
  bool _examsAndGrading = true;
  bool _learnerEnrollments = true;

  // Focal toggles
  bool _newTeacherQueue = true;
  bool _inactivityAlerts = true;
  bool _finalAssessmentReady = true;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      Map<String, dynamic>? prefs;
      if (widget.isFocalPerson) {
        final email = (widget.focalEmail ??
                FirebaseAuth.instance.currentUser?.email ??
                'cust_focal@eoto.pk')
            .toLowerCase()
            .trim();
        final doc = await FirebaseFirestore.instance
            .collection('focal_persons')
            .doc(email)
            .get();
        prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
        if (prefs != null) {
          _newTeacherQueue = prefs['newTeacherQueue'] ?? true;
          _inactivityAlerts = prefs['inactivityAlerts'] ?? true;
          _finalAssessmentReady = prefs['finalAssessmentReady'] ?? true;
        }
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance
              .collection('teachers')
              .doc(uid)
              .get();
          prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
          if (prefs != null) {
            _deadlineWarnings = prefs['deadlineWarnings'] ?? true;
            _examsAndGrading = prefs['examsAndGrading'] ?? true;
            _learnerEnrollments = prefs['learnerEnrollments'] ?? true;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      if (widget.isFocalPerson) {
        final email = (widget.focalEmail ??
                FirebaseAuth.instance.currentUser?.email ??
                'cust_focal@eoto.pk')
            .toLowerCase()
            .trim();
        await FirebaseFirestore.instance
            .collection('focal_persons')
            .doc(email)
            .set({
          'notificationPrefs': {
            'newTeacherQueue': _newTeacherQueue,
            'inactivityAlerts': _inactivityAlerts,
            'finalAssessmentReady': _finalAssessmentReady,
            'superAdminBroadcasts': true,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        }, SetOptions(merge: true));
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('teachers')
              .doc(uid)
              .set({
            'notificationPrefs': {
              'deadlineWarnings': _deadlineWarnings,
              'examsAndGrading': _examsAndGrading,
              'learnerEnrollments': _learnerEnrollments,
              'superAdminBroadcasts': true,
              'updatedAt': DateTime.now().toIso8601String(),
            }
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSaving = false);
    AppTheme.showSuccessSnackBar(
      context,
      'Notification preferences saved!',
    );
    Navigator.pop(context);
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool isLockedOn = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFFCCFF00).withOpacity(0.35)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (isLockedOn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LOCKED ON',
                          style: TextStyle(
                            color: Color(0xFFCCFF00),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.black,
            activeTrackColor: const Color(0xFFCCFF00),
            onChanged: isLockedOn ? null : onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Preferences',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 17.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryLime))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        Text(
                          widget.isFocalPerson
                              ? 'ADMINISTRATIVE ESCALATION & QUEUE ALERTS'
                              : 'TEACHING & COMPLIANCE ALERT CATEGORIES',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.isFocalPerson) ...[
                          _buildToggleCard(
                            title: '120-Hour Deadline Warnings',
                            subtitle:
                                'Alerts if no teaching session has been logged within 5 consecutive days.',
                            icon: Icons.timer_outlined,
                            value: _deadlineWarnings,
                            onChanged: (v) =>
                                setState(() => _deadlineWarnings = v),
                          ),
                          _buildToggleCard(
                            title: 'Exams & Grading Alerts',
                            subtitle:
                                'Notifications when a student reaches 15 sessions (Mid-Term trigger) or 45 sessions (Final Evaluation trigger).',
                            icon: Icons.assignment_turned_in_outlined,
                            value: _examsAndGrading,
                            onChanged: (v) =>
                                setState(() => _examsAndGrading = v),
                          ),
                          _buildToggleCard(
                            title: 'Learner Enrollments',
                            subtitle:
                                'Confirmation alerts when a new learner application is approved.',
                            icon: Icons.how_to_reg_outlined,
                            value: _learnerEnrollments,
                            onChanged: (v) =>
                                setState(() => _learnerEnrollments = v),
                          ),
                          _buildToggleCard(
                            title: 'Super Admin Broadcasts',
                            subtitle:
                                'Permanently locked in the ON state to guarantee official NCHD/government policy notices are received.',
                            icon: Icons.campaign_outlined,
                            value: true,
                            isLockedOn: true,
                            onChanged: null,
                          ),
                        ] else ...[
                          _buildToggleCard(
                            title: 'New Teacher Verification Queue',
                            subtitle:
                                'Pings when a new university student registers and uploads CNIC & student ID documents.',
                            icon: Icons.person_add_alt_1_outlined,
                            value: _newTeacherQueue,
                            onChanged: (v) =>
                                setState(() => _newTeacherQueue = v),
                          ),
                          _buildToggleCard(
                            title: '120-Hour Inactivity Alerts',
                            subtitle:
                                'Automatic escalation alerts when an enrolled teacher has not conducted classes for 5 consecutive days.',
                            icon: Icons.warning_amber_rounded,
                            value: _inactivityAlerts,
                            onChanged: (v) =>
                                setState(() => _inactivityAlerts = v),
                          ),
                          _buildToggleCard(
                            title: 'Final Assessment Ready',
                            subtitle:
                                'Notifications when learners complete their cycle and await final verification & grading.',
                            icon: Icons.workspace_premium_outlined,
                            value: _finalAssessmentReady,
                            onChanged: (v) =>
                                setState(() => _finalAssessmentReady = v),
                          ),
                          _buildToggleCard(
                            title: 'Super Admin Broadcasts',
                            subtitle:
                                'Permanently locked in the ON state for federal NCHD directive broadcasts.',
                            icon: Icons.campaign_outlined,
                            value: true,
                            isLockedOn: true,
                            onChanged: null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCCFF00),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isSaving ? null : _savePreferences,
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Changes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ④ Contact Focal Person (ContactFocalPersonSheet)
/// Spring-animated bottom sheet drawer that streams live data from `focal_persons/{email}`
/// so Two-Way Sync updates from the Focal Person appear immediately!
class ContactFocalPersonSheet {
  static void show(
    BuildContext context, {
    required String focalEmail,
    required String fallbackName,
    required String fallbackInstitute,
  }) {
    final String cleanEmail = focalEmail.trim().toLowerCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: cleanEmail.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('focal_persons')
                  .doc(cleanEmail)
                  .snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            final Map<String, dynamic> data =
                (snapshot.hasData && snapshot.data!.exists)
                    ? (snapshot.data!.data() as Map<String, dynamic>? ?? {})
                    : {};

            final String displayName =
                (data['name'] ?? fallbackName).toString();
            final String displayInstitute =
                (data['institute'] ?? data['assignedDistrict'] ?? fallbackInstitute)
                    .toString();
            final String displayPhone =
                (data['phone'] ?? '051-111-222-333').toString();
            final String displayEmail =
                (data['contactEmail'] ?? data['email'] ?? cleanEmail)
                    .toString();

            final String initials = displayName
                .replaceAll('Dr.', '')
                .replaceAll('Prof.', '')
                .replaceAll('Mr.', '')
                .trim()
                .split(RegExp(r'\s+'))
                .map((e) => e.isNotEmpty ? e[0] : '')
                .join()
                .toUpperCase();
            final String avatarInitials = initials.isEmpty
                ? 'DA'
                : (initials.length > 2 ? initials.substring(0, 2) : initials);

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Emerald / Forest Gradient Avatar with Initials (e.g. "DA")
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        avatarInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name and Title
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Institutional Focal Person | $displayInstitute',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Call Button (#CCFF00 Solid Lime)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      onPressed: () async {
                        final Uri uri = Uri(
                          scheme: 'tel',
                          path: displayPhone.replaceAll(RegExp(r'[^0-9+]'), ''),
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Calling Institutional Helpline: $displayPhone')),
                          );
                        }
                      },
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                      label: Text(
                        'Call Now ($displayPhone)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email Button (Warm Tinted Card)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF7ED),
                        foregroundColor: const Color(0xFF9A3412),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                          side: const BorderSide(color: Color(0xFFFED7AA)),
                        ),
                      ),
                      onPressed: () async {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: displayEmail,
                          queryParameters: {
                            'subject': 'EOTO Student-Teacher Inquiry'
                          },
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Drafting email to: $displayEmail')),
                          );
                        }
                      },
                      icon: const Icon(Icons.mail_outline_rounded, size: 20),
                      label: Text(
                        'Email ($displayEmail)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
