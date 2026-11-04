import 'package:flutter_test/flutter_test.dart';
import 'package:eoto_app/core/interfaces.dart';
import 'package:eoto_app/core/validators.dart';
import 'package:eoto_app/core/routing_strategy.dart';
import 'package:eoto_app/models/learner.dart';
import 'package:eoto_app/controllers/registration_controller.dart';

// Mock implementation of ILocationService for unit testing DIP structures
class MockLocationService implements ILocationService {
  bool checkPermissionReturnValue = true;
  Map<String, double> currentLocationReturnValue = {
    'latitude': 34.0151,
    'longitude': 71.5249,
  };

  @override
  Future<bool> checkAndRequestPermissions() async {
    return checkPermissionReturnValue;
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    return currentLocationReturnValue;
  }
}

class MockAuthService implements IAuthService {
  @override
  Future<String?> login(String email, String password) async => 'mock-uid-123';

  @override
  Future<String?> signUp(String email, String password) async => 'mock-uid-123';

  @override
  Future<void> logout() async {}

  @override
  String? getCurrentUserUid() => 'mock-uid-123';
}

// Mock implementation of IDatabaseService for unit testing DIP structures
class MockDatabaseService implements IDatabaseService {
  bool saveTeacherRegistrationReturnValue = true;
  Map<String, dynamic>? lastSavedTeacherData;

  @override
  Future<bool> saveTeacherRegistration(String uid, Map<String, dynamic> teacherData) async {
    lastSavedTeacherData = teacherData;
    return saveTeacherRegistrationReturnValue;
  }

  @override
  Future<List<Map<String, dynamic>>> getLearners(String teacherId) async => [];

  @override
  Future<bool> enrollLearner(String teacherId, Map<String, dynamic> learnerData) async => true;

  @override
  Future<bool> updateLearner(String learnerId, Map<String, dynamic> updates) async => true;

  @override
  Future<bool> addClassSession(String learnerId, Map<String, dynamic> sessionLog) async => true;

  @override
  Future<Map<String, dynamic>?> getTeacherProfile(String uid) async => null;
}

void main() {
  group('SOLID Core Validators (SRP)', () {
    test('validateName rejects blank or invalid format names', () {
      expect(EotoValidators.validateName('', 'Name'), 'Name is required');
      expect(EotoValidators.validateName('   ', 'Name'), 'Name is required');
      expect(EotoValidators.validateName('Ali123', 'Name'), 'Name must contain letters and spaces only');
      expect(EotoValidators.validateName('Ali Khan', 'Name'), isNull);
    });

    test('validateCNIC verifies raw 13-digit Pakistani CNIC limits', () {
      expect(EotoValidators.validateCNIC(''), 'CNIC/B-Form is required');
      expect(EotoValidators.validateCNIC('352011234'), 'Must be exactly 13 digits');
      expect(EotoValidators.validateCNIC('352011234567a'), 'Must contain digits only');
      expect(EotoValidators.validateCNIC('3520112345678'), isNull);
    });

    test('validatePhone verifies Pakistani phone formatting norms', () {
      expect(EotoValidators.validatePhone(''), 'Phone number is required');
      expect(EotoValidators.validatePhone('030012345'), 'Must be 11 digits starting with 03');
      expect(EotoValidators.validatePhone('04231112222'), 'Must be 11 digits starting with 03');
      expect(EotoValidators.validatePhone('03001234567'), isNull);
    });

    test('validateEmail checks standard syntax rules', () {
      expect(EotoValidators.validateEmail(''), 'Email is required');
      expect(EotoValidators.validateEmail('notanemail'), 'Enter a valid email address');
      expect(EotoValidators.validateEmail('test@eoto.pk'), isNull);
    });
  });

  group('SOLID Routing Strategies (OCP)', () {
    test('CUST university student routing assignments', () {
      final resolved = EotoRouter.resolveRoute(
        role: 'student',
        instituteName: 'Capital University of Science and Technology (CUST), Islamabad',
      );
      expect(resolved.routingType, 'Institutional (Registered)');
      expect(resolved.assignedName, 'Dr. Daud Arshad (CUST VIS Lead)');
      expect(resolved.assignedEmail, 'cust_focal@eoto.pk');
    });

    test('Generic registered university student routing assignments', () {
      final resolved = EotoRouter.resolveRoute(
        role: 'student',
        instituteName: 'NUST University, Islamabad',
      );
      expect(resolved.routingType, 'Institutional (Registered)');
      expect(resolved.assignedName, contains('NUST'));
      expect(resolved.assignedEmail, contains('nust'));
    });

    test('Community / General Volunteer routing assignments in ICT', () {
      final resolved = EotoRouter.resolveRoute(
        role: 'not_student',
        district: 'Islamabad (ICT)',
      );
      expect(resolved.routingType, 'District Officer (Unregistered/Community)');
      expect(resolved.assignedName, 'Mr. Danish Abbas (NCHD Islamabad District Officer)');
      expect(resolved.assignedEmail, 'islamabad_officer@eoto.pk');
    });

    test('Community / General Volunteer routing assignments in outer districts', () {
      final resolved = EotoRouter.resolveRoute(
        role: 'not_student',
        district: 'Rawalpindi',
      );
      expect(resolved.routingType, 'District Officer (Unregistered/Community)');
      expect(resolved.assignedName, contains('Rawalpindi'));
      expect(resolved.assignedEmail, contains('rawalpindi'));
    });
  });

  group('SOLID Dependency Inversion Service Integration (DIP)', () {
    late MockLocationService mockLocation;
    late MockDatabaseService mockDatabase;
    late MockAuthService mockAuth;
    late RegistrationController controller;

    setUp(() {
      mockLocation = MockLocationService();
      mockDatabase = MockDatabaseService();
      mockAuth = MockAuthService();
      controller = RegistrationController(
        locationService: mockLocation,
        databaseService: mockDatabase,
        authService: mockAuth,
      );
    });

    test('saveToFirestore calls abstract IDatabaseService and submits correct payload', () async {
      controller.setRole('student');
      controller.setDetails(
        name: 'John Doe',
        emailAddress: 'john@eoto.pk',
        phoneNumber: '03001234567',
        cnicNumber: '3520112345678',
      );
      controller.setDocuments(
        district: 'Islamabad (ICT)',
        qualification: 'Bachelors',
        institute: 'Capital University of Science and Technology (CUST), Islamabad',
        type: 'CNIC',
        frontUrl: 'front_doc.png',
      );

      final success = await controller.saveToFirestore();
      expect(success, isTrue);
      expect(mockDatabase.lastSavedTeacherData, isNotNull);
      expect(mockDatabase.lastSavedTeacherData!['fullName'], 'John Doe');
      expect(mockDatabase.lastSavedTeacherData!['assignedFocalPersonName'], 'Dr. Daud Arshad (CUST VIS Lead)');
    });

    test('endClass appends a type-safe session log to Learner correctly', () {
      // Learner 1 (Bashir Ahmad) has 8 classes initially
      expect(controller.learners[0]['classesTaught'], 8);
      expect(controller.learners[0]['sessionLogs'].length, 2);

      controller.startClass('L-9021');
      controller.endClass('L-9021', 'Covered Urdu Book 1 page 7-9.', 33.72, 73.09);

      expect(controller.learners[0]['classesTaught'], 9);
      expect(controller.learners[0]['sessionLogs'].length, 3);
      expect(controller.learners[0]['sessionLogs'][2]['remarks'], 'Covered Urdu Book 1 page 7-9.');
    });
  });
}
