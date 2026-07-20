import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';

class TherapistProfileImage extends StatelessWidget {
  final String fullName;
  final String? profileImageUrl;
  final double radius;

  const TherapistProfileImage({
    super.key,
    required this.fullName,
    required this.profileImageUrl,
    this.radius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = _resolveImageUrl(profileImageUrl);

    if (resolvedImageUrl == null) {
      return _buildFallbackAvatar(context);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          resolvedImageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackContent(context);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Center(
                child: SizedBox(
                  width: radius * 0.7,
                  height: radius * 0.7,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: _buildFallbackContent(context),
    );
  }

  Widget _buildFallbackContent(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String get _initials {
    final nameParts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.isEmpty) {
      return '?';
    }

    if (nameParts.length == 1) {
      return nameParts.first[0].toUpperCase();
    }

    return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
  }

  String? _resolveImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    final normalizedPath = imagePath.trim();
    final imageUri = Uri.tryParse(normalizedPath);

    if (imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https')) {
      return normalizedPath;
    }

    final apiUri = Uri.tryParse(ApiConstants.apiBaseUrl);

    if (apiUri == null || apiUri.host.isEmpty) {
      return null;
    }

    final normalizedImagePath = normalizedPath.startsWith('/')
        ? normalizedPath
        : '/$normalizedPath';

    return apiUri
        .replace(path: normalizedImagePath, query: null, fragment: null)
        .toString();
  }
}
