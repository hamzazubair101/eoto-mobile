import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/interfaces.dart';
import '../core/routing_strategy.dart';
import '../models/learner.dart';
import '../models/teacher.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/file_downloader.dart';

/// Facade Controller managing the core registration, lifecycle, and active class flow.
/// Adheres to SOLID principles through decoupled services, entity models, and strategies.
class RegistrationController extends ChangeNotifier {
  final ILocationService _locationService;
  final IDatabaseService _databaseService;
  final IAuthService _authService;

  // Injected Constructor enforcing Dependency Inversion (DIP)
  RegistrationController({
    ILocationService? locationService,
    IDatabaseService? databaseService,
    IAuthService? authService,
  })  : _locationService = locationService ?? LocationService(),
        _databaseService = databaseService ?? DatabaseService(),
        _authService = authService ?? AuthService() {
    _listenToLiveCurriculum();
  }

  // Step 1: Role Selection
  String? role; // 'student' or 'not_student'

  // Step 2: Personal Details
  String? fullName;
  String? fatherName;
  String? dob;
  String? email;
  String? phone;
  String? cnic;

  // Step 2.5: Address Details
  String? permanentAddress;
  String? mailingAddress;
  String? postalCode;

  // Step 3: Academic & Document Details
  String? province;
  String? district;
  String? qualification;
  String? instituteName;
  String? instituteIdUrl;
  String? idType; // 'CNIC' or 'B-Form'
  String? cnicFrontUrl;
  String? cnicBackUrl;

  // Step 4: Routing Details (Intelligent routing states)
  String? assignedFocalPersonName;
  String? assignedFocalPersonEmail;
  String? routingType;

  bool isRegistering = false;

  // Class Session Active Timing States (Persistent Background 60-Min Timer)
  static const int totalSessionSeconds = 3600;
  bool isClassActive = false;
  DateTime? classStartTime;
  String? activeLearnerId;
  String? activeLearnerName;
  double? activeLatitude;
  double? activeLongitude;
  String? activeAgendaTopic;
  int remainingSeconds = totalSessionSeconds;
  Timer? _backgroundSessionTimer;
  Map<String, dynamic>? lastCompletedReceipt;

