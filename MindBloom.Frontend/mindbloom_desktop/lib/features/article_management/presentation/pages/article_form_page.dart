import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/validation/file_validation.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../viewmodels/article_form_viewmodel.dart';
import 'article_preview_page.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/app_loading_state.dart';

class ArticleFormPage extends StatefulWidget {
  final int? articleId;

  const ArticleFormPage({super.key, this.articleId});

  bool get isEditing => articleId != null;

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

    _titleController.addListener(_onFormFieldChanged);

    _descriptionController.addListener(_onFormFieldChanged);

    _contentController.addListener(_onFormFieldChanged);

    _imageUrlController.addListener(_onImageUrlChanged);

    _initialize();
  }

  void _onFormFieldChanged() {
    _viewModel.clearError();
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
    _viewModel.clearError();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _titleController.removeListener(_onFormFieldChanged);

    _descriptionController.removeListener(_onFormFieldChanged);

    _contentController.removeListener(_onFormFieldChanged);

    _imageUrlController.removeListener(_onImageUrlChanged);

    _viewModel.dispose();

    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();

    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_viewModel.isUploadingImage || _viewModel.isSaving) {
      return;
    }

    _viewModel.clearError();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileValidation.allowedImageExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final selectedFile = result.files.single;

    final filePath = selectedFile.path;

    final validationMessage = FileValidation.validateImage(
      filePath: filePath,
      extension: selectedFile.extension ?? '',
      sizeInBytes: selectedFile.size,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));

      return;
    }

    final imageUrl = await _viewModel.uploadImage(filePath!);

    if (!mounted) {
      return;
    }

    if (imageUrl == null) {
      return;
    }

    _imageUrlController.text = imageUrl;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slika članka je uspješno učitana.')),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_viewModel.isSaving) {
      return;
    }

    _viewModel.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
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
                ? 'Članak je uspješno izmijenjen.'
                : 'Članak je uspješno kreiran.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    }
  }

  String? _validateTitle(String? value) {
    return AppValidators.textLength(
      value,
      fieldName: 'Naslov',
      minLength: 3,
      maxLength: 200,
    );
  }

  String? _validateDescription(String? value) {
    return AppValidators.textLength(
      value,
      fieldName: 'Opis',
      minLength: 10,
      maxLength: 500,
    );
  }

  String? _validateContent(String? value) {
    return AppValidators.textLength(
      value,
      fieldName: 'Sadržaj članka',
      minLength: 20,
      maxLength: 20000,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Uredi članak' : 'Kreiraj članak'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading || !_formInitialized) {
      return const AppLoadingState(message: 'Učitavanje podataka članka...');
    }

    if (_viewModel.errorMessage != null &&
        _viewModel.article == null &&
        widget.isEditing) {
      return AppErrorPanel(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _loadArticle();
        },
      );
    }

    final isBusy = _viewModel.isSaving || _viewModel.isUploadingImage;

    return AppLoadingOverlay(
      isLoading: isBusy,
      message: _viewModel.isUploadingImage
          ? 'Učitavanje slike...'
          : 'Spremanje članka...',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !isBusy,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Naslov',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateTitle,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    enabled: !isBusy,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Opis',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateDescription,
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategorija članka',
                      border: OutlineInputBorder(),
                    ),
                    items: _viewModel.categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: isBusy
                        ? null
                        : (value) {
                            _viewModel.clearError();

                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Kategorija članka je obavezna.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contentController,
                    enabled: !isBusy,
                    minLines: 12,
                    maxLines: 20,
                    maxLength: 20000,
                    decoration: const InputDecoration(
                      labelText: 'Sadržaj članka',
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
                                  ? 'Naslovna slika nije učitana.'
                                  : 'Naslovna slika je učitana.',
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: isBusy ? null : _pickAndUploadImage,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              _imageUrlController.text.trim().isEmpty
                                  ? 'Učitaj sliku'
                                  : 'Zamijeni sliku',
                            ),
                          ),
                        ],
                      ),
                      if (_imageUrlController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ImagePreview(
                          imageUrl: _imageUrlController.text.trim(),
                        ),
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
                    onChanged: isBusy
                        ? null
                        : (value) {
                            _viewModel.clearError();

                            setState(() {
                              _isPublished = value;
                            });
                          },
                    title: const Text('Objavljen'),
                    subtitle: Text(
                      _isPublished
                          ? 'Članak će biti vidljiv korisnicima.'
                          : 'Članak će ostati neobjavljena skica.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_viewModel.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AppErrorBanner(
                      message: _viewModel.errorMessage!,
                      onDismiss: _viewModel.clearError,
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text('Odustani'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : _openPreview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Pregled'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: isBusy ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(
                          widget.articleId == null
                              ? 'Kreiraj članak'
                              : 'Spremi izmjene',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                Text('Pregled slike nije moguće učitati.'),
              ],
            ),
          );
        },
      ),
    );
  }
}
