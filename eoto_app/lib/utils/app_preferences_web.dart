import 'dart:html' as html;

class AppPreferences {
  static bool get hasSeenOnboarding {
    try {
      return html.window.localStorage['eoto_has_seen_onboarding'] == 'true';
    } catch (_) {
      return false;
    }
  }

  static void setHasSeenOnboarding(bool value) {
    try {
      html.window.localStorage['eoto_has_seen_onboarding'] = value.toString();
    } catch (_) {}
  }
}