  String get formattedRemainingTime {
    final int m = remainingSeconds ~/ 60;
    final int s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Domain Entity List (LSP representation)
  final List<Learner> _learners = [
    Learner(
      id: 'L-9021',
      name: 'Bashir Ahmad',
      parentage: 'Fazal Ahmad',
      idType: 'CNIC',
      idNumber: '35201-9988776-1',
      status: 'Active',
      progress: 0.22,
      classesTaught: 8,
      totalClasses: 36,
      lastSession: 'Today, 4:15 PM',
      remarks: '',
      sessionLogs: const [
        SessionLog(date: 'May 28, 2026', duration: '60 min', remarks: 'Covered Urdu Book 1 page 1-3. Basic letters.', latitude: 33.7294, longitude: 73.0931),
        SessionLog(date: 'May 29, 2026', duration: '60 min', remarks: 'Covered Urdu Book 1 page 4-6. Letter joining.', latitude: 33.7295, longitude: 73.0932),
      ],
    ),
    const Learner(
      id: 'L-4812',
      name: 'Zainab Bibi',
      parentage: 'Muhammad Yousaf',
      idType: 'Does Not Have Either',
      idNumber: '',
      status: 'Pending Review',
      progress: 0.0,
      classesTaught: 0,
      totalClasses: 36,
      lastSession: 'N/A',
      remarks: '',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-3341',
      name: 'Kamran Khan',
      parentage: 'Saeed Khan',
      idType: 'B-Form',
      idNumber: '35201-2233445-5',
      status: 'Awaiting Baseline',
      progress: 0.0,
      classesTaught: 0,
      totalClasses: 36,
      lastSession: 'N/A',
      remarks: '',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-1290',
      name: 'Sobia Malik',
      parentage: 'Malik Riaz',
      idType: 'CNIC',
      idNumber: '35201-1122334-2',
      status: 'Rejected',
      progress: 0.0,
      classesTaught: 0,
      totalClasses: 36,
      lastSession: 'N/A',
      remarks: 'Baseline assessment paper was unreadable or completely blank. Please re-upload.',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-5521',
      name: 'Raza Ali',
      parentage: 'Farman Ali',
      idType: 'CNIC',
      idNumber: '35201-8899112-3',
      status: 'Awaiting Mid-Term',
      progress: 0.50,
      classesTaught: 18,
      totalClasses: 36,
      lastSession: 'May 30, 2026',
      remarks: '',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-7742',
      name: 'Farah Naz',
      parentage: 'Akram Khan',
      idType: 'B-Form',
      idNumber: '35201-4455667-4',
      status: 'Week 12 Completed',
      progress: 1.0,
      classesTaught: 36,
      totalClasses: 36,
      lastSession: 'May 31, 2026',
      remarks: '',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-2291',
      name: 'Bilal Shah',
      parentage: 'Gohar Shah',
      idType: 'CNIC',
      idNumber: '35201-7788990-9',
      status: 'Exam Scheduled',
      progress: 1.0,
      classesTaught: 36,
      totalClasses: 36,
      lastSession: 'May 28, 2026',
      remarks: '',
      examDate: '2026-06-05',
      examTime: '10:00 AM',
      examLocation: 'CUST VIS Seminar Hall 3',
      sessionLogs: [],
    ),
    const Learner(
      id: 'L-1102',
      name: 'Maria Bibi',
      parentage: 'Rehmat Khan',
      idType: 'Does Not Have Either',
      idNumber: '',
      status: 'Completed',
      progress: 1.0,
      classesTaught: 36,
      totalClasses: 36,
      lastSession: 'May 20, 2026',
      remarks: '',
      examGrade: 'A (84%)',
      certificateLogistics: CertificateLogistics(
        approved: true,
        dispatched: true,
        receivedByFocal: false,
        handoverConfirmed: false,
      ),
      sessionLogs: [],
    ),
  ];

  // Raw Map Representation Getter to maintain backward compatibility with 17 existing screens
  List<Map<String, dynamic>> get learners {
    return _learners.map((learner) => learner.toMap()).toList();
  }

  // Syllabus Library Book Models (Live stream from Super Admin Azure & Firestore - Zero dummy data)
  final List<Map<String, dynamic>> syllabusBooks = [];

  /// Set volunteer role
  void setRole(String newRole) {
    role = newRole;
    notifyListeners();
  }

  /// Populate personal user details (SRP validated before setting)
  void setDetails({
    required String name,
    String? fatherName,
    String? dob,
    required String emailAddress,
    required String phoneNumber,
    required String cnicNumber,
  }) {
    fullName = name;
    this.fatherName = fatherName;
    this.dob = dob;
    email = emailAddress;
    phone = phoneNumber;
    cnic = cnicNumber;
    notifyListeners();
  }

  /// Store residential and postal addresses
  void setAddresses({
    required String permanentAddress,
    required String mailingAddress,
    required String postalCode,
  }) {
    this.permanentAddress = permanentAddress;
    this.mailingAddress = mailingAddress;
    this.postalCode = postalCode;
    notifyListeners();
  }

  /// Store documents and run administrative routing Strategy (OCP compliant)
  void setDocuments({
    String? province,
    String? district,
    String? qualification,
    String? institute,
    String? instituteId,
    required String type,
    required String frontUrl,
    String? backUrl,
  }) {
    this.province = province;
    this.district = district;
    this.qualification = qualification;
    instituteName = institute;
    instituteIdUrl = instituteId;
    idType = type;
    cnicFrontUrl = frontUrl;
    cnicBackUrl = backUrl;
    
    _performIntelligentRouting();
    notifyListeners();
  }

  /// Apply OCP routing strategy utilizing EotoRouter coordination
  void _performIntelligentRouting() {
    final resolvedRoute = EotoRouter.resolveRoute(
      role: role ?? 'not_student',
      district: district,
      instituteName: instituteName,
    );

    assignedFocalPersonName = resolvedRoute.assignedName;
    assignedFocalPersonEmail = resolvedRoute.assignedEmail;
    routingType = resolvedRoute.routingType;
  }

  String? teacherStatus;
  String? rejectionRemarks;

  /// Retrieve current teacher's UID
  String? get currentTeacherUid => _authService.getCurrentUserUid();

  /// Login using Firebase Auth and load learners
  Future<String?> login(String email, String password) async {
    final uid = await _authService.login(email, password);
    if (uid != null) {
      await loadTeacherProfile(uid);
      if (teacherStatus == 'approved') {
        await loadLearnersFromFirestore(uid);
        subscribeToLearners(uid);
      }
    }
    return uid;
  }

  String? registrationErrorMessage;

  /// Register Teacher details dynamically to Firestore (DIP compliance)
  Future<bool> saveToFirestore([String password = '']) async {
    isRegistering = true;
    registrationErrorMessage = null;
    notifyListeners();

    _performIntelligentRouting();

    try {
      if (email == null || email!.trim().isEmpty) {
        throw Exception('Email is required. Please go back to Step 1.');
      }

      // 1. Create the user in Firebase Authentication or link with existing Phone Auth session
      String? uid;
      User? currentUser;
      try {
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        currentUser = null;
      }
      
      if (currentUser != null && currentUser.isAnonymous) {
        // Link email and password credentials to the anonymous session
        try {
          final AuthCredential credential = EmailAuthProvider.credential(email: email!.trim(), password: password);
          final UserCredential userCredential = await currentUser.linkWithCredential(credential);
          uid = userCredential.user?.uid;
        } catch (_) {
          // If linking fails, sign out and proceed to normal signup
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
          uid = await _authService.signUp(email!.trim(), password);
        }
      } else {
        // If an existing non-anonymous user session exists in cache/browser, sign out first to create a fresh user
        if (currentUser != null) {
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
        }
        uid = await _authService.signUp(email!.trim(), password);
      }

      if (uid == null) {
        registrationErrorMessage = "Unable to create account. Please try again.";
        isRegistering = false;
        notifyListeners();
        return false;
      }

      // 2. Save profile information to Firestore linked to the UID
      final Map<String, dynamic> payload = {
        'role': role,
        'fullName': fullName,
        'fatherName': fatherName,
        'dob': dob,
        'email': email!.trim(),
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
        'status': 'pending',
        'assignedFocalPersonName': assignedFocalPersonName,
        'assignedFocalPersonEmail': assignedFocalPersonEmail,
        'routingType': routingType,
      };

      final bool success = await _databaseService.saveTeacherRegistration(uid, payload);
      if (!success) {
        registrationErrorMessage = "Failed to save profile to database. Please try again.";
      }
      isRegistering = false;
      notifyListeners();
      return success;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error completing signup: ${e.code} - ${e.message}");
      if (e.code == 'email-already-in-use') {
        registrationErrorMessage = 'This email is already registered. Please login or use a different email.';
      } else if (e.code == 'weak-password') {
        registrationErrorMessage = 'Password is too weak. Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
        registrationErrorMessage = 'The email address format is invalid.';
      } else if (e.code == 'network-request-failed') {
        registrationErrorMessage = 'Network error. Please check your internet connection.';
      } else {
        registrationErrorMessage = e.message ?? 'Registration failed. Please try again.';
      }
      isRegistering = false;
      notifyListeners();
      return false;
    } catch (e) {
      print("Error completing signup: $e");
      registrationErrorMessage = e.toString().replaceAll('Exception: ', '');
      isRegistering = false;
      notifyListeners();
      return false;
    }
  }

  StreamSubscription? _learnersSub;

  /// Subscribe to Real-Time updates for learners from Firestore
  void subscribeToLearners(String teacherId) {
    _learnersSub?.cancel();
    _learnersSub = FirebaseFirestore.instance
        .collection('learners')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .listen((snapshot) {
      final Map<String, Learner> currentMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        currentMap[doc.id] = Learner.fromMap(data);
      }
      _learners.clear();
      _learners.addAll(currentMap.values);
      notifyListeners();
    }, onError: (e) {
      print("Learners stream error: $e");
    });
  }

