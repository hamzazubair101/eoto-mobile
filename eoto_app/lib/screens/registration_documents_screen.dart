import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../utils/app_theme.dart';
import '../utils/districts_data.dart';
import '../controllers/registration_controller.dart';
import '../services/azure_storage_service.dart';
import 'registration_otp_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationDocumentsScreen extends StatefulWidget {
  final String role; // 'student' or 'not_student'

  const RegistrationDocumentsScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<RegistrationDocumentsScreen> createState() => _RegistrationDocumentsScreenState();
}

class _RegistrationDocumentsScreenState extends State<RegistrationDocumentsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingDocs = false;
  
  // Dropdown / Selection states
  String _selectedProvince = 'Punjab';
  String? _selectedDistrict;
  String? _selectedQualification;
  final TextEditingController _instituteSearchController = TextEditingController();

  String _selectedIdType = 'CNIC'; // Default to CNIC
  XFile? _cnicFrontFile;
  XFile? _cnicBackFile;
  XFile? _academicProofFile;

  List<String> get _districts => DistrictsData.getDistricts(_selectedProvince);
  final List<String> _qualifications = [
    'Matriculation / Grade 10', 
    'Intermediate / Grade 12', 
    'Bachelors / Undergraduate', 
    'Masters / Postgraduate', 
    'PhD'
  ];

  @override
  void dispose() {
    _instituteSearchController.dispose();
    super.dispose();
  }

  Future<void> _handlePickFile(String target) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() {
        if (target == 'FRONT') {
          _cnicFrontFile = file;
        } else if (target == 'BACK') {
          _cnicBackFile = file;
        } else if (target == 'ACADEMIC') {
          _academicProofFile = file;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select file: $e')),
      );
    }
  }

  bool _isNextEnabled() {
    // District and Qualification are mandatory
    if (_selectedDistrict == null || _selectedQualification == null) return false;
    
    // If student, institute name must be filled
    if (widget.role == 'student' && _instituteSearchController.text.trim().isEmpty) return false;

    // CNIC needs front and back; B-Form needs only one document
    final bool idProofUploaded = _selectedIdType == 'CNIC'
        ? (_cnicFrontFile != null && _cnicBackFile != null)
        : (_cnicFrontFile != null); // B-Form uses Front slot

    // Student needs academic proof; non-students do not
    final bool academicUploaded = widget.role == 'student'
        ? (_academicProofFile != null)
        : true;

    return idProofUploaded && academicUploaded;
  }

  // Premium Custom Search Dialog for Institutes (HCI Optimized)
  void _showInstituteSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        String query = '';
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('registered_institutes').snapshots(),
          builder: (context, snapshot) {
            List<String> liveInstitutes = [];
            String filterType = 'University';
            if (_selectedQualification == 'Matriculation / Grade 10') {
              filterType = 'School';
            } else if (_selectedQualification == 'Intermediate / Grade 12') {
              filterType = 'College';
            }

            if (snapshot.hasData) {
              liveInstitutes = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final String type = data['type'] ?? 'University';
                return type.toLowerCase().trim() == filterType.toLowerCase().trim();
              })
              .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
            }

            // Fallback static list if Firebase list is empty
            if (liveInstitutes.isEmpty) {
              if (filterType == 'School') {
                liveInstitutes = [
                  'Army Public School (APS)',
                  'Beaconhouse School System',
                  'The City School',
                  'Lahore Grammar School (LGS)',
                  'Divisional Public School (DPS)',
                  'Islamabad Model School for Girls (IMSG)',
                ];
              } else if (filterType == 'College') {
                liveInstitutes = [
                  'Government College University (GCU) Lahore',
                  'Forman Christian College (FCCU)',
                  'Punjab Group of Colleges (PGC)',
                  'Lahore College for Women University (LCWU)',
                  'Islamabad Model College for Boys (IMCB)',
                ];
              } else {
                liveInstitutes = [
                  'COMSATS University',
                  'National University of Sciences and Technology (NUST)',
                  'University of the Punjab (PU)',
                  'Peshawar University',
                  'Capital University of Science and Technology (CUST)',
                  'FAST National University',
                ];
              }
            }

            // Ensure we still append "NONE"
            if (!liveInstitutes.contains('NONE')) {
              liveInstitutes.add('NONE');
            }

            return StatefulBuilder(
              builder: (context, setModalState) {
                final filtered = liveInstitutes.where((inst) {
                  return inst.toLowerCase().contains(query.toLowerCase());
                }).toList();

                return Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Institution',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      // Search Field inside Bottom Sheet
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            hintText: 'Type school or university name...',
                            hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: Color(0xFF8E8E93)),
                            filled: false,
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              query = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFFF2F2F7)),
                          itemBuilder: (context, index) {
                            final inst = filtered[index];
                            final isCust = inst.contains('CUST') || inst.contains('Capital University');

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                inst,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: isCust ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isCust 
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLime.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'CUST',
                                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _instituteSearchController.text = inst;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchablePill({
    required String hintText,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty ? hintText : controller.text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: controller.text.isEmpty ? const Color(0xFF8E8E93) : Colors.black,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.search, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required String hintText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          hint: Text(hintText, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
          dropdownColor: Colors.white,
          decoration: const InputDecoration(
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8E8E93)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item, 
                style: const TextStyle(color: Colors.black, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCNICUploadBox(String title, XFile? file, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: file != null ? AppTheme.primaryLime.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null ? AppTheme.primaryLime : const Color(0xFFD1D1D6),
              style: BorderStyle.solid,
              width: file != null ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                file != null ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                color: file != null ? Colors.green[800] : const Color(0xFF4A5500),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: file != null ? Colors.green[800] : Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (file != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Icon(Icons.check_circle, color: AppTheme.primaryLime, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNextStep() async {
    if (!_isNextEnabled() || _isUploadingDocs) return;

    setState(() => _isUploadingDocs = true);

    // Save details and documents to provider
    final controller = Provider.of<RegistrationController>(context, listen: false);
    final String userIdentifier = controller.cnic?.replaceAll(RegExp(r'[^0-9]'), '') ??
        controller.phone?.replaceAll(RegExp(r'[^0-9]'), '') ??
        DateTime.now().millisecondsSinceEpoch.toString();

    String? frontDocUrl;
    String? backDocUrl;
    String? academicDocUrl;

    // 1. Process CNIC / B-Form Front
    if (_cnicFrontFile != null) {
      try {
        final bytes = await _cnicFrontFile!.readAsBytes();
        final azureUrl = await AzureStorageService.uploadRegistrationDocBytes(
          bytes: bytes,
          userId: userIdentifier,
          docType: 'cnic_front',
          fileName: _cnicFrontFile!.name,
        );
        final ext = _cnicFrontFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        frontDocUrl = azureUrl ?? 'data:$ext;base64,${base64Encode(bytes)}';
        controller.cnicFrontUrl = frontDocUrl;
      } catch (e) {
        debugPrint('Error processing cnic_front: $e');
      }
    }

    // 2. Process CNIC Back
    if (_cnicBackFile != null) {
      try {
        final bytes = await _cnicBackFile!.readAsBytes();
        final azureUrl = await AzureStorageService.uploadRegistrationDocBytes(
          bytes: bytes,
          userId: userIdentifier,
          docType: 'cnic_back',
          fileName: _cnicBackFile!.name,
        );
        final ext = _cnicBackFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        backDocUrl = azureUrl ?? 'data:$ext;base64,${base64Encode(bytes)}';
        controller.cnicBackUrl = backDocUrl;
      } catch (e) {
        debugPrint('Error processing cnic_back: $e');
      }
    }

    // 3. Process Academic Proof
    if (_academicProofFile != null) {
      try {
        final bytes = await _academicProofFile!.readAsBytes();
        final azureUrl = await AzureStorageService.uploadRegistrationDocBytes(
          bytes: bytes,
          userId: userIdentifier,
          docType: 'academic_proof',
          fileName: _academicProofFile!.name,
        );
        final ext = _academicProofFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        academicDocUrl = azureUrl ?? 'data:$ext;base64,${base64Encode(bytes)}';
        controller.instituteIdUrl = academicDocUrl;
      } catch (e) {
        debugPrint('Error processing academic_proof: $e');
      }
    }

    controller.setDocuments(
      province: _selectedProvince,
      district: _selectedDistrict,
      qualification: _selectedQualification,
      institute: widget.role == 'student' ? _instituteSearchController.text.trim() : 'N/A',
      instituteId: academicDocUrl ?? _academicProofFile?.path ?? '',
      type: _selectedIdType,
      frontUrl: frontDocUrl ?? _cnicFrontFile?.path ?? '',
      backUrl: backDocUrl ?? _cnicBackFile?.path,
    );

    if (mounted) {
      setState(() => _isUploadingDocs = false);
      // Redirect directly to the Phone/Email OTP Verification page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RegistrationOtpScreen(
            role: widget.role,
            email: controller.email ?? 'your email',
            phone: controller.phone ?? '',
          ),
        ),
      );
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
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.language, color: Color(0xFF8E8E93), size: 20),
            label: const Text(
              'EN',
              style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.bold, fontSize: 13),
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
              // Progress Bar (Step 3 of 4, 75%)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STEP 3 OF 4',
                    style: TextStyle(
                      color: Color(0xFF8E8E93), 
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '75%',
                    style: TextStyle(
                      color: Colors.grey[600], 
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
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
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppTheme.primaryLime, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 36),

              // Headers
              const Text(
                'Academic Details &\nDocuments',
                style: TextStyle(
                  color: Colors.black, 
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please select your institution and upload the required files.',
                style: TextStyle(
                  color: Color(0xFF636366), 
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Province dropdown field
              const Text(
                'PROVINCE / REGION',
                style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              _buildDropdownPill(
                hintText: 'Select Province...',
                value: _selectedProvince,
                items: DistrictsData.provinces,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedProvince = value;
                      final available = DistrictsData.getDistricts(value);
                      if (_selectedDistrict != null && !available.contains(_selectedDistrict)) {
                        _selectedDistrict = available.first;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // District dropdown field
              Text(
                'DISTRICT NAME (${_districts.length} AVAILABLE)',
                style: const TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              _buildDropdownPill(
                hintText: 'Select District...',
                value: _selectedDistrict != null && _districts.contains(_selectedDistrict)
                    ? _selectedDistrict
                    : null,
                items: _districts,
                onChanged: (value) => setState(() => _selectedDistrict = value),
              ),
              const SizedBox(height: 24),

              // Qualification dropdown field
              const Text(
                'HIGHEST QUALIFICATION',
                style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              _buildDropdownPill(
                hintText: 'Select Qualification...',
                value: _selectedQualification,
                items: _qualifications,
                onChanged: (value) => setState(() => _selectedQualification = value),
              ),
              const SizedBox(height: 24),

              // Institute search field
              if (widget.role == 'student') ...[
                const Text(
                  'INSTITUTE NAME',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                _buildSearchablePill(
                  hintText: 'Search Institute...',
                  controller: _instituteSearchController,
                  onTap: _showInstituteSearchDialog,
                ),
                const SizedBox(height: 32),
              ],

              // Identity Proof Toggle switch pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Identity Proof',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    '(Max 5MB)',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 52,
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIdType = 'CNIC'),
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _selectedIdType == 'CNIC' ? AppTheme.primaryLime : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CNIC',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: _selectedIdType == 'CNIC' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIdType = 'B-Form'),
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _selectedIdType == 'B-Form' ? AppTheme.primaryLime : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'B-Form',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: _selectedIdType == 'B-Form' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Upload fields for Front / Back CNIC
              if (_selectedIdType == 'CNIC') ...[
                Row(
                  children: [
                    _buildCNICUploadBox('UPLOAD FRONT', _cnicFrontFile, () => _handlePickFile('FRONT')),
                    const SizedBox(width: 16),
                    _buildCNICUploadBox('UPLOAD BACK', _cnicBackFile, () => _handlePickFile('BACK')),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    _buildCNICUploadBox('UPLOAD B-FORM', _cnicFrontFile, () => _handlePickFile('FRONT')),
                  ],
                ),
              ],
              const SizedBox(height: 36),

              // Academic Proof Card
              if (widget.role == 'student') ...[
                const Text(
                  'Academic Proof',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _handlePickFile('ACADEMIC'),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _academicProofFile != null ? AppTheme.primaryLime.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _academicProofFile != null ? AppTheme.primaryLime : const Color(0xFFD1D1D6),
                        style: BorderStyle.solid,
                        width: _academicProofFile != null ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.drive_folder_upload_outlined,
                          color: Color(0xFF4A5500),
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _academicProofFile != null
                              ? 'Institute ID / Degree Uploaded!'
                              : 'Tap to upload Institute ID / Degree',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PDF, JPG or PNG formats',
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],

              // Underlined Next Step Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isNextEnabled() && !_isUploadingDocs) ? _handleNextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNextEnabled() ? AppTheme.primaryLime : const Color(0xFFE5E5EA),
                    foregroundColor: _isNextEnabled() ? Colors.black : const Color(0xFF8E8E93),
                    minimumSize: const Size(double.infinity, 58),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29),
                    ),
                  ),
                  child: _isUploadingDocs
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(
                          'NEXT STEP',
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold,
                            decoration: _isNextEnabled() ? TextDecoration.underline : TextDecoration.none,
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
    );
  }
}
