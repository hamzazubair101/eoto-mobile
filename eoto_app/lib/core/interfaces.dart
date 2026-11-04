/// Core abstract interfaces establishing Dependency Inversion (DIP) boundaries.
/// High-level modules depend on these contracts rather than concrete plugins.

abstract class ILocationService {
  /// Check and request location permissions on the device.
  /// Returns [true] if permission is granted, [false] otherwise.
  Future<bool> checkAndRequestPermissions();

  /// Retrieve the current GPS coordinates of the device.
  /// Returns a map with 'latitude' and 'longitude' keys.
  Future<Map<String, double>> getCurrentLocation();
}

abstract class IAuthService {
  /// Sign in a user with email and password.
  Future<String?> login(String email, String password);

  /// Sign up a new user with email and password.
  Future<String?> signUp(String email, String password);

  /// Sign out the current user.
  Future<void> logout();

  /// Retrieve the current authenticated user's ID.
  String? getCurrentUserUid();
}

abstract class IDatabaseService {
  /// Save a teacher's registration data to the backend datastore.
  /// Returns [true] if successful, [false] if fail.
  Future<bool> saveTeacherRegistration(String uid, Map<String, dynamic> teacherData);

  /// Fetch the list of learners for a specific teacher.
  Future<List<Map<String, dynamic>>> getLearners(String teacherId);

  /// Enroll a new learner.
  Future<bool> enrollLearner(String teacherId, Map<String, dynamic> learnerData);

  /// Update an existing learner's fields (like status, exam grades, etc.).
  Future<bool> updateLearner(String learnerId, Map<String, dynamic> updates);

  /// Add a class session log for a learner.
  Future<bool> addClassSession(String learnerId, Map<String, dynamic> sessionLog);

  /// Fetch a teacher's profile details by UID.
  Future<Map<String, dynamic>?> getTeacherProfile(String uid);
}

