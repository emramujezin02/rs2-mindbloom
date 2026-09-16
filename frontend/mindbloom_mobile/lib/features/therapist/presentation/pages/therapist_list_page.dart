import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/widgets/therapist_session_modes.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../data/models/therapist_list_arguments.dart';
import '../../data/models/therapist_model.dart';
import '../viewmodels/therapist_list_viewmodel.dart';
import '../widgets/therapist_profile_image.dart';

const _therapistBackground = Color(0xFFFCFAFF);
const _therapistLavender = Color(0xFFF5EFFC);
const _therapistSurface = Color(0xFFFFFFFF);
const _therapistTint = Color(0xFFFAF7FE);
const _therapistBorder = Color(0xFFE8DEF3);
const _therapistPrimary = Color(0xFF6D4F91);
const _therapistText = Color(0xFF3E3152);
const _therapistBody = Color(0xFF625B6B);
const _therapistRadius = 20.0;

class TherapistListPage extends StatefulWidget {
  final TherapistListArguments? arguments;
  final bool showAppBar;

  const TherapistListPage({super.key, this.arguments, this.showAppBar = true});

  @override
  State<TherapistListPage> createState() => _TherapistListPageState();
}

class _TherapistListPageState extends State<TherapistListPage> {
  final TherapistListViewModel _viewModel =
      AppInjection.createTherapistListViewModel();

  final ScrollController _scrollController = ScrollController();

  final _searchController = TextEditingController();

  final _specializationController = TextEditingController();

  final _languageController = TextEditingController();

  final _locationController = TextEditingController();

  final _minPriceController = TextEditingController();

  final _maxPriceController = TextEditingController();

  Timer? _searchDebounce;

  String? _selectedGender;
  String? _selectedSessionMode;
  String? _selectedAvailableDay;
  double? _selectedMinRating;
  String? _sortBy;
  String? _sortDirection;

  int? _selectedTherapyApproachId;
  String? _selectedTherapyApproachName;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _scrollController.addListener(_onScroll);

    _selectedTherapyApproachId = widget.arguments?.therapyApproachId;

    _selectedTherapyApproachName = widget.arguments?.therapyApproachName;

    _viewModel.loadTherapists(therapyApproachId: _selectedTherapyApproachId);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _viewModel.removeListener(_onChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _viewModel.dispose();

    _searchController.dispose();
    _specializationController.dispose();
    _languageController.dispose();
    _locationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    const threshold = 250.0;

    if (_scrollController.position.extentAfter <= threshold) {
      _viewModel.loadMore();
    }
  }

