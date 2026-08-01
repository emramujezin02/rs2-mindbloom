import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';

class ArticlePreviewPage extends StatelessWidget {
  final String title;

  final String description;

  final String content;

  final String? imageUrl;

  final String categoryName;

  final bool isPublished;

  const ArticlePreviewPage({
    super.key,
    required this.title,
    required this.description,
    required this.content,
    required this.imageUrl,
    required this.categoryName,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim() ?? '';
    final resolvedImageUrl = normalizedImageUrl.isEmpty
        ? ''
        : normalizedImageUrl.startsWith('http://') ||
              normalizedImageUrl.startsWith('https://')
        ? normalizedImageUrl
        : '${ApiConstants.apiBaseUrl}'
              '$normalizedImageUrl';
    return Scaffold(
      appBar: AppBar(title: const Text('Article preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(
                        categoryName.isEmpty ? 'No category' : categoryName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(label: Text(isPublished ? 'Published' : 'Draft')),
                  ],
                ),

                const SizedBox(height: 24),

                if (normalizedImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      resolvedImageUrl,
                      width: double.infinity,
                      height: 360,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 220,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48),
                              SizedBox(height: 8),
                              Text('Image preview is unavailable.'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),
                ],

                Text(
                  title.trim().isEmpty ? 'Untitled article' : title.trim(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  description.trim().isEmpty
                      ? 'No summary provided.'
                      : description.trim(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Divider(height: 48),

                SelectableText(
                  content.trim().isEmpty
                      ? 'No article content.'
                      : content.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