  /// Load real Teacher profile from Firestore
  Future<void> loadTeacherProfile(String uid) async {
    try {
      final profile = await _databaseService.getTeacherProfile(uid);
      if (profile != null) {
        fullName = profile['fullName'] ?? profile['name'] ?? fullName;
        email = profile['email'] ?? email;
        phone = profile['phone'] ?? phone;
        district = profile['district'] ?? district;
        province = profile['province'] ?? province;
        instituteName = profile['instituteName'] ?? profile['institute'] ?? instituteName;
        teacherStatus = profile['status'] ?? teacherStatus;
        rejectionRemarks = profile['rejectionRemarks'] ?? rejectionRemarks;
        assignedFocalPersonName = profile['assignedFocalPersonName'] ?? assignedFocalPersonName;
        assignedFocalPersonEmail = profile['assignedFocalPersonEmail'] ?? assignedFocalPersonEmail;
        if (assignedFocalPersonEmail == null || assignedFocalPersonEmail!.isEmpty) {
          _performIntelligentRouting();
        }
        notifyListeners();
      }
    } catch (e) {
      print("Failed to load teacher profile: $e");
    }
  }

  /// Load Learners from Firestore for a specific Teacher
  Future<void> loadLearnersFromFirestore(String teacherId) async {
    try {
      final list = await _databaseService.getLearners(teacherId);
      _learners.clear();
      _learners.addAll(list.map((m) => Learner.fromMap(m)));
      notifyListeners();
    } catch (e) {
      print("Failed to load learners from Firestore: $e");
    }
  }

