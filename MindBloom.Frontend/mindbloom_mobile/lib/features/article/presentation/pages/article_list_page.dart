import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../data/models/article_category_model.dart';
import '../../data/models/article_model.dart';
import '../viewmodels/article_viewmodel.dart';
import '../widgets/article_image.dart';

const _articleBackground = Color(0xFFFCFAFF);
const _articleSurface = Color(0xFFFFFFFF);
const _articleTint = Color(0xFFFAF7FE);
const _articleBorder = Color(0xFFE8DEF3);
const _articlePrimary = Color(0xFF6D4F91);
const _articleText = Color(0xFF3E3152);
const _articleBody = Color(0xFF625B6B);
const _articleRadius = 20.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _articleBackground,
      appBar: AppBar(
        title: const Text('Articles'),
        backgroundColor: _articleBackground,
        foregroundColor: _articleText,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _ArticleListHeader(
            searchController: _searchController,
            isBusy: _viewModel.isLoading,
            onSearch: _search,
            onClearSearch: _clearSearch,
          ),
          _CategoryFilter(
            isLoading: _viewModel.isLoadingCategories,
            categoriesError: _viewModel.categoriesError,
            selectedCategoryId: _viewModel.selectedArticleCategoryId,
            categories: _viewModel.categories,
            isArticlesLoading: _viewModel.isLoading,
            onRetryCategories: _viewModel.loadCategories,
            onChanged: _viewModel.filterByCategory,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.articles.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading articles...',
        skeletonItemCount: 5,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Articles could not be refreshed',
              error: _viewModel.error,
              onRetry: _refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ..._viewModel.articles.map(
            (article) => _ArticleCard(article: article),
          ),
          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more articles...',
            )
          else if (_viewModel.loadMoreError != null)
            AppLoadMoreError(
              error: _viewModel.loadMoreError,
              fallbackMessage: 'More articles could not be loaded.',
              onRetry: _viewModel.retryLoadMore,
            )
          else if (_viewModel.hasMorePages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
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

class _ArticleListHeader extends StatelessWidget {
  final TextEditingController searchController;
  final bool isBusy;
  final Future<void> Function() onSearch;
  final Future<void> Function() onClearSearch;

  const _ArticleListHeader({
    required this.searchController,
    required this.isBusy,
    required this.onSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const BoxDecoration(
        color: _articleBackground,
        border: Border(bottom: BorderSide(color: _articleBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MindBloom articles',
            style: TextStyle(
              color: _articleText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Explore educational content written by professionals.',
            style: TextStyle(color: _articleBody, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              onSearch();
            },
            decoration: InputDecoration(
              labelText: 'Search articles',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: isBusy ? null : onSearch,
                      tooltip: 'Search',
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton(
                      onPressed: isBusy ? null : onClearSearch,
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),
              ),
              filled: true,
              fillColor: _articleSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _articleBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final bool isLoading;
  final String? categoriesError;
  final int? selectedCategoryId;
  final List<ArticleCategoryModel> categories;
  final bool isArticlesLoading;
  final Future<void> Function() onRetryCategories;
  final Future<void> Function(int?) onChanged;

  const _CategoryFilter({
    required this.isLoading,
    required this.categoriesError,
    required this.selectedCategoryId,
    required this.categories,
    required this.isArticlesLoading,
    required this.onRetryCategories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          if (categoriesError != null)
            AppInlineError(
              title: 'Categories could not be loaded',
              error: categoriesError,
              onRetry: onRetryCategories,
              margin: const EdgeInsets.only(bottom: 10),
            ),
          DropdownButtonFormField<int?>(
            initialValue: selectedCategoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Article category',
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
              fillColor: _articleSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _articleBorder),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All categories'),
              ),
              ...categories.map(
                (category) => DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: isArticlesLoading ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final ArticleModel article;

  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final category = article.articleCategoryName.trim();
    final author = article.authorName.trim();
    final description = article.description.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: _articleSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_articleRadius),
        side: const BorderSide(color: _articleBorder),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRouter.articleDetails, arguments: article.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArticleImage(imageUrl: article.imageUrl),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty) ...[
                    _ArticleMetaChip(
                      icon: Icons.category_outlined,
                      label: category,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _articleText,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _articleBody, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (author.isNotEmpty)
                        _ArticleMetaChip(
                          icon: Icons.person_outline,
                          label: author,
                        ),
                      _ArticleMetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat(
                          'dd.MM.yyyy.',
                        ).format(article.publishedAtUtc.toLocal()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Text(
                        'Read article',
                        style: TextStyle(
                          color: _articlePrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        color: _articlePrimary,
                        size: 18,
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

class _ArticleMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ArticleMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _articleTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _articleBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _articlePrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _articleBody,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
