import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/article_management_model.dart';
import '../viewmodels/article_management_viewmodel.dart';

class ArticleManagementPage extends StatefulWidget {
  const ArticleManagementPage({super.key});

  @override
  State<ArticleManagementPage> createState() => _ArticleManagementPageState();
}

class _ArticleManagementPageState extends State<ArticleManagementPage> {
  late final ArticleManagementViewModel _viewModel;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createArticleManagementViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadArticles();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();
    _searchController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCreatePage() async {
    final changed = await Navigator.of(
      context,
    ).pushNamed<bool>(AppRouter.articleManagementForm);

    if (changed == true) {
      await _viewModel.loadArticles(requestedPage: 1);
    }
  }

  Future<void> _openEditPage(ArticleManagementModel article) async {
    final changed = await Navigator.of(
      context,
    ).pushNamed<bool>(AppRouter.articleManagementForm, arguments: article.id);

    if (changed == true) {
      await _viewModel.loadArticles(requestedPage: _viewModel.pageNumber);
    }
  }

  Future<void> _confirmPublication(ArticleManagementModel article) async {
    final nextPublishedState = !article.isPublished;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nextPublishedState ? 'Publish article' : 'Unpublish article',
          ),
          content: Text(
            nextPublishedState
                ? 'Are you sure you want to publish "${article.title}"?'
                : 'Are you sure you want to unpublish "${article.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(nextPublishedState ? 'Publish' : 'Unpublish'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.updatePublication(
      article: article,
      isPublished: nextPublishedState,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextPublishedState
                ? 'Article published successfully.'
                : 'Article unpublished successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(ArticleManagementModel article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete article'),
          content: Text(
            'Are you sure you want to delete "${article.title}"? '
            'The article will no longer be visible to users.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.deleteArticle(article.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildFilters(),

          const SizedBox(height: 16),

          if (_viewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          Expanded(child: _buildContent()),

          const SizedBox(height: 12),

          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Articles management',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Create, edit, publish and remove articles.'),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _viewModel.isActionLoading ? null : _openCreatePage,
          icon: const Icon(Icons.add),
          label: const Text('Create article'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search articles',
              hintText: 'Title, description or author',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () async {
                        _searchController.clear();

                        setState(() {});

                        await _viewModel.clearSearch();
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {});

              _viewModel.updateSearch(value);
            },
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<bool?>(
            initialValue: _viewModel.publishedFilter,
            decoration: const InputDecoration(
              labelText: 'Publication status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('All articles')),
              DropdownMenuItem<bool?>(value: true, child: Text('Published')),
              DropdownMenuItem<bool?>(value: false, child: Text('Unpublished')),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    _viewModel.updatePublishedFilter(value);
                  },
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            initialValue: _viewModel.pageSize,
            decoration: const InputDecoration(
              labelText: 'Page size',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      _viewModel.changePageSize(value);
                    }
                  },
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _viewModel.isLoading
              ? null
              : () {
                  _viewModel.loadArticles();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.articles.isEmpty) {
      return const Center(
        child: Text('No articles match the selected filters.'),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Image')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Author')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Published')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _viewModel.articles.map(_buildRow).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(ArticleManagementModel article) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataRow(
      cells: [
        DataCell(_ArticleImage(imageUrl: article.imageUrl)),
        DataCell(
          SizedBox(
            width: 280,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  article.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(article.authorName)),
        DataCell(
          Chip(
            label: Text(article.isPublished ? 'Published' : 'Unpublished'),
            avatar: Icon(
              article.isPublished ? Icons.public : Icons.public_off,
              size: 18,
            ),
          ),
        ),
        DataCell(Text(formatter.format(article.publishedAtUtc.toLocal()))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit article',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _openEditPage(article);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: article.isPublished ? 'Unpublish' : 'Publish',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _confirmPublication(article);
                      },
                icon: Icon(
                  article.isPublished
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Delete article',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _confirmDelete(article);
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    final totalPages = _viewModel.totalPages == 0 ? 1 : _viewModel.totalPages;

    return Row(
      children: [
        Text('Total: ${_viewModel.totalCount}'),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _viewModel.canGoPrevious && !_viewModel.isLoading
              ? _viewModel.previousPage
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page ${_viewModel.pageNumber} of $totalPages'),
        IconButton(
          tooltip: 'Next page',
          onPressed: _viewModel.canGoNext && !_viewModel.isLoading
              ? _viewModel.nextPage
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ArticleImage extends StatelessWidget {
  final String imageUrl;

  const _ArticleImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const SizedBox(
        width: 72,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFECEFF1),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(Icons.image_not_supported_outlined),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 72,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            width: 72,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFFECEFF1)),
              child: Icon(Icons.broken_image_outlined),
            ),
          );
        },
      ),
    );
  }
}
