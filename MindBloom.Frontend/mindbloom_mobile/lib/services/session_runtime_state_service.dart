import 'package:shared_preferences/shared_preferences.dart';

class SessionRuntimeStateService {
  static const String _clientActiveTabKey =
      'mindbloom_client_active_navigation_tab';

  static const String _therapistActiveTabKey =
      'mindbloom_therapist_active_navigation_tab';

  Future<void> resetAuthenticatedUiState() async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait([
      preferences.remove(_clientActiveTabKey),
      preferences.remove(_therapistActiveTabKey),
    ]);
  }
}