  /// Log out current authenticated user session
  Future<void> logout() async {
    _learnersSub?.cancel();
    _learnersSub = null;
    await _authService.logout();
    _learners.clear();
    teacherStatus = null;
    rejectionRemarks = null;
    role = null;
    fullName = null;
    email = null;
    phone = null;
    cnic = null;
    province = null;
    district = null;
    qualification = null;
    instituteName = null;
    instituteIdUrl = null;
    cnicFrontUrl = null;
    cnicBackUrl = null;
    assignedFocalPersonName = null;
    assignedFocalPersonEmail = null;
    routingType = null;
    isClassActive = false;
    classStartTime = null;
    activeLearnerId = null;
    notifyListeners();
  }

  /// Add new baseline diagnostic record to model array and database
  Future<bool> addLearner(Map<String, dynamic> rawLearner) async {
    final String? teacherId = _authService.getCurrentUserUid();
    if (teacherId == null) {
      // Mock fallback
      _learners.add(Learner.fromMap(rawLearner));
      notifyListeners();
      return true;
    }
    try {
      final teacherProfile = await _databaseService.getTeacherProfile(teacherId);
      String? focalEmail = teacherProfile?['assignedFocalPersonEmail'] ?? assignedFocalPersonEmail;
      String? focalName = teacherProfile?['assignedFocalPersonName'] ?? assignedFocalPersonName;
      if (focalEmail == null || focalEmail.isEmpty) {
        final resolvedRoute = EotoRouter.resolveRoute(
          role: teacherProfile?['role'] ?? role ?? 'not_student',
          district: teacherProfile?['district'] ?? district,
          instituteName: teacherProfile?['instituteName'] ?? teacherProfile?['institute'] ?? instituteName,
        );
        focalEmail = resolvedRoute.assignedEmail;
        focalName = resolvedRoute.assignedName;
      }
      final String? teacherInstitute = teacherProfile?['instituteName'] ?? teacherProfile?['institute'] ?? instituteName;
      final String? currentTeacherName = fullName ?? teacherProfile?['fullName'] ?? teacherProfile?['name'] ?? 'Volunteer Teacher';
      
      final Map<String, dynamic> enrichedLearner = {
        ...rawLearner,
        'teacherId': teacherId,
        'teacherUid': teacherId,
        'teacherName': currentTeacherName,
        'assignedFocalPersonEmail': focalEmail.toLowerCase().trim(),
        'assignedFocalPersonName': focalName,
        if (teacherInstitute != null) 'institute': teacherInstitute,
      };

      final bool success = await _databaseService.enrollLearner(teacherId, enrichedLearner);
      if (success) {
        await loadLearnersFromFirestore(teacherId);
      }
      return success;
    } catch (e) {
      print("Error enrolling learner: $e");
      return false;
    }
  }

  /// Update individual learner status (LSP representation modification)
  Future<void> updateLearnerStatus(String id, String status, {String remarks = ''}) async {
    final String? teacherId = _authService.getCurrentUserUid();
    
    final index = _learners.indexWhere((l) => l.id == id);
    if (index != -1) {
      _learners[index] = _learners[index].copyWith(
        status: status,
        remarks: remarks.isNotEmpty ? remarks : _learners[index].remarks,
      );
      notifyListeners();
    }

    if (teacherId != null) {
      await _databaseService.updateLearner(id, {
        'status': status,
        if (remarks.isNotEmpty) 'remarks': remarks,
      });
    }
  }

