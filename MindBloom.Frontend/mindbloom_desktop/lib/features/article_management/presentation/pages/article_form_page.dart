import 'package:flutter/material.dart';
import 'article_preview_page.dart';
import '../../../../app/di/injection.dart';
import '../viewmodels/article_form_viewmodel.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/api_constants.dart';

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

  bool _isPublished = false;
  int? _selectedCategoryId;
  bool _formInitialized = false;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createArticleFormViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _imageUrlController.addListener(_onImageUrlChanged);

    _initialize();
  }

  void _openPreview() {
    final selectedCategory = _viewModel.categories
        .where((category) => category.id == _selectedCategoryId)
        .firstOrNull;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArticlePreviewPage(
          title: _titleController.text,
          description: _descriptionController.text,
          content: _contentController.text,
          imageUrl: _imageUrlController.text,
          categoryName: selectedCategory?.name ?? '',
          isPublished: _isPublished,
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    final categoriesLoaded = await _viewModel.loadCategories();

    if (!categoriesLoaded || !mounted) {
      return;
    }

    if (widget.articleId != null) {
      await _loadArticle();
      return;
    }

    if (_viewModel.categories.isNotEmpty) {
      _selectedCategoryId = _viewModel.categories.first.id;
    }

    _formInitialized = true;

    setState(() {});
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
    _selectedCategoryId = article.articleCategoryId;
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

  Future<void> _pickAndUploadImage() async {
    if (_viewModel.isUploadingImage) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final selectedFile = result.files.single;

    final filePath = selectedFile.path;

    if (filePath == null || filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected file could not be read.')),
      );

      return;
    }

    const maximumFileSize = 5 * 1024 * 1024;

    if (selectedFile.size > maximumFileSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article image may not exceed 5 MB.')),
      );

      return;
    }

    final imageUrl = await _viewModel.uploadImage(filePath);

    if (!mounted) {
      return;
    }

    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.errorMessage ?? 'Image upload failed.'),
        ),
      );

      return;
    }

    _imageUrlController.text = imageUrl;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article image uploaded successfully.')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an article category.')),
      );

      return;
    }

    final success = await _viewModel.saveArticle(
      articleId: widget.articleId,
      title: _titleController.text,
      description: _descriptionController.text,
      content: _contentController.text,
      imageUrl: _imageUrlController.text,
      isPublished: _isPublished,
      articleCategoryId: _selectedCategoryId!,
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

                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Article category',
                    border: OutlineInputBorder(),
                  ),
                  items: _viewModel.categories
                      .map(
                        (category) => DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: _viewModel.isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Article category is required.';
                    }

                    return null;
                  },
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _imageUrlController.text.trim().isEmpty
                                ? 'No cover image uploaded.'
                                : 'Cover image uploaded.',
                          ),
                        ),

                        const SizedBox(width: 12),

                        OutlinedButton.icon(
                          onPressed:
                              _viewModel.isSaving || _viewModel.isUploadingImage
                              ? null
                              : _pickAndUploadImage,
                          icon: _viewModel.isUploadingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(
                            _viewModel.isUploadingImage
                                ? 'Uploading...'
                                : _imageUrlController.text.trim().isEmpty
                                ? 'Upload cover image'
                                : 'Replace image',
                          ),
                        ),
                      ],
                    ),

                    if (_imageUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),

                      _ImagePreview(imageUrl: _imageUrlController.text.trim()),

                      const SizedBox(height: 8),

                      Text(
                        _imageUrlController.text,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _viewModel.isSaving ? null : _openPreview,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Preview'),
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton.icon(
                          onPressed: _viewModel.isSaving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                            widget.articleId == null
                                ? 'Create article'
                                : 'Save changes',
                          ),
                        ),
                      ],
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
    final normalizedUrl = imageUrl.trim();

    final String resolvedUrl;

    if (normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://')) {
      resolvedUrl = normalizedUrl;
    } else {
      final apiUri = Uri.parse(ApiConstants.apiBaseUrl);

      resolvedUrl = apiUri
          .replace(
            path: normalizedUrl.startsWith('/')
                ? normalizedUrl
                : '/$normalizedUrl',
            query: null,
            fragment: null,
          )
          .toString();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        resolvedUrl,
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
