import 'package:shared_preferences/shared_preferences.dart';

class LaunchService {
  static const _keyFirstLaunch = 'first_launch';

  /// Returns true if this is the first time the app is opened
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool(_keyFirstLaunch) ?? true;
    return isFirst;
  }

  /// Call this after onboarding completes
  static Future<void> markLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  /// For dev/testing — resets the flag so onboarding shows again
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFirstLaunch);
  }
}