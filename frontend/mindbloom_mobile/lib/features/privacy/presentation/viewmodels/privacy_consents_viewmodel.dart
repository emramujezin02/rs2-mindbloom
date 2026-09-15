import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/privacy_current_versions_model.dart';
import '../../data/models/user_consent_model.dart';
import '../../data/repositories/privacy_repository.dart';

class PrivacyConsentsViewModel extends ChangeNotifier {
  final PrivacyRepository repository;

  PrivacyConsentsViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<UserConsentModel> consents = [];

  PrivacyCurrentVersionsModel? currentVersions;

  Future<void> load() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        repository.getMyConsents(),
        repository.getCurrentVersions(),
      ]);

      consents = results[0] as List<UserConsentModel>;

      currentVersions = results[1] as PrivacyCurrentVersionsModel;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  UserConsentModel? latestConsent(String consentType) {
    final matching =
        consents.where((item) => item.consentType == consentType).toList()
          ..sort((a, b) => b.acceptedAtUtc.compareTo(a.acceptedAtUtc));

    return matching.isEmpty ? null : matching.first;
  }

  bool isCurrent(UserConsentModel consent) {
    final current =
        currentVersions?.versionFor(consent.consentType).trim() ?? '';

    return current.isNotEmpty && consent.documentVersion.trim() == current;
  }
}
