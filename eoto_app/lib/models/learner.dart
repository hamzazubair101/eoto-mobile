/// Session Log domain model representing a single teaching class event.
class SessionLog {
  final String date;
  final String duration;
  final String remarks;
  final double latitude;
  final double longitude;

  const SessionLog({
    required this.date,
    required this.duration,
    required this.remarks,
    required this.latitude,
    required this.longitude,
  });

  factory SessionLog.fromMap(Map<String, dynamic> map) {
    return SessionLog(
      date: map['date'] ?? 'N/A',
      duration: map['duration'] ?? '60 min',
      remarks: map['remarks'] ?? '',
      latitude: (map['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'duration': duration,
      'remarks': remarks,
      'lat': latitude,
      'lng': longitude,
    };
  }
}

/// Certificate Logistics state container model tracking multi-tier physical handoff.
class CertificateLogistics {
  final bool approved;
  final bool dispatched;
  final bool receivedByFocal;
  final bool handoverConfirmed;

  const CertificateLogistics({
    this.approved = false,
    this.dispatched = false,
    this.receivedByFocal = false,
    this.handoverConfirmed = false,
  });

  factory CertificateLogistics.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CertificateLogistics();
    return CertificateLogistics(
      approved: map['approved'] ?? false,
      dispatched: map['dispatched'] ?? false,
      receivedByFocal: map['receivedByFocal'] ?? false,
      handoverConfirmed: map['handoverConfirmed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'approved': approved,
      'dispatched': dispatched,
      'receivedByFocal': receivedByFocal,
      'handoverConfirmed': handoverConfirmed,
    };
  }

  CertificateLogistics copyWith({
    bool? approved,
    bool? dispatched,
    bool? receivedByFocal,
    bool? handoverConfirmed,
  }) {
    return CertificateLogistics(
      approved: approved ?? this.approved,
      dispatched: dispatched ?? this.dispatched,
      receivedByFocal: receivedByFocal ?? this.receivedByFocal,
      handoverConfirmed: handoverConfirmed ?? this.handoverConfirmed,
    );
  }
}

/// Domain model representing an enrolled illiterate Learner under the LSP principle.
class Learner {
  final String id;
  final String name;
  final String parentage;
  final String idType;
  final String idNumber;
  final String status;
  final double progress;
  final int classesTaught;
  final int totalClasses;
  final String lastSession;
  final String remarks;
  
  // Optional Geographic & Demographic Profile Fields
  final String? province;
  final String? district;
  final String? origin;
  final String? occupation;
  final String? startingLiteracy;
  final String? gender;
  final String? dob;
  final String? dateOfBirth;
  final int? age;

  // Optional Assessment & Certification Fields
  final String? examDate;
  final String? examTime;
  final String? examLocation;
  final String? examGrade;
  final CertificateLogistics? certificateLogistics;
  final List<SessionLog> sessionLogs;

  const Learner({
    required this.id,
    required this.name,
    required this.parentage,
    required this.idType,
    required this.idNumber,
    required this.status,
    required this.progress,
    required this.classesTaught,
    required this.totalClasses,
    required this.lastSession,
    required this.remarks,
    this.province,
    this.district,
    this.origin,
    this.occupation,
    this.startingLiteracy,
    this.gender,
    this.dob,
    this.dateOfBirth,
    this.age,
    this.examDate,
    this.examTime,
    this.examLocation,
    this.examGrade,
    this.certificateLogistics,
    this.sessionLogs = const [],
  });

  factory Learner.fromMap(Map<String, dynamic> map) {
    var rawLogs = map['sessionLogs'] as List?;
    List<SessionLog> parsedLogs = rawLogs != null
        ? rawLogs.map((log) => SessionLog.fromMap(Map<String, dynamic>.from(log))).toList()
        : [];

    return Learner(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      parentage: map['parentage'] ?? '',
      idType: map['idType'] ?? 'CNIC',
      idNumber: map['idNumber'] ?? '',
      status: map['status'] ?? 'Awaiting Baseline',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      classesTaught: map['classesTaught'] ?? 0,
      totalClasses: map['totalClasses'] ?? 36,
      lastSession: map['lastSession'] ?? 'N/A',
      remarks: map['remarks'] ?? '',
      province: map['province'],
      district: map['district'],
      origin: map['origin'],
      occupation: map['occupation'],
      startingLiteracy: map['startingLiteracy'],
      gender: map['gender'],
      dob: map['dob'] ?? map['dateOfBirth'],
      dateOfBirth: map['dateOfBirth'] ?? map['dob'],
      age: (map['age'] as num?)?.toInt(),
      examDate: map['examDate'],
      examTime: map['examTime'],
      examLocation: map['examLocation'],
      examGrade: map['examGrade'],
      certificateLogistics: map['certificateLogistics'] != null
          ? CertificateLogistics.fromMap(Map<String, dynamic>.from(map['certificateLogistics']))
          : null,
      sessionLogs: parsedLogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentage': parentage,
      'idType': idType,
      'idNumber': idNumber,
      'status': status,
      'progress': progress,
      'classesTaught': classesTaught,
      'totalClasses': totalClasses,
      'lastSession': lastSession,
      'remarks': remarks,
      'province': province,
      'district': district,
      'origin': origin,
      'occupation': occupation,
      'startingLiteracy': startingLiteracy,
      'gender': gender,
      'dob': dob,
      'dateOfBirth': dateOfBirth,
      'age': age,
      'examDate': examDate,
      'examTime': examTime,
      'examLocation': examLocation,
      'examGrade': examGrade,
      'certificateLogistics': certificateLogistics?.toMap(),
      'sessionLogs': sessionLogs.map((log) => log.toMap()).toList(),
    };
  }

  Learner copyWith({
    String? id,
    String? name,
    String? parentage,
    String? idType,
    String? idNumber,
    String? status,
    double? progress,
    int? classesTaught,
    int? totalClasses,
    String? lastSession,
    String? remarks,
    String? province,
    String? district,
    String? origin,
    String? occupation,
    String? startingLiteracy,
    String? gender,
    String? dob,
    String? dateOfBirth,
    int? age,
    String? examDate,
    String? examTime,
    String? examLocation,
    String? examGrade,
    CertificateLogistics? certificateLogistics,
    List<SessionLog>? sessionLogs,
  }) {
    return Learner(
      id: id ?? this.id,
      name: name ?? this.name,
      parentage: parentage ?? this.parentage,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      classesTaught: classesTaught ?? this.classesTaught,
      totalClasses: totalClasses ?? this.totalClasses,
      lastSession: lastSession ?? this.lastSession,
      remarks: remarks ?? this.remarks,
      province: province ?? this.province,
      district: district ?? this.district,
      origin: origin ?? this.origin,
      occupation: occupation ?? this.occupation,
      startingLiteracy: startingLiteracy ?? this.startingLiteracy,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      examDate: examDate ?? this.examDate,
      examTime: examTime ?? this.examTime,
      examLocation: examLocation ?? this.examLocation,
      examGrade: examGrade ?? this.examGrade,
      certificateLogistics: certificateLogistics ?? this.certificateLogistics,
      sessionLogs: sessionLogs ?? this.sessionLogs,
    );
  }
}
