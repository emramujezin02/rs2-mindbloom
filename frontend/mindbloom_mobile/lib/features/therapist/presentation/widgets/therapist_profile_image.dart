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
    this.radius = 42,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _buildFullImageUrl(profileImageUrl);

    return Semantics(
      image: true,
      label: '$fullName profile image',
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: imageUrl == null
              ? _buildInitialsFallback()
              : Image.network(
                  imageUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return _buildLoadingPlaceholder(loadingProgress);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildInitialsFallback();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ImageChunkEvent loadingProgress) {
    final expectedTotalBytes = loadingProgress.expectedTotalBytes;

    final progress = expectedTotalBytes == null
        ? null
        : loadingProgress.cumulativeBytesLoaded / expectedTotalBytes;

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: const Color(0xFFE4D8F3),
      child: SizedBox(
        width: radius * 0.65,
        height: radius * 0.65,
        child: CircularProgressIndicator(strokeWidth: 2.5, value: progress),
      ),
    );
  }

  Widget _buildInitialsFallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: const Color(0xFFE4D8F3),
      child: Text(
        _buildInitials(fullName),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF65468B),
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String? _buildFullImageUrl(String? imageUrl) {
    if (imageUrl == null) {
      return null;
    }

    final normalizedUrl = imageUrl.trim();

    if (normalizedUrl.isEmpty) {
      return null;
    }

    final parsedUrl = Uri.tryParse(normalizedUrl);

    if (parsedUrl == null) {
      return null;
    }

    if (parsedUrl.hasScheme &&
        (parsedUrl.scheme == 'http' || parsedUrl.scheme == 'https')) {
      return normalizedUrl;
    }

    final baseUri = Uri.tryParse(ApiConstants.apiBaseUrl);

    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      return null;
    }

    final normalizedPath = normalizedUrl.startsWith('/')
        ? normalizedUrl
        : '/$normalizedUrl';

    return baseUri
        .replace(path: normalizedPath, query: null, fragment: null)
        .toString();
  }

  static String _buildInitials(String fullName) {
    final nameParts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.isEmpty) {
      return '?';
    }

    if (nameParts.length == 1) {
      return nameParts.first.substring(0, 1).toUpperCase();
    }

    final firstInitial = nameParts.first.substring(0, 1).toUpperCase();

    final lastInitial = nameParts.last.substring(0, 1).toUpperCase();

    return '$firstInitial$lastInitial';
  }
}
