import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/article_model.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
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

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() async {
    await _viewModel.loadArticleDetails(widget.articleId);
  }

  String? _buildImageUrl(String imageUrl) {
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

  @override
  Widget build(BuildContext context) {
    final article = _viewModel.selectedArticle;

    return Scaffold(
      appBar: AppBar(title: const Text('Article details')),
      body: _buildBody(article),
    );
  }

  Widget _buildBody(ArticleModel? article) {
    if (_viewModel.isLoadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (article == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.error ?? 'Article could not be loaded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final imageUrl = _buildImageUrl(article.imageUrl);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        children: [
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
                const Divider(height: 32),
                Text(
                  article.content,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
