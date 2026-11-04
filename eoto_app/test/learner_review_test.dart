import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eoto_app/screens/focal/learner_review_detail_screen.dart';

void main() {
  testWidgets('LearnerReviewDetailScreen renders all details without error', (WidgetTester tester) async {
    final learnerData = {
      'id': 'test_learner_123',
      'name': 'zaman',
      'role': 'Learner Partner',
      'district': 'Lahore',
      'createdAt': Timestamp.now(),
      'type': 'learner',
    };

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LearnerReviewDetailScreen(learner: learnerData),
      ),
    );

    // Verify presence of title
    expect(find.text('Review Learner'), findsOneWidget);

    // Verify presence of Learner Profile section
    expect(find.text('Learner Profile'), findsOneWidget);
    debugPrint('RECT OF LEARNER PROFILE: ${tester.getRect(find.text("Learner Profile"))}');
    debugPrint('RECT OF BODY: ${tester.getRect(find.byType(SingleChildScrollView))}');
    debugPrint('RECT OF REJECT BUTTON: ${tester.getRect(find.text("R E J E C T"))}');

    // Verify presence of learner name
    expect(find.text('zaman'), findsOneWidget);

    // Verify presence of Baseline Assessment section
    expect(find.text('Baseline Assessment'), findsOneWidget);

    // Verify action buttons
    expect(find.text('R E J E C T'), findsOneWidget);
    expect(find.text('A P P R O V E'), findsOneWidget);
  });
}
