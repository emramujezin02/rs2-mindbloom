import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/article_form_viewmodel.dart';

class ArticleFormPage extends StatefulWidget {
  final int? articleId;

  const ArticleFormPage({super.key, this.articleId});

  bool get isEditing {
    return articleId != null;
  }

  @override
  State<ArticleFormPage> createState() => _ArticleFormPageState();
}

class _ArticleFormPageState extends State<ArticleFormPage> {
  late final ArticleFormViewModel _viewModel;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _contentController = TextEditingController();

  final TextEditingController _imageUrlController = TextEditingController();

  bool _isPublished = true;
  bool _formInitialized = false;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createArticleFormViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _imageUrlController.addListener(_onImageUrlChanged);

    if (widget.articleId != null) {
      _loadArticle();
    } else {
      _formInitialized = true;
    }
  }

  Future<void> _loadArticle() async {
    final success = await _viewModel.loadArticle(widget.articleId!);

    if (!success || !mounted) {
      return;
    }

    final article = _viewModel.article;

    if (article == null) {
      return;
    }

    _titleController.text = article.title;

    _descriptionController.text = article.description;

    _contentController.text = article.content;

    _imageUrlController.text = article.imageUrl;

    _isPublished = article.isPublished;

    _formInitialized = true;

    setState(() {});
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onImageUrlChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();

    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.saveArticle(
      articleId: widget.articleId,
      title: _titleController.text,
      description: _descriptionController.text,
      content: _contentController.text,
      imageUrl: _imageUrlController.text,
      isPublished: _isPublished,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Article updated successfully.'
                : 'Article created successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  String? _validateTitle(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Title is required.';
    }

    if (normalized.length < 3) {
      return 'Title must contain at least 3 characters.';
    }

    if (normalized.length > 200) {
      return 'Title may contain at most 200 characters.';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Description is required.';
    }

    if (normalized.length < 10) {
      return 'Description must contain at least 10 characters.';
    }

    if (normalized.length > 500) {
      return 'Description may contain at most 500 characters.';
    }

    return null;
  }

  String? _validateContent(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Content is required.';
    }

    if (normalized.length < 20) {
      return 'Content must contain at least 20 characters.';
    }

    if (normalized.length > 20000) {
      return 'Content may contain at most 20000 characters.';
    }

    return null;
  }

  String? _validateImageUrl(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.length > 1000) {
      return 'Image URL may contain at most 1000 characters.';
    }

    final uri = Uri.tryParse(normalized);

    final isAbsoluteHttp =
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');

    final isRelative = normalized.startsWith('/');

    if (!isAbsoluteHttp && !isRelative) {
      return 'Enter an HTTP/HTTPS URL or a relative application path.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit article' : 'Create article'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading || !_formInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null &&
        _viewModel.article == null &&
        widget.isEditing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadArticle,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateTitle,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateDescription,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _contentController,
                  minLines: 12,
                  maxLines: 20,
                  maxLength: 20000,
                  decoration: const InputDecoration(
                    labelText: 'Article content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateContent,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _imageUrlController,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'https://example.com/image.jpg',
                    prefixIcon: Icon(Icons.image_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateImageUrl,
                ),

                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ImagePreview(imageUrl: _imageUrlController.text.trim()),
                  const SizedBox(height: 16),
                ],

                SwitchListTile(
                  value: _isPublished,
                  onChanged: (value) {
                    setState(() {
                      _isPublished = value;
                    });
                  },
                  title: const Text('Published'),
                  subtitle: Text(
                    _isPublished
                        ? 'The article will be visible to users.'
                        : 'The article will remain an unpublished draft.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _viewModel.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _viewModel.isSaving
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _viewModel.isSaving ? null : _save,
                      icon: _viewModel.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _viewModel.isSaving
                            ? 'Saving...'
                            : widget.isEditing
                            ? 'Save changes'
                            : 'Create article',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String imageUrl;

  const _ImagePreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFECEFF1),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48),
                SizedBox(height: 8),
                Text('Image preview could not be loaded.'),
              ],
            ),
          );
        },
      ),
    );
  }
}
