import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/article_model.dart';
import '../viewmodels/article_viewmodel.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final ArticleViewModel _viewModel = AppInjection.createArticleViewModel();

  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _scrollController.addListener(_onScroll);

    _viewModel.loadInitialData();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _scrollController.removeListener(_onScroll);

    _searchController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 150) {
      _viewModel.loadMore();
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    await _viewModel.searchArticles(_searchController.text);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();

    FocusScope.of(context).unfocus();

    await _viewModel.clearSearch();
  }

  Future<void> _refresh() async {
    await _viewModel.refreshArticles();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      body: Column(
        children: [
          _buildSearch(),
          _buildCategoryFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
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
          IconButton(
            onPressed: _viewModel.isLoading ? null : _search,
            tooltip: 'Search',
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: _viewModel.isLoading ? null : _clearSearch,
            tooltip: 'Clear search',
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    if (_viewModel.isLoadingCategories) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LinearProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DropdownButtonFormField<int?>(
        initialValue: _viewModel.selectedArticleCategoryId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Article category',
          prefixIcon: Icon(Icons.category),
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All categories'),
          ),
          ..._viewModel.categories.map(
            (category) => DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.name),
            ),
          ),
        ],
        onChanged: _viewModel.isLoading
            ? null
            : (value) {
                _viewModel.filterByCategory(value);
              },
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.articles.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading articles...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.articles.isEmpty) {
      return AppErrorWidget(
        title: 'Articles could not be loaded',
        error: _viewModel.error,
        onRetry: _refresh,
        footer: const PublicFooter(),
      );
    }

    if (_viewModel.articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No articles found',
          message: 'Try changing the search text or selected category.',
          icon: Icons.article_outlined,
          footer: PublicFooter(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Articles could not be refreshed',
              error: _viewModel.error,
              onRetry: _refresh,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            ),
          ..._viewModel.articles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: index == 0 ? 12 : 0,
              ),
              child: _ArticleCard(
                article: article,
                imageUrl: _buildImageUrl(article.imageUrl),
              ),
            );
          }),
          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more articles...',
            )
          else if (_viewModel.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AppLoadMoreError(
                error: _viewModel.loadMoreError,
                fallbackMessage: 'More articles could not be loaded.',
                onRetry: _viewModel.retryLoadMore,
              ),
            )
          else if (_viewModel.hasMorePages)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton.icon(
                onPressed: _viewModel.loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: PublicFooter(),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final ArticleModel article;
  final String? imageUrl;

  const _ArticleCard({required this.article, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
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
                imageUrl!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 140,
                    child: Center(child: Icon(Icons.broken_image, size: 45)),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.articleCategoryName.trim().isNotEmpty) ...[
                    Chip(
                      avatar: const Icon(Icons.category, size: 17),
                      label: Text(article.articleCategoryName),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                  if (article.articleCategoryName.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Chip(
                      avatar: const Icon(Icons.category, size: 17),
                      label: Text(article.articleCategoryName),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(article.authorName)),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