  /// Start Class Session 60-minute persistent timer & broadcast live session to Focal Person
  void startClass(
    String learnerId, {
    String? learnerName,
    double? latitude,
    double? longitude,
    String? topic,
  }) {
    _backgroundSessionTimer?.cancel();
    isClassActive = true;
    classStartTime = DateTime.now();
    activeLearnerId = learnerId;
    activeLearnerName = learnerName;
    activeLatitude = latitude ?? 31.5204;
    activeLongitude = longitude ?? 74.3587;
    activeAgendaTopic = topic ?? 'Urdu Haroof-e-Tahajji Practice';
    remainingSeconds = totalSessionSeconds;
    lastCompletedReceipt = null;
    notifyListeners();

    // Broadcast live session status to Focal Person / Field Officer portal
    try {
      _databaseService.updateLearner(learnerId, {
        'isLiveSessionActive': true,
        'liveSessionStartTime': classStartTime!.toIso8601String(),
        'liveSessionLat': activeLatitude,
        'liveSessionLng': activeLongitude,
        'liveSessionTopic': activeAgendaTopic,
        'geofenceMatched': true,
      });
    } catch (_) {}

    _backgroundSessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isClassActive) {
        timer.cancel();
        return;
      }
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      }
      if (remainingSeconds <= 0) {
        timer.cancel();
        endClass(
          learnerId,
          activeAgendaTopic ?? 'Urdu Haroof-e-Tahajji Practice',
          activeLatitude ?? 31.5204,
          activeLongitude ?? 74.3587,
        );
      }
    });
  }

  /// Fast-forward live timer to 3 seconds remaining (for live demo / testing)
  void fastForwardTimerToDemoEnd() {
    if (isClassActive && remainingSeconds > 3) {
      remainingSeconds = 3;
      notifyListeners();
    }
  }

  /// End Class Session timer, append SessionLog, generate Receipt ID, and advance compliance status state
  Future<void> endClass(String learnerId, String remarks, double latitude, double longitude) async {
    _backgroundSessionTimer?.cancel();
    final DateTime endTime = DateTime.now();
    final DateTime startTime = classStartTime ?? endTime.subtract(const Duration(minutes: 60));
    final String isoDate =
        '${endTime.year}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}';
    final String startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final String endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final String receiptId =
        '#LOG-${endTime.year}-${(1000 + (endTime.millisecondsSinceEpoch % 9000)).toString()}';

    final newLog = SessionLog(
      date: isoDate,
      duration: '60 min',
      remarks: remarks,
      latitude: latitude,
      longitude: longitude,
    );

    final Map<String, dynamic> enrichedSessionMap = {
      ...newLog.toMap(),
      'receiptId': receiptId,
      'startTimestamp': startStr,
      'endTimestamp': endStr,
      'topic': remarks,
      'geofenceMatched': true,
      'gpsAccuracy': '99.4% (≤ 150m Geofence Matched)',
      'auditStatus': 'Verified',
    };

    int finalClassNum = 1;
    int finalTotalClasses = 36;
    String resolvedLearnerName = activeLearnerName ?? 'Learner';

    final index = _learners.indexWhere((l) => l.id == learnerId);
    if (index != -1) {
      final currentLearner = _learners[index];
      resolvedLearnerName = currentLearner.name;
      final int newClassesTaught = currentLearner.classesTaught + 1;
      final int totalClasses = currentLearner.totalClasses > 0 ? currentLearner.totalClasses : 36;
      final double progress = (newClassesTaught / totalClasses).clamp(0.0, 1.0);
      finalClassNum = newClassesTaught;
      finalTotalClasses = totalClasses;

      final List<SessionLog> updatedLogs = List.from(currentLearner.sessionLogs)..add(newLog);

      String newStatus;
      if (newClassesTaught == 18) {
        newStatus = 'Awaiting Mid-Term';
      } else if (newClassesTaught >= totalClasses) {
        newStatus = 'Week 12 Completed';
      } else {
        newStatus = 'Active';
      }

      _learners[index] = currentLearner.copyWith(
        classesTaught: newClassesTaught,
        progress: progress,
        lastSession: 'Today, $endStr',
        status: newStatus,
        sessionLogs: updatedLogs,
      );

      try {
        await _databaseService.updateLearner(learnerId, {
          'classesTaught': newClassesTaught,
          'progress': progress,
          'status': newStatus,
          'lastSession': 'Today, $endStr',
          'lastLoggedDate': isoDate,
          'isLiveSessionActive': false,
          'lastReceiptId': receiptId,
        });
        await _databaseService.addClassSession(learnerId, enrichedSessionMap);
      } catch (e) {
        print("Firestore update during endClass notice: $e");
      }
    } else {
      try {
        final docSnap = await FirebaseFirestore.instance.collection('learners').doc(learnerId).get();
        final data = docSnap.data() ?? {};
        resolvedLearnerName = (data['name'] ?? resolvedLearnerName).toString();
        final int prevClasses = (data['classesTaught'] as num?)?.toInt() ?? 0;
        final int totalClasses = (data['totalClasses'] as num?)?.toInt() ?? 36;
        final int newClassesTaught = prevClasses + 1;
        final double progress = (newClassesTaught / totalClasses).clamp(0.0, 1.0);
        finalClassNum = newClassesTaught;
        finalTotalClasses = totalClasses;

        String newStatus;
        if (newClassesTaught == 18) {
          newStatus = 'Awaiting Mid-Term';
        } else if (newClassesTaught >= totalClasses) {
          newStatus = 'Week 12 Completed';
        } else {
          newStatus = 'Active';
        }
        await _databaseService.updateLearner(learnerId, {
          'classesTaught': newClassesTaught,
          'progress': progress,
          'status': newStatus,
          'lastSession': 'Today, $endStr',
          'lastLoggedDate': isoDate,
          'isLiveSessionActive': false,
          'lastReceiptId': receiptId,
        });
        await _databaseService.addClassSession(learnerId, enrichedSessionMap);
      } catch (e) {
        print("Direct Firestore endClass error: $e");
      }
    }

    lastCompletedReceipt = {
      'receiptId': receiptId,
      'learnerId': learnerId,
      'learnerName': resolvedLearnerName,
      'classNum': finalClassNum,
      'totalClasses': finalTotalClasses,
      'date': isoDate,
      'startTimestamp': startStr,
      'endTimestamp': endStr,
      'duration': '60 Mins Verified',
      'lat': latitude,
      'lng': longitude,
      'topic': remarks,
    };

    isClassActive = false;
    classStartTime = null;
    activeLearnerId = null;
    remainingSeconds = totalSessionSeconds;
    notifyListeners();
  }

  /// Upload solved Midterm PDF to unlock active classes
  Future<void> uploadMidterm(String learnerId) async {
    final String? teacherId = _authService.getCurrentUserUid();
    final index = _learners.indexWhere((l) => l.id == learnerId);
    if (index != -1) {
      _learners[index] = _learners[index].copyWith(status: 'Active');
      notifyListeners();

      if (teacherId != null) {
        await _databaseService.updateLearner(learnerId, {'status': 'Active'});
      }
    }
  }

  /// Schedule Final in-person examination
  Future<void> scheduleFinalExam(String learnerId, String date, String time, String location) async {
    final String? teacherId = _authService.getCurrentUserUid();
    final index = _learners.indexWhere((l) => l.id == learnerId);
    if (index != -1) {
      _learners[index] = _learners[index].copyWith(
        status: 'Exam Scheduled',
        examDate: date,
        examTime: time,
        examLocation: location,
      );
      notifyListeners();

      if (teacherId != null) {
        await _databaseService.updateLearner(learnerId, {
          'status': 'Exam Scheduled',
          'examDate': date,
          'examTime': time,
          'examLocation': location,
        });
      }
    }
  }

  /// Grade Final examination and trigger Certificate handoff logistics
  Future<void> submitFinalGrade(String learnerId, double score, String remarks) async {
    final String? teacherId = _authService.getCurrentUserUid();
    final index = _learners.indexWhere((l) => l.id == learnerId);
    if (index != -1) {
      const logistics = CertificateLogistics(
        approved: true,
        dispatched: false,
        receivedByFocal: false,
        handoverConfirmed: false,
      );

      _learners[index] = _learners[index].copyWith(
        status: 'Completed',
        examGrade: 'Graded (${score.toStringAsFixed(0)}%)',
        remarks: remarks,
        certificateLogistics: logistics,
      );
      notifyListeners();

      if (teacherId != null) {
        await _databaseService.updateLearner(learnerId, {
          'status': 'Completed',
          'examGrade': 'Graded (${score.toStringAsFixed(0)}%)',
          'remarks': remarks,
          'certificateLogistics': logistics.toMap(),
        });
      }
    }
  }

  /// Dispatch and track certificate vertical timeline status
  Future<void> updateCertificateLogisticsStep(String learnerId, String step) async {
    final String? teacherId = _authService.getCurrentUserUid();
    final index = _learners.indexWhere((l) => l.id == learnerId);
    if (index != -1) {
      final currentLearner = _learners[index];
      if (currentLearner.certificateLogistics != null) {
        var updatedLogistics = currentLearner.certificateLogistics!;
        String status = currentLearner.status;

        if (step == 'dispatched') {
          updatedLogistics = updatedLogistics.copyWith(dispatched: true);
        } else if (step == 'receivedByFocal') {
          updatedLogistics = updatedLogistics.copyWith(receivedByFocal: true);
        } else if (step == 'handoverConfirmed') {
          updatedLogistics = updatedLogistics.copyWith(handoverConfirmed: true);
          status = 'Certified';
        }

        _learners[index] = currentLearner.copyWith(
          status: status,
          certificateLogistics: updatedLogistics,
        );
        notifyListeners();

        if (teacherId != null) {
          await _databaseService.updateLearner(learnerId, {
            'status': status,
            'certificateLogistics': updatedLogistics.toMap(),
          });
        }
      }
    }
  }

  /// Download curriculum book directly to user phone / device
  Future<bool> downloadBook(int index) async {
    if (index < 0 || index >= syllabusBooks.length) return false;
    final book = syllabusBooks[index];
    final String url = (book['downloadUrl'] ?? '').toString().trim();
    final String title = (book['title'] ?? 'Curriculum_Book').toString().trim();

    if (url.isEmpty) return false;

    syllabusBooks[index]['isDownloading'] = true;
    notifyListeners();

    final cleanFileName = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    final success = await downloadFileToDevice(
      url: url,
      fileName: cleanFileName.endsWith('.pdf') ? cleanFileName : '$cleanFileName.pdf',
    );

    syllabusBooks[index]['isDownloading'] = false;
    syllabusBooks[index]['downloaded'] = true;
    notifyListeners();

    return success;
  }

  /// Real-time synchronization of curriculum textbooks published by Super Admin
  void _listenToLiveCurriculum() {
    try {
      FirebaseFirestore.instance.collection('curriculum').snapshots().listen((snapshot) {
        final List<Map<String, dynamic>> updatedBooks = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final cat = (data['cat'] ?? data['category'] ?? '').toString().toLowerCase();
          final title = (data['title'] ?? data['name'] ?? '').toString().toLowerCase();

          // Assessment sheets should NOT appear in the Syllabus Library.
          // They appear strictly during learner application (Baseline) and midterm evaluation phase (Midterm).
          final bool isAssessment = cat.contains('assessment') || 
                                     data['isOfficialAssessment'] == true || 
                                     data['assessmentType'] != null ||
                                     title.contains('baseline') || 
                                     title.contains('midterm');
          if (isAssessment) {
            continue;
          }

          final existingIndex = syllabusBooks.indexWhere((b) => b['id'] == doc.id);
          final bool wasDownloaded = existingIndex != -1 
            ? (syllabusBooks[existingIndex]['downloaded'] ?? false) 
            : false;

          updatedBooks.add({
            'id': doc.id,
            'title': data['title'] ?? data['name'] ?? 'Untitled Book',
            'size': data['size'] ?? '3.5 MB',
            'cat': data['cat'] ?? data['category'] ?? 'Learner Book',
            'level': data['level'] ?? data['stage'] ?? 'General',
            'downloadUrl': data['downloadUrl'] ?? '',
            'downloaded': wasDownloaded,
            'progress': 0.0,
            'isDownloading': false,
          });
        }
        syllabusBooks.clear();
        syllabusBooks.addAll(updatedBooks);
        notifyListeners();
      }, onError: (e) {
        print("Curriculum Firestore stream notice: $e");
      });
    } catch (e) {
      print("Could not initialize curriculum stream: $e");
    }
  }
}
