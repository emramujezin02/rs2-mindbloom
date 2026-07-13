import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../viewmodels/article_viewmodel.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final ArticleViewModel _viewModel = AppInjection.createArticleViewModel();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadArticles();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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

    return '${ApiConstants.baseUrl}'
        '$normalizedPath';
  }

  Future<void> _search() async {
    await _viewModel.loadArticles(search: _searchController.text.trim());
  }

  Future<void> _clearSearch() async {
    _searchController.clear();

    await _viewModel.loadArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      _search();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search articles',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _viewModel.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_viewModel.articles.isEmpty) {
      return const Center(child: Text('No articles were found.'));
    }

    return RefreshIndicator(
      onRefresh: () =>
          _viewModel.loadArticles(search: _viewModel.currentSearch),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount:
            _viewModel.articles.length + (_viewModel.hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _viewModel.articles.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ElevatedButton(
                  onPressed: _viewModel.isLoadingMore
                      ? null
                      : _viewModel.loadMore,
                  child: _viewModel.isLoadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
            );
          }

          final article = _viewModel.articles[index];

          final imageUrl = _buildImageUrl(article.imageUrl);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed(AppRouter.articleDetails, arguments: article.id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 130,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 45),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          article.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd.MM.yyyy.',
                          ).format(article.publishedAtUtc.toLocal()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
