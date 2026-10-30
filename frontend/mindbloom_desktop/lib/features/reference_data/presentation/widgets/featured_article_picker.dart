import 'package:flutter/material.dart';
import '../../../article_management/data/models/article_management_model.dart';
import '../../../article_management/data/repositories/article_management_repository.dart';

/// Uses all published management pages, never an inferred title match.
class FeaturedArticlePicker extends StatefulWidget {
  final ArticleManagementRepository repository;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const FeaturedArticlePicker({
    super.key,
    required this.repository,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<FeaturedArticlePicker> createState() => _FeaturedArticlePickerState();
}

class _FeaturedArticlePickerState extends State<FeaturedArticlePicker> {
  List<ArticleManagementModel> _articles = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final articles = <ArticleManagementModel>[];
      var page = 1;
      while (true) {
        final result = await widget.repository.getArticles(
          pageNumber: page,
          pageSize: 100,
          isPublished: true,
        );
        articles.addAll(result.items);
        if (page >= result.totalPages || result.items.isEmpty) break;
        page++;
      }
      if (mounted) setState(() => _articles = articles);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_failed) {
      return TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Članke nije moguće učitati. Pokušaj ponovo.'),
      );
    }
    final selected = widget.selectedId ?? 0;
    return DropdownButtonFormField<int>(
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Glavni objavljeni članak',
        border: OutlineInputBorder(),
        helperText: 'Bez članka: SAZNAJ VIŠE nije dostupan.',
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Bez članka')),
        if (selected != 0 &&
            !_articles.any((article) => article.id == selected))
          DropdownMenuItem(
            value: selected,
            child: const Text('Trenutni članak nije javno dostupan'),
          ),
        ..._articles.map(
          (article) => DropdownMenuItem(
            value: article.id,
            child: Text(
              article.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (id) => widget.onChanged(id == 0 ? null : id),
    );
  }
}
