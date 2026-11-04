import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/interfaces.dart';

class DatabaseService implements IDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<bool> saveTeacherRegistration(String uid, Map<String, dynamic> teacherData) async {
    try {
      await _firestore.collection('teachers').doc(uid).set({
        ...teacherData,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Firestore saveTeacherRegistration Error: $e");
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLearners(String teacherId) async {
    try {
      final Map<String, Map<String, dynamic>> learnersMap = {};

      // 1. Query by teacherId
      final queryByTeacherId = await _firestore
          .collection('learners')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      for (var doc in queryByTeacherId.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        learnersMap[doc.id] = data;
      }

      // 2. Query by teacherUid (legacy or alt mapping)
      try {
        final queryByTeacherUid = await _firestore
            .collection('learners')
            .where('teacherUid', isEqualTo: teacherId)
            .get();

        for (var doc in queryByTeacherUid.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          learnersMap[doc.id] = data;
        }
      } catch (_) {}

      return learnersMap.values.toList();
    } catch (e) {
      print("Firestore getLearners Error: $e");
      rethrow;
    }
  }

  @override
  Future<bool> enrollLearner(String teacherId, Map<String, dynamic> learnerData) async {
    try {
      final docRef = _firestore.collection('learners').doc();
      await docRef.set({
        ...learnerData,
        'id': docRef.id,
        'teacherId': teacherId,
        'teacherUid': teacherId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Firestore enrollLearner Error: $e");
      rethrow;
    }
  }

  @override
  Future<bool> updateLearner(String learnerId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('learners').doc(learnerId).update(updates);
      return true;
    } catch (e) {
      print("Firestore updateLearner Error: $e");
      rethrow;
    }
  }

  @override
  Future<bool> addClassSession(String learnerId, Map<String, dynamic> sessionLog) async {
    try {
      await _firestore.collection('learners').doc(learnerId).update({
        'sessionLogs': FieldValue.arrayUnion([sessionLog]),
        'lastSession': sessionLog['date'] ?? 'Just Now',
      });
      return true;
    } catch (e) {
      print("Firestore addClassSession Error: $e");
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getTeacherProfile(String uid) async {
    try {
      final doc = await _firestore.collection('teachers').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print("Firestore getTeacherProfile Error: $e");
      return null;
    }
  }
}
