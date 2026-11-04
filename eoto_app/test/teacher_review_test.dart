import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eoto_app/screens/focal/teacher_review_detail_screen.dart';

void main() {
  testWidgets('TeacherReviewDetailScreen renders all original and accurate data for focal officer review', (WidgetTester tester) async {
    final teacherData = {
      'id': 'T-987654321',
      'fullName': 'Fatima Noor',
      'fatherName': 'Muhammad Noor',
      'role': 'student',
      'cnic': '35201-1234567-8',
      'idType': 'CNIC',
      'dob': '14/08/2002',
      'phone': '03001234567',
      'email': 'fatima.noor@cust.pk',
      'permanentAddress': 'House 45, Street 12, Sector F-8/1, Islamabad',
      'mailingAddress': 'Hostel 3, CUST Campus, Sihala, Islamabad',
      'postalCode': '44000',
      'instituteName': 'Capital University of Science and Technology (CUST)',
      'qualification': 'Bachelors / Undergraduate',
      'district': 'Islamabad',
      'province': 'ICT',
      'routingType': 'Institutional (Registered)',
      'assignedFocalPersonName': 'Dr. Daud Arshad',
      'assignedFocalPersonEmail': 'cust_focal@eoto.pk',
      'cnicFrontUrl': 'https://eotostorage.blob.core.windows.net/eotocontainer/registration_docs/cnic_front_test.jpg',
      'cnicBackUrl': 'https://eotostorage.blob.core.windows.net/eotocontainer/registration_docs/cnic_back_test.jpg',
      'instituteIdUrl': 'https://eotostorage.blob.core.windows.net/eotocontainer/registration_docs/academic_proof_test.jpg',
      'createdAt': Timestamp.now(),
      'status': 'pending',
    };

    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TeacherReviewDetailScreen(applicant: teacherData),
      ),
    );

    // Header
    expect(find.text('Volunteer Profile Review'), findsOneWidget);

    // Personal details
    expect(find.text('Fatima Noor'), findsOneWidget);
    expect(find.text('Muhammad Noor'), findsOneWidget);
    expect(find.text('35201-1234567-8'), findsOneWidget);
    expect(find.text('14/08/2002'), findsOneWidget);
    expect(find.text('03001234567'), findsOneWidget);
    expect(find.text('fatima.noor@cust.pk'), findsOneWidget);

    // Address logistics
    expect(find.text('House 45, Street 12, Sector F-8/1, Islamabad'), findsOneWidget);
    expect(find.text('Hostel 3, CUST Campus, Sihala, Islamabad'), findsOneWidget);
    expect(find.text('44000'), findsOneWidget);

    // Academic & Allocation
    expect(find.text('University Student Volunteer (VIS)'), findsOneWidget);
    expect(find.text('Capital University of Science and Technology (CUST)'), findsOneWidget);

    // Documents
    expect(find.text('CNIC FRONT PHOTO'), findsOneWidget);
    expect(find.text('CNIC BACK PHOTO'), findsOneWidget);
    expect(find.text('STUDENT ID CARD / ENROLLMENT PROOF'), findsOneWidget);

    // Decision Actions
    expect(find.text('REJECT PROFILE'), findsOneWidget);
    expect(find.text('APPROVE PROFILE'), findsOneWidget);
  });
}
