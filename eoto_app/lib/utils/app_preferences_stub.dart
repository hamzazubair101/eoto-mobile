class AppPreferences {
  static bool _seen = false;

  static bool get hasSeenOnboarding => _seen;

  static void setHasSeenOnboarding(bool value) {
    _seen = value;
  }
}
