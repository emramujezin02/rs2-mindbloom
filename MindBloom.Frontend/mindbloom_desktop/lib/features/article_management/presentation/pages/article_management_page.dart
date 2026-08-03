import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_error_banner.dart';
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

    _viewModel.loadCategories();
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

  Future<void> _clearFilters() async {
    _searchController.clear();

    if (mounted) {
      setState(() {});
    }

    await _viewModel.clearFilters();
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _viewModel.publishedFilter != null ||
        _viewModel.categoryFilter != null;
  }

  Widget _buildActiveFilters() {
    if (!_hasActiveFilters) {
      return const SizedBox.shrink();
    }

    final category = _viewModel.categoryFilter == null
        ? null
        : _viewModel.categories
              .where((item) => item.id == _viewModel.categoryFilter)
              .firstOrNull;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_searchController.text.trim().isNotEmpty)
          Chip(
            avatar: const Icon(Icons.search, size: 18),
            label: Text('Pretraga: ${_searchController.text.trim()}'),
          ),
        if (_viewModel.publishedFilter != null)
          Chip(
            label: Text(
              _viewModel.publishedFilter!
                  ? 'Status: Objavljen'
                  : 'Status: Neobjavljen',
            ),
          ),
        if (category != null) Chip(label: Text('Kategorija: ${category.name}')),
        ActionChip(
          avatar: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Resetuj filtere'),
          onPressed: _viewModel.isLoading ? null : _clearFilters,
        ),
      ],
    );
  }

  Future<void> _openCreatePage() async {
    final changed = await Navigator.of(
      context,
    ).pushNamed<bool>(AppRouter.articleManagementForm);

    if (!mounted) {
      return;
    }

    if (changed == true) {
      await _viewModel.loadArticles(requestedPage: 1);
    }
  }

  Future<void> _openEditPage(ArticleManagementModel article) async {
    final changed = await Navigator.of(
      context,
    ).pushNamed<bool>(AppRouter.articleManagementForm, arguments: article.id);

    if (!mounted) {
      return;
    }

    if (changed == true) {
      await _viewModel.loadArticles(requestedPage: _viewModel.pageNumber);
    }
  }

  Future<void> _confirmPublication(ArticleManagementModel article) async {
    final nextPublishedState = !article.isPublished;

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: nextPublishedState ? 'Objavi članak' : 'Poništi objavu članka',
      message: nextPublishedState
          ? 'Da li ste sigurni da želite objaviti "${article.title}"?'
          : 'Da li ste sigurni da želite poništiti objavu članka "${article.title}"?',
      confirmText: nextPublishedState ? 'Objavi' : 'Poništi objavu',
      destructive: !nextPublishedState,
    );

    if (!confirmed || !mounted) {
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
                ? 'Članak je objavljen.'
                : 'Objava članka je poništena.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(ArticleManagementModel article) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Obriši članak',
      message:
          'Da li ste sigurni da želite obrisati "${article.title}"? '
          'Članak više neće biti vidljiv korisnicima.',
      confirmText: 'Obriši',
      destructive: true,
      icon: Icons.delete_outline,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.deleteArticle(article.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Članak je obrisan.')));
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

          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],

          const SizedBox(height: 16),

          if (_viewModel.errorMessage != null && _viewModel.articles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppErrorBanner(
                message: _viewModel.errorMessage!,
                onDismiss: _viewModel.clearError,
              ),
            ),

          Expanded(child: _buildContent()),

          if (_viewModel.articles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPagination(),
          ],
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
                'Upravljanje člancima',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Kreiranje, uređivanje, objavljivanje i uklanjanje članaka.',
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _viewModel.isActionLoading ? null : _openCreatePage,
          icon: const Icon(Icons.add),
          label: const Text('Kreiraj članak'),
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
            enabled: !_viewModel.isLoading,
            decoration: InputDecoration(
              labelText: 'Pretraži članke',
              hintText: 'Naslov, opis ili autor',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Očisti pretragu',
                      onPressed: _viewModel.isLoading
                          ? null
                          : () async {
                              _searchController.clear();

                              if (mounted) {
                                setState(() {});
                              }

                              await _viewModel.clearSearch();
                            },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (mounted) {
                setState(() {});
              }

              _viewModel.updateSearch(value);
            },
            onSubmitted: (_) {
              _viewModel.loadArticles(
                requestedPage: 1,
                clearCurrentResults: true,
              );
            },
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<bool?>(
            initialValue: _viewModel.publishedFilter,
            decoration: const InputDecoration(
              labelText: 'Status objave',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('Svi članci')),
              DropdownMenuItem<bool?>(value: true, child: Text('Objavljeni')),
              DropdownMenuItem<bool?>(
                value: false,
                child: Text('Neobjavljeni'),
              ),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    _viewModel.updatePublishedFilter(value);
                  },
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            initialValue: _viewModel.categoryFilter,
            decoration: const InputDecoration(
              labelText: 'Kategorija članka',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sve kategorije'),
              ),
              ..._viewModel.categories.map((category) {
                return DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(category.name),
                );
              }),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    _viewModel.updateCategoryFilter(value);
                  },
          ),
        ),
        IconButton(
          tooltip: 'Osvježi',
          onPressed: _viewModel.isLoading
              ? null
              : () {
                  _viewModel.loadArticles();
                },
          icon: const Icon(Icons.refresh),
        ),
        OutlinedButton.icon(
          onPressed: _viewModel.isLoading ? null : _clearFilters,
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('Resetuj filtere'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.articles.isEmpty) {
      return const AdminTableLoadingState(message: 'Učitavanje članaka...');
    }

    if (_viewModel.articles.isEmpty && _viewModel.errorMessage != null) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadArticles();
        },
      );
    }

    if (_viewModel.articles.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.article_outlined,
        title: 'Nema članaka',
        message: 'Nijedan članak ne odgovara odabranim filterima.',
      );
    }

    return AdminTableContainer(
      minimumWidth: 1050,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Slika')),
          DataColumn(label: Text('Naslov')),
          DataColumn(label: Text('Autor')),
          DataColumn(label: Text('Kategorija')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Objavljeno')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.articles.map(_buildRow).toList(),
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
          Text(
            article.articleCategoryName.trim().isEmpty
                ? '—'
                : article.articleCategoryName,
          ),
        ),
        DataCell(
          Chip(
            label: Text(article.isPublished ? 'Objavljen' : 'Neobjavljen'),
            avatar: Icon(
              article.isPublished ? Icons.public : Icons.public_off,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        DataCell(
          Text(
            article.publishedAtUtc == null
                ? '—'
                : formatter.format(article.publishedAtUtc!.toLocal()),
          ),
        ),
        DataCell(
          AdminTableActionMenu<String>(
            enabled: !_viewModel.isActionLoading,
            actions: [
              const AdminTableAction<String>(
                value: 'edit',
                label: 'Uredi',
                icon: Icons.edit_outlined,
              ),
              AdminTableAction<String>(
                value: 'publication',
                label: article.isPublished ? 'Poništi objavu' : 'Objavi',
                icon: article.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              const AdminTableAction<String>(
                value: 'delete',
                label: 'Obriši',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditPage(article);
                  break;

                case 'publication':
                  _confirmPublication(article);
                  break;

                case 'delete':
                  _confirmDelete(article);
                  break;
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return AdminTablePagination(
      pageNumber: _viewModel.pageNumber,
      pageSize: _viewModel.pageSize,
      totalCount: _viewModel.totalCount,
      totalPages: _viewModel.totalPages,
      isLoading: _viewModel.isLoading,
      onPreviousPage: _viewModel.canGoPrevious ? _viewModel.previousPage : null,
      onNextPage: _viewModel.canGoNext ? _viewModel.nextPage : null,
      onPageSizeChanged: _viewModel.changePageSize,
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
              decoration: BoxDecoration(
                color: Color(0xFFECEFF1),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Icon(Icons.broken_image_outlined),
            ),
          );
        },
      ),
    );
  }
}
