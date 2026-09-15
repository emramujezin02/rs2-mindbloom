import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../data/models/article_model.dart';
import '../viewmodels/article_viewmodel.dart';
import '../widgets/article_image.dart';

const _detailBackground = Color(0xFFFCFAFF);
const _detailLavender = Color(0xFFF5EFFC);
const _detailSurface = Color(0xFFFFFFFF);
const _detailTint = Color(0xFFFAF7FE);
const _detailBorder = Color(0xFFE8DEF3);
const _detailPrimary = Color(0xFF6D4F91);
const _detailText = Color(0xFF3E3152);
const _detailBody = Color(0xFF625B6B);
const _detailRadius = 22.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _detailBackground,
      appBar: AppBar(
        title: const Text('Article details'),
        backgroundColor: _detailBackground,
        foregroundColor: _detailText,
        surfaceTintColor: Colors.transparent,
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

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (_viewModel.detailsError != null)
            AppInlineError(
              title: 'Article could not be refreshed',
              error: _viewModel.detailsError,
              onRetry: _reload,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
          _ArticleHeader(article: article),
          _ArticleBody(article: article),
          const PublicFooter(),
        ],
      ),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  final ArticleModel article;

  const _ArticleHeader({required this.article});

  @override
  Widget build(BuildContext context) {
    final category = article.articleCategoryName.trim();
    final author = article.authorName.trim();

    return Container(
      width: double.infinity,
      color: _detailLavender,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_detailRadius),
                child: ArticleImage(
                  imageUrl: article.imageUrl,
                  aspectRatio: 16 / 10,
                ),
              ),
              const SizedBox(height: 18),
              if (category.isNotEmpty) ...[
                _DetailMetaChip(icon: Icons.category_outlined, label: category),
                const SizedBox(height: 12),
              ],
              Text(
                article.title,
                style: const TextStyle(
                  color: _detailText,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (author.isNotEmpty)
                    _DetailMetaChip(icon: Icons.person_outline, label: author),
                  _DetailMetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat(
                      'dd.MM.yyyy.',
                    ).format(article.publishedAtUtc.toLocal()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  final ArticleModel article;

  const _ArticleBody({required this.article});

  @override
  Widget build(BuildContext context) {
    final description = article.description.trim();
    final paragraphs = article.content
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      color: _detailSurface,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _detailTint,
                    borderRadius: BorderRadius.circular(_detailRadius),
                    border: Border.all(color: _detailBorder),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: _detailText,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (paragraphs.isEmpty)
                const AppInlineEmptyState(
                  message: 'This article has no body content yet.',
                  icon: Icons.article_outlined,
                )
              else
                ...paragraphs.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: SelectableText(
                      paragraph,
                      style: const TextStyle(
                        color: _detailText,
                        fontSize: 16,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _detailBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _detailPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailBody,
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