  void _onSearchTextChanged(String _) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _applyFilters();
    });
  }

  double? _parsePrice(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.'));
  }

  Future<void> _applyFilters() async {
    await _viewModel.searchTherapists(
      searchText: _searchController.text,
      specialization: _specializationController.text,
      therapyApproachId: _selectedTherapyApproachId,
      gender: _selectedGender,
      language: _languageController.text,
      location: _locationController.text,
      sessionMode: _selectedSessionMode,
      minPrice: _parsePrice(_minPriceController),
      maxPrice: _parsePrice(_maxPriceController),
      minRating: _selectedMinRating,
      availableDay: _selectedAvailableDay,
      sortBy: _sortBy,
      sortDirection: _sortDirection,
      resetPage: true,
    );
  }

  Future<void> _refresh() async {
    await _applyFilters();
  }

  void _clearSearchOnly() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    _applyFilters();
  }

  void _clearFilters() {
    _searchDebounce?.cancel();

    _searchController.clear();
    _specializationController.clear();
    _languageController.clear();
    _locationController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();

    setState(() {
      _selectedGender = null;
      _selectedSessionMode = null;
      _selectedAvailableDay = null;
      _selectedMinRating = null;
      _sortBy = null;
      _sortDirection = null;

      _selectedTherapyApproachId = null;
      _selectedTherapyApproachName = null;
    });

    _viewModel.searchTherapists(resetPage: true);
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _specializationController.text.trim().isNotEmpty ||
        _languageController.text.trim().isNotEmpty ||
        _locationController.text.trim().isNotEmpty ||
        _minPriceController.text.trim().isNotEmpty ||
        _maxPriceController.text.trim().isNotEmpty ||
        _selectedTherapyApproachId != null ||
        _selectedGender != null ||
        _selectedSessionMode != null ||
        _selectedAvailableDay != null ||
        _selectedMinRating != null ||
        _sortBy != null;
  }

  String? get _selectedSortValue {
    final sortBy = _sortBy;

    if (sortBy == null) {
      return null;
    }

    final direction = _sortDirection ??
        switch (sortBy) {
          'price' => 'asc',
          'rating' => 'desc',
          'experience' => 'desc',
          _ => null,
        };

    return direction == null ? sortBy : '$sortBy:$direction';
  }

  int get _activeFilterCount {
    var count = 0;

    if (_searchController.text.trim().isNotEmpty) count++;
    if (_specializationController.text.trim().isNotEmpty) count++;
    if (_languageController.text.trim().isNotEmpty) count++;
    if (_locationController.text.trim().isNotEmpty) count++;
    if (_minPriceController.text.trim().isNotEmpty) count++;
    if (_maxPriceController.text.trim().isNotEmpty) count++;
    if (_selectedTherapyApproachId != null) count++;
    if (_selectedGender != null) count++;
    if (_selectedSessionMode != null) count++;
    if (_selectedAvailableDay != null) count++;
    if (_selectedMinRating != null) count++;
    if (_sortBy != null) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final content = ColoredBox(
      color: _therapistBackground,
      child: Column(
        children: [
          _TherapistSearchHeader(
            searchController: _searchController,
            isLoading: _viewModel.isLoading,
            activeFilterCount: _activeFilterCount,
            hasActiveFilters: _hasActiveFilters,
            onSearchChanged: _onSearchTextChanged,
            onSubmitSearch: _applyFilters,
            onClearSearch: _clearSearchOnly,
            filters: _buildFilters(),
          ),
          if (_hasActiveFilters) _buildActiveFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: _therapistBackground,
      appBar: AppBar(
        title: const Text('Therapists'),
        backgroundColor: _therapistBackground,
        foregroundColor: _therapistText,
        surfaceTintColor: Colors.transparent,
      ),
      body: content,
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FilterSectionLabel(
            icon: Icons.manage_search_outlined,
            label: 'Search details',
          ),
          _FilterTextField(
            controller: _specializationController,
            labelText: 'Specialization',
            icon: Icons.psychology_outlined,
          ),
          const SizedBox(height: 10),
          _FilterTextField(
            controller: _languageController,
            labelText: 'Language',
            hintText: 'For example: Bosnian',
            icon: Icons.language,
          ),
          const SizedBox(height: 10),
          _FilterTextField(
            controller: _locationController,
            labelText: 'Location',
            hintText: 'City, country or address',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 18),
          const _FilterSectionLabel(
            icon: Icons.tune_outlined,
            label: 'Preferences',
          ),
          _FilterDropdown<String>(
            value: _selectedGender,
            labelText: 'Gender',
            icon: Icons.person_outline,
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });

              _applyFilters();
            },
          ),
          const SizedBox(height: 10),
          _FilterDropdown<String>(
            value: _selectedSessionMode,
            labelText: 'Session mode',
            icon: Icons.video_call_outlined,
            items: const [
              DropdownMenuItem(value: 'online', child: Text('Online')),
              DropdownMenuItem(value: 'inPerson', child: Text('In person')),
              DropdownMenuItem(
                value: 'both',
                child: Text('Online and in person'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSessionMode = value;
              });

              _applyFilters();
            },
          ),
          const SizedBox(height: 10),
          _FilterDropdown<double>(
            value: _selectedMinRating,
            labelText: 'Minimum rating',
            icon: Icons.star_outline,
            items: const [
              DropdownMenuItem(value: 1, child: Text('1.0 or higher')),
              DropdownMenuItem(value: 2, child: Text('2.0 or higher')),
              DropdownMenuItem(value: 3, child: Text('3.0 or higher')),
              DropdownMenuItem(value: 4, child: Text('4.0 or higher')),
              DropdownMenuItem(value: 4.5, child: Text('4.5 or higher')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedMinRating = value;
              });

              _applyFilters();
            },
          ),
          const SizedBox(height: 10),
          _FilterDropdown<String>(
            value: _selectedAvailableDay,
            labelText: 'Available day',
            icon: Icons.calendar_today_outlined,
            items: const [
              DropdownMenuItem(value: 'Monday', child: Text('Monday')),
              DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
              DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
              DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
              DropdownMenuItem(value: 'Friday', child: Text('Friday')),
              DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
              DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedAvailableDay = value;
              });

              _applyFilters();
            },
          ),
          const SizedBox(height: 18),
          const _FilterSectionLabel(
            icon: Icons.payments_outlined,
            label: 'Price and sorting',
          ),
          Row(
            children: [
              Expanded(
                child: _FilterTextField(
                  controller: _minPriceController,
                  labelText: 'Min price',
                  suffixText: 'KM',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterTextField(
                  controller: _maxPriceController,
                  labelText: 'Max price',
                  suffixText: 'KM',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterDropdown<String>(
            value: _selectedSortValue,
            labelText: 'Sort by',
            icon: Icons.sort,
            items: const [
              DropdownMenuItem(
                value: 'price:asc',
                child: Text('Price: low to high'),
              ),
              DropdownMenuItem(
                value: 'price:desc',
                child: Text('Price: high to low'),
              ),
              DropdownMenuItem(
                value: 'rating:asc',
                child: Text('Rating: low to high'),
              ),
              DropdownMenuItem(
                value: 'rating:desc',
                child: Text('Rating: high to low'),
              ),
              DropdownMenuItem(
                value: 'experience:desc',
                child: Text('Most experience'),
              ),
            ],
            onChanged: (value) {
              final parts = value?.split(':') ?? [];

              setState(() {
                _sortBy = parts.isNotEmpty ? parts[0] : null;
                _sortDirection = parts.length > 1 ? parts[1] : null;
              });

              _applyFilters();
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _viewModel.isLoading ? null : _applyFilters,
                icon: const Icon(Icons.search),
                label: const Text('Apply filters'),
              ),
              OutlinedButton.icon(
                onPressed: _hasActiveFilters ? _clearFilters : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    void addChip({required String label, required VoidCallback onDeleted}) {
      chips.add(
        InputChip(
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          onDeleted: onDeleted,
          deleteIcon: const Icon(Icons.close, size: 18),
          backgroundColor: _therapistTint,
          side: const BorderSide(color: _therapistBorder),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final searchText = _searchController.text.trim();

    if (searchText.isNotEmpty) {
      addChip(
        label: 'Search: $searchText',
        onDeleted: () {
          _searchDebounce?.cancel();
          _searchController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    final specialization = _specializationController.text.trim();

    if (specialization.isNotEmpty) {
      addChip(
        label: 'Specialization: $specialization',
        onDeleted: () {
          _specializationController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    if (_selectedTherapyApproachId != null) {
      addChip(
        label: 'Approach: ${_selectedTherapyApproachName ?? 'Selected'}',
        onDeleted: () {
          setState(() {
            _selectedTherapyApproachId = null;
            _selectedTherapyApproachName = null;
          });

          _applyFilters();
        },
      );
    }

    if (_selectedGender != null) {
      addChip(
        label: 'Gender: $_selectedGender',
        onDeleted: () {
          setState(() {
            _selectedGender = null;
          });

          _applyFilters();
        },
      );
    }

    final language = _languageController.text.trim();

    if (language.isNotEmpty) {
      addChip(
        label: 'Language: $language',
        onDeleted: () {
          _languageController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    final location = _locationController.text.trim();

    if (location.isNotEmpty) {
      addChip(
        label: 'Location: $location',
        onDeleted: () {
          _locationController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    if (_selectedSessionMode != null) {
      final sessionModeLabel = switch (_selectedSessionMode) {
        'online' => 'Online',
        'inPerson' => 'In person',
        'both' => 'Online and in person',
        _ => _selectedSessionMode!,
      };

      addChip(
        label: 'Session mode: $sessionModeLabel',
        onDeleted: () {
          setState(() {
            _selectedSessionMode = null;
          });

          _applyFilters();
        },
      );
    }

    final minPrice = _minPriceController.text.trim();

    if (minPrice.isNotEmpty) {
      addChip(
        label: 'Min price: $minPrice KM',
        onDeleted: () {
          _minPriceController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    final maxPrice = _maxPriceController.text.trim();

    if (maxPrice.isNotEmpty) {
      addChip(
        label: 'Max price: $maxPrice KM',
        onDeleted: () {
          _maxPriceController.clear();
          setState(() {});
          _applyFilters();
        },
      );
    }

    if (_selectedMinRating != null) {
      addChip(
        label: 'Rating: ${_selectedMinRating!.toStringAsFixed(1)}+',
        onDeleted: () {
          setState(() {
            _selectedMinRating = null;
          });

          _applyFilters();
        },
      );
    }

    if (_selectedAvailableDay != null) {
      addChip(
        label: 'Available: $_selectedAvailableDay',
        onDeleted: () {
          setState(() {
            _selectedAvailableDay = null;
          });

          _applyFilters();
        },
      );
    }

    if (_sortBy != null) {
      final sortLabel = switch (_sortBy) {
        'experience' => 'Most experience',
        'price' when _sortDirection == 'desc' => 'Price: high to low',
        'price' => 'Price: low to high',
        'rating' when _sortDirection == 'asc' => 'Rating: low to high',
        'rating' => 'Rating: high to low',
        _ => _sortBy!,
      };

      addChip(
        label: 'Sort: $sortLabel',
        onDeleted: () {
          setState(() {
            _sortBy = null;
            _sortDirection = null;
          });

          _applyFilters();
        },
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: _therapistSurface,
        border: Border(bottom: BorderSide(color: _therapistBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Active filters ($_activeFilterCount)',
                  style: const TextStyle(
                    color: _therapistText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Reset all'),
              ),
            ],
          ),
          Wrap(spacing: 7, runSpacing: 7, children: chips),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.therapists.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading therapists...',
        skeletonItemCount: 4,
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.therapists.isEmpty) {
      return AppErrorWidget(
        title: 'Therapists could not be loaded',
        error: _viewModel.errorMessage,
        fallbackMessage: 'Therapists could not be loaded.',
        onRetry: _refresh,
        footer: const PublicFooter(),
      );
    }

    if (_viewModel.therapists.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: AppEmptyStateWidget(
          title: _hasActiveFilters
              ? 'No matching therapists'
              : 'No therapists available',
          message: _hasActiveFilters
              ? 'No therapists match the selected filters. Try changing or clearing the filters.'
              : 'No therapists are currently available. Pull down to refresh the list.',
          icon: _hasActiveFilters
              ? Icons.search_off_outlined
              : Icons.psychology_outlined,
          actionLabel: _hasActiveFilters ? 'Clear filters' : 'Refresh',
          onAction: _hasActiveFilters ? _clearFilters : _refresh,
          footer: const PublicFooter(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_viewModel.errorMessage != null)
            AppInlineError(
              title: 'Therapists could not be refreshed',
              error: _viewModel.errorMessage,
              fallbackMessage: 'The existing therapists are still displayed.',
              onRetry: _refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ...List.generate(_viewModel.therapists.length, (index) {
            final therapist = _viewModel.therapists[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _viewModel.therapists.length - 1 ? 0 : 14,
              ),
              child: _TherapistResultCard(
                therapist: therapist,
                isFavorite: _viewModel.isFavorite(therapist.id),
                isChangingFavorite: _viewModel.isChangingFavorite(therapist.id),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRouter.therapistDetails,
                    arguments: therapist.id,
                  );
                },
                onToggleFavorite: () {
                  _toggleFavorite(therapist);
                },
              ),
            );
          }),
          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more therapists...',
            ),
          if (_viewModel.loadMoreErrorMessage != null)
            AppLoadMoreError(
              error: _viewModel.loadMoreErrorMessage,
              fallbackMessage: 'More therapists could not be loaded.',
              onRetry: _viewModel.retryLoadMore,
            ),
          if (!_viewModel.hasMore && _viewModel.therapists.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Center(
                child: Text(
                  'All therapists have been loaded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _therapistBody),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const PublicFooter(),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(TherapistModel therapist) async {
    final wasFavorite = _viewModel.isFavorite(therapist.id);

    final success = await _viewModel.toggleFavorite(therapist.id);

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.favoriteErrorMessage ?? 'Favorite could not be updated.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite
              ? 'Therapist removed from favorites.'
              : 'Therapist added to favorites.',
        ),
      ),
    );
  }
}

class _TherapistSearchHeader extends StatelessWidget {
  final TextEditingController searchController;
  final bool isLoading;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onSubmitSearch;
  final VoidCallback onClearSearch;
  final Widget filters;

  const _TherapistSearchHeader({
    required this.searchController,
    required this.isLoading,
    required this.activeFilterCount,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onSubmitSearch,
    required this.onClearSearch,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final maxFilterHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(220.0, 360.0)
        .toDouble();

    return Material(
      color: _therapistBackground,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _therapistLavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tune, color: _therapistPrimary),
          ),
          title: const Text(
            'Find a therapist',
            style: TextStyle(
              color: _therapistText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            hasActiveFilters
                ? '$activeFilterCount active filter${activeFilterCount == 1 ? '' : 's'}'
                : 'Search by name, specialization, or location',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _therapistBody),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  onSubmitSearch();
                },
                decoration: _fieldDecoration(
                  labelText: 'Search therapists',
                  hintText: 'Name, specialization, location...',
                  icon: Icons.search,
                  suffixIcon: searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: isLoading ? null : onClearSearch,
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxFilterHeight),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.zero,
                child: filters,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterSectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _therapistPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _therapistText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? suffixText;
  final IconData? icon;
  final TextInputType? keyboardType;

  const _FilterTextField({
    required this.controller,
    required this.labelText,
    this.hintText,
    this.suffixText,
    this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _fieldDecoration(
        labelText: labelText,
        hintText: hintText,
        icon: icon,
        suffixText: suffixText,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String labelText;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.labelText,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: _fieldDecoration(labelText: labelText, icon: icon),
      items: items,
      onChanged: onChanged,
    );
  }
}

InputDecoration _fieldDecoration({
  required String labelText,
  String? hintText,
  IconData? icon,
  String? suffixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixText: suffixText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _therapistSurface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _therapistBorder),
    ),
  );
}

class _TherapistResultCard extends StatelessWidget {
  final TherapistModel therapist;
  final bool isFavorite;
  final bool isChangingFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _TherapistResultCard({
    required this.therapist,
    required this.isFavorite,
    required this.isChangingFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final specialization = therapist.specialization.trim().isEmpty
        ? 'Specialization not specified'
        : therapist.specialization.trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _therapistSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_therapistRadius),
        side: const BorderSide(color: _therapistBorder),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TherapistProfileImage(
                    fullName: therapist.fullName,
                    profileImageUrl: therapist.profileImageUrl,
                    radius: 38,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                therapist.fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _therapistText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _FavoriteButton(
                              isFavorite: isFavorite,
                              isChanging: isChangingFavorite,
                              onPressed: onToggleFavorite,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          specialization,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _therapistPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (therapist.therapyApproaches.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: therapist.therapyApproaches
                      .take(4)
                      .map((approach) => _ApproachChip(label: approach))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              _CardMetaRow(
                icon: Icons.location_on_outlined,
                text: therapist.formattedLocation,
              ),
              const SizedBox(height: 10),
              TherapistSessionModes(
                offersOnline: therapist.offersOnline,
                offersInPerson: therapist.offersInPerson,
                compact: true,
              ),
              const SizedBox(height: 12),
              Text(
                therapist.biography.isEmpty
                    ? 'No biography added.'
                    : therapist.biography,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _therapistBody, height: 1.45),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InlineMetric(
                    icon: Icons.star_rounded,
                    iconColor: Color(0xFFF2B84B),
                    text: therapist.totalReviews == 0
                        ? 'No reviews'
                        : '${therapist.averageRating.toStringAsFixed(1)} '
                              '(${therapist.totalReviews})',
                  ),
                  _InlineMetric(
                    icon: Icons.payments_outlined,
                    text:
                        '${therapist.hourlyRate.toStringAsFixed(2)} KM / session',
                  ),
                  _InlineMetric(
                    icon: Icons.work_outline,
                    text: therapist.experienceYears == 1
                        ? '1 year'
                        : '${therapist.experienceYears} years',
                  ),
                  if (therapist.isVerified)
                    const _InlineMetric(
                      icon: Icons.verified_outlined,
                      text: 'Verified',
                      iconColor: Color(0xFF2E7D4F),
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

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final bool isChanging;
  final VoidCallback onPressed;

  const _FavoriteButton({
    required this.isFavorite,
    required this.isChanging,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: isChanging ? null : onPressed,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: isChanging
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
    );
  }
}

class _ApproachChip extends StatelessWidget {
  final String label;

  const _ApproachChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _therapistTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _therapistBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.psychology_outlined,
            color: _therapistPrimary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _therapistBody,
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

class _CardMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CardMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _therapistPrimary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _therapistBody,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _InlineMetric({
    required this.icon,
    required this.text,
    this.iconColor = _therapistPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _therapistText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
