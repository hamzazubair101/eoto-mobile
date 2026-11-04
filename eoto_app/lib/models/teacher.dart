/// Domain model representing a Volunteer Teacher's profile data.
class TeacherModel {
  final String role;
  final String fullName;
  final String? fatherName;
  final String? dob;
  final String email;
  final String phone;
  final String cnic;
  final String? permanentAddress;
  final String? mailingAddress;
  final String? postalCode;
  final String? province;
  final String district;
  final String qualification;
  final String instituteName;
  final String instituteIdUrl;
  final String idType;
  final String cnicFrontUrl;
  final String cnicBackUrl;
  final String status;
  final String assignedFocalPersonName;
  final String assignedFocalPersonEmail;
  final String routingType;

  const TeacherModel({
    required this.role,
    required this.fullName,
    this.fatherName,
    this.dob,
    required this.email,
    required this.phone,
    required this.cnic,
    this.permanentAddress,
    this.mailingAddress,
    this.postalCode,
    this.province,
    required this.district,
    required this.qualification,
    required this.instituteName,
    required this.instituteIdUrl,
    required this.idType,
    required this.cnicFrontUrl,
    required this.cnicBackUrl,
    required this.status,
    required this.assignedFocalPersonName,
    required this.assignedFocalPersonEmail,
    required this.routingType,
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    return TeacherModel(
      role: map['role'] ?? '',
      fullName: map['fullName'] ?? map['name'] ?? '',
      fatherName: map['fatherName'] ?? map['father_name'],
      dob: map['dob'] ?? map['dateOfBirth'],
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      cnic: map['cnic'] ?? '',
      permanentAddress: map['permanentAddress'] ?? map['address'],
      mailingAddress: map['mailingAddress'],
      postalCode: map['postalCode'] ?? map['zipCode'],
      province: map['province'],
      district: map['district'] ?? '',
      qualification: map['qualification'] ?? '',
      instituteName: map['instituteName'] ?? map['institute'] ?? '',
      instituteIdUrl: map['instituteIdUrl'] ?? '',
      idType: map['idType'] ?? 'CNIC',
      cnicFrontUrl: map['cnicFrontUrl'] ?? '',
      cnicBackUrl: map['cnicBackUrl'] ?? '',
      status: map['status'] ?? 'pending',
      assignedFocalPersonName: map['assignedFocalPersonName'] ?? '',
      assignedFocalPersonEmail: map['assignedFocalPersonEmail'] ?? '',
      routingType: map['routingType'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'fullName': fullName,
      'fatherName': fatherName,
      'dob': dob,
      'email': email,
      'phone': phone,
      'cnic': cnic,
      'permanentAddress': permanentAddress,
      'mailingAddress': mailingAddress,
      'postalCode': postalCode,
      'province': province,
      'district': district,
      'qualification': qualification,
      'instituteName': instituteName,
      'instituteIdUrl': instituteIdUrl,
      'idType': idType,
      'cnicFrontUrl': cnicFrontUrl,
      'cnicBackUrl': cnicBackUrl,
      'status': status,
      'assignedFocalPersonName': assignedFocalPersonName,
      'assignedFocalPersonEmail': assignedFocalPersonEmail,
      'routingType': routingType,
    };
  }
}

