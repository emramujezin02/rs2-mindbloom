import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/public_footer.dart';
import '../viewmodels/article_viewmodel.dart';

class ArticleDetailsPage extends StatefulWidget {
  final int articleId;

  const ArticleDetailsPage({super.key, required this.articleId});

  @override
  State<ArticleDetailsPage> createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends State<ArticleDetailsPage> {
  final ArticleViewModel _viewModel = AppInjection.createArticleViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadArticleDetails(widget.articleId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() {
    return _viewModel.loadArticleDetails(widget.articleId);
  }

  String? _buildImageUrl(String imageUrl) {
    final value = imageUrl.trim();

    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final normalizedPath = value.startsWith('/') ? value : '/$value';
    return '${ApiConstants.baseUrl}$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoadingDetails ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final article = _viewModel.selectedArticle;

    if (_viewModel.isLoadingDetails && article == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading article...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.detailsError != null && article == null) {
      return AppErrorWidget(
        title: 'Article could not be loaded',
        error: _viewModel.detailsError,
        onRetry: _reload,
      );
    }

    if (article == null) {
      return const AppEmptyStateWidget(
        title: 'Article unavailable',
        message: 'The requested article is not available.',
        icon: Icons.article_outlined,
      );
    }

    final imageUrl = _buildImageUrl(article.imageUrl);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_viewModel.detailsError != null)
            AppInlineError(
              title: 'Article could not be refreshed',
              error: _viewModel.detailsError,
              onRetry: _reload,
              margin: const EdgeInsets.all(16),
            ),
          if (imageUrl != null)
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 170,
                  child: Center(child: Icon(Icons.broken_image, size: 50)),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article.description,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(article.authorName)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat(
                        'dd.MM.yyyy.',
                      ).format(article.publishedAtUtc.toLocal()),
                    ),
                  ],
                ),
                if (article.articleCategoryName.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Chip(
                    avatar: const Icon(Icons.category, size: 17),
                    label: Text(article.articleCategoryName),
                  ),
                ],
                const Divider(height: 32),
                ...article.content
                    .split(RegExp(r'\n\s*\n'))
                    .map((paragraph) => paragraph.trim())
                    .where((paragraph) => paragraph.isNotEmpty)
                    .map(
                      (paragraph) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SelectableText(
                          paragraph,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 16, height: 1.65),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const PublicFooter(),
        ],
      ),
    );
  }
}
