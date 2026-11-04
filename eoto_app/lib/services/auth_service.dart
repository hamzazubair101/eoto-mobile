import 'package:firebase_auth/firebase_auth.dart';
import '../core/interfaces.dart';

class AuthService implements IAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<String?> login(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user?.uid;
    } catch (e) {
      print("Firebase Auth Login Error: $e");
      rethrow;
    }
  }

  @override
  Future<String?> signUp(String email, String password) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user?.uid;
    } catch (e) {
      print("Firebase Auth SignUp Error: $e");
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }
}
