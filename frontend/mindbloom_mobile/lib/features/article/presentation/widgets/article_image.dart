import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';

class ArticleImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  const ArticleImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _buildImageUrl(imageUrl);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: resolvedUrl == null
            ? const ArticleImageFallback()
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ArticleImageFallback(),
              ),
      ),
    );
  }

  static String? _buildImageUrl(String imageUrl) {
    final value = imageUrl.trim();

    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final normalizedPath = value.startsWith('/') ? value : '/$value';

    return '${ApiConstants.baseUrl}$normalizedPath';
  }
}

class ArticleImageFallback extends StatelessWidget {
  const ArticleImageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE9DFFF),
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 54,
          color: Color(0xFF6D4F91),
        ),
      ),
    );
  }
}
