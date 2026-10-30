import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinkLauncher {
  ExternalLinkLauncher._();

  static Future<void> open(
    BuildContext context,
    Uri? uri, {
    required String failureMessage,
  }) async {
    var opened = false;
    try {
      if (uri != null) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Unsupported schemes/platforms and platform exceptions use the same UI.
    }
    if (!context.mounted || opened) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
