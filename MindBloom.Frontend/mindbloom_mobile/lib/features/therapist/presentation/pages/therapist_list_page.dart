import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/widgets/therapist_session_modes.dart';
import '../widgets/therapist_profile_image.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/therapist_list_viewmodel.dart';
import '../../data/models/therapist_list_arguments.dart';
import '../../../../core/widgets/public_footer.dart';

class TherapistListPage extends StatefulWidget {
  final TherapistListArguments? arguments;

  const TherapistListPage({super.key, this.arguments});

  @override
  State<TherapistListPage> createState() => _TherapistListPageState();
}

class _TherapistListPageState extends State<TherapistListPage> {
  final TherapistListViewModel _viewModel =
      AppInjection.createTherapistListViewModel();


final _searchController =
    TextEditingController();

final _specializationController =
    TextEditingController();

final _languageController =
    TextEditingController();

final _locationController =
    TextEditingController();

final _minPriceController =
    TextEditingController();

final _maxPriceController =
    TextEditingController();

Timer? _searchDebounce;

String? _selectedGender;
String? _selectedSessionMode;
String? _selectedAvailableDay;
double? _selectedMinRating;
String? _sortBy;

int? _selectedTherapyApproachId;
String? _selectedTherapyApproachName;

@override
void initState() {
  super.initState();

  _viewModel.addListener(_onChanged);

  _selectedTherapyApproachId =
      widget.arguments?.therapyApproachId;

  _selectedTherapyApproachName =
      widget.arguments?.therapyApproachName;

  _viewModel.loadTherapists(
    therapyApproachId:
        _selectedTherapyApproachId,
  );
}

@override
void dispose() {
  _searchDebounce?.cancel();

  _viewModel.removeListener(_onChanged);
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

  void _onSearchTextChanged(String _) {
  _searchDebounce?.cancel();

  _searchDebounce = Timer(
    const Duration(milliseconds: 400),
    () {
      _applyFilters();
    },
  );
}

double? _parsePrice(
  TextEditingController controller,
) {
  return double.tryParse(
    controller.text
        .trim()
        .replaceAll(',', '.'),
  );
}

Future<void> _applyFilters() async {
  await _viewModel.searchTherapists(
    searchText: _searchController.text,
    specialization:
        _specializationController.text,
    therapyApproachId:
        _selectedTherapyApproachId,
    gender: _selectedGender,
    language: _languageController.text,
    location: _locationController.text,
    sessionMode: _selectedSessionMode,
    minPrice: _parsePrice(
      _minPriceController,
    ),
    maxPrice: _parsePrice(
      _maxPriceController,
    ),
    minRating: _selectedMinRating,
    availableDay: _selectedAvailableDay,
    sortBy: _sortBy,
    resetPage: true,
  );
}

Future<void> _refresh() async {
  await _applyFilters();
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

    _selectedTherapyApproachId = null;
    _selectedTherapyApproachName = null;
  });

  _viewModel.searchTherapists(
    resetPage: true,
  );
}

bool get _hasActiveFilters {
  return _searchController.text.trim().isNotEmpty ||
      _specializationController.text
          .trim()
          .isNotEmpty ||
      _languageController.text
          .trim()
          .isNotEmpty ||
      _locationController.text
          .trim()
          .isNotEmpty ||
      _minPriceController.text
          .trim()
          .isNotEmpty ||
      _maxPriceController.text
          .trim()
          .isNotEmpty ||
      _selectedTherapyApproachId != null ||
      _selectedGender != null ||
      _selectedSessionMode != null ||
      _selectedAvailableDay != null ||
      _selectedMinRating != null ||
      _sortBy != null;
}

  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Therapists'),
    ),
    body: Column(
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(
            Icons.tune,
          ),
          title: const Text(
            'Search and filters',
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: _buildFilters(),
              ),
            ),
          ],
        ),
        if (_hasActiveFilters)
          _buildActiveFilters(),
        Expanded(
          child: _buildBody(),
        ),
      ],
    ),
  );
}

 Widget _buildFilters() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      12,
      0,
      12,
      12,
    ),
    child: Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchTextChanged,
          textInputAction:
              TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search therapists',
            hintText:
                'Name, specialization, location...',
            prefixIcon: Icon(
              Icons.search,
            ),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller:
              _specializationController,
          decoration: const InputDecoration(
            labelText: 'Specialization',
            prefixIcon: Icon(
              Icons.psychology_outlined,
            ),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            prefixIcon: Icon(
              Icons.person_outline,
            ),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Female',
              child: Text('Female'),
            ),
            DropdownMenuItem(
              value: 'Male',
              child: Text('Male'),
            ),
            DropdownMenuItem(
              value: 'Other',
              child: Text('Other'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });

            _applyFilters();
          },
        ),

        const SizedBox(height: 10),

        TextField(
          controller: _languageController,
          decoration: const InputDecoration(
            labelText: 'Language',
            hintText: 'For example: Bosnian',
            prefixIcon: Icon(
              Icons.language,
            ),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            hintText:
                'City, country or address',
            prefixIcon: Icon(
              Icons.location_on_outlined,
            ),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _selectedSessionMode,
          decoration: const InputDecoration(
            labelText: 'Session mode',
            prefixIcon: Icon(
              Icons.video_call_outlined,
            ),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'online',
              child: Text('Online'),
            ),
            DropdownMenuItem(
              value: 'inPerson',
              child: Text('In person'),
            ),
            DropdownMenuItem(
              value: 'both',
              child: Text(
                'Online and in person',
              ),
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

        Row(
          children: [
            Expanded(
              child: TextField(
                controller:
                    _minPriceController,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(
                  labelText: 'Min price',
                  suffixText: 'KM',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:
                    _maxPriceController,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(
                  labelText: 'Max price',
                  suffixText: 'KM',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<double>(
          value: _selectedMinRating,
          decoration: const InputDecoration(
            labelText: 'Minimum rating',
            prefixIcon: Icon(
              Icons.star_outline,
            ),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 1,
              child: Text('1.0 or higher'),
            ),
            DropdownMenuItem(
              value: 2,
              child: Text('2.0 or higher'),
            ),
            DropdownMenuItem(
              value: 3,
              child: Text('3.0 or higher'),
            ),
            DropdownMenuItem(
              value: 4,
              child: Text('4.0 or higher'),
            ),
            DropdownMenuItem(
              value: 4.5,
              child: Text('4.5 or higher'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMinRating = value;
            });

            _applyFilters();
          },
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _selectedAvailableDay,
          decoration: const InputDecoration(
            labelText: 'Available day',
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
            ),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Monday',
              child: Text('Monday'),
            ),
            DropdownMenuItem(
              value: 'Tuesday',
              child: Text('Tuesday'),
            ),
            DropdownMenuItem(
              value: 'Wednesday',
              child: Text('Wednesday'),
            ),
            DropdownMenuItem(
              value: 'Thursday',
              child: Text('Thursday'),
            ),
            DropdownMenuItem(
              value: 'Friday',
              child: Text('Friday'),
            ),
            DropdownMenuItem(
              value: 'Saturday',
              child: Text('Saturday'),
            ),
            DropdownMenuItem(
              value: 'Sunday',
              child: Text('Sunday'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedAvailableDay =
                  value;
            });

            _applyFilters();
          },
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: const InputDecoration(
            labelText: 'Sort by',
            prefixIcon: Icon(
              Icons.sort,
            ),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'rating',
              child: Text(
                'Highest rating',
              ),
            ),
            DropdownMenuItem(
              value: 'price',
              child: Text(
                'Lowest price',
              ),
            ),
            DropdownMenuItem(
              value: 'experience',
              child: Text(
                'Most experience',
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _sortBy = value;
            });

            _applyFilters();
          },
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _applyFilters,
                icon: const Icon(
                  Icons.search,
                ),
                label: const Text(
                  'Apply filters',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _hasActiveFilters
                    ? _clearFilters
                    : null,
                icon: const Icon(
                  Icons.restart_alt,
                ),
                label: const Text(
                  'Reset all',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildActiveFilters() {
  final chips = <Widget>[];

  void addChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    chips.add(
      InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIcon: const Icon(
          Icons.close,
          size: 18,
        ),
      ),
    );
  }

  final searchText =
      _searchController.text.trim();

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

  final specialization =
      _specializationController.text.trim();

  if (specialization.isNotEmpty) {
    addChip(
      label:
          'Specialization: $specialization',
      onDeleted: () {
        _specializationController.clear();
        setState(() {});
        _applyFilters();
      },
    );
  }

  if (_selectedTherapyApproachId != null) {
    addChip(
      label:
          'Approach: ${_selectedTherapyApproachName ?? 'Selected'}',
      onDeleted: () {
        setState(() {
          _selectedTherapyApproachId =
              null;
          _selectedTherapyApproachName =
              null;
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

  final language =
      _languageController.text.trim();

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

  final location =
      _locationController.text.trim();

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
    final sessionModeLabel =
        switch (_selectedSessionMode) {
      'online' => 'Online',
      'inPerson' => 'In person',
      'both' => 'Online and in person',
      _ => _selectedSessionMode!,
    };

    addChip(
      label:
          'Session mode: $sessionModeLabel',
      onDeleted: () {
        setState(() {
          _selectedSessionMode = null;
        });

        _applyFilters();
      },
    );
  }

  final minPrice =
      _minPriceController.text.trim();

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

  final maxPrice =
      _maxPriceController.text.trim();

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
      label:
          'Rating: ${_selectedMinRating!.toStringAsFixed(1)}+',
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
      label:
          'Available: $_selectedAvailableDay',
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
      'rating' => 'Highest rating',
      'price' => 'Lowest price',
      'experience' => 'Most experience',
      _ => _sortBy!,
    };

    addChip(
      label: 'Sort: $sortLabel',
      onDeleted: () {
        setState(() {
          _sortBy = null;
        });

        _applyFilters();
      },
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      12,
      4,
      12,
      12,
    ),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Color(0xFFE5DCEA),
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Active filters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'Reset all',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: chips,
        ),
      ],
    ),
  );
}

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 52,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Therapists could not be loaded',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120),
            const PublicFooter(),
          ],
        ),
      );
    }

    if (_viewModel.therapists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _hasActiveFilters
                    ? 'No therapists match the selected filters.'
                    : 'No therapists are currently available.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 180),
          const PublicFooter(),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(_viewModel.therapists.length, (index) {
                final therapist = _viewModel.therapists[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _viewModel.therapists.length - 1 ? 0 : 12,
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRouter.therapistDetails,
                        arguments: therapist.id,
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: TherapistProfileImage(
                                fullName: therapist.fullName,
                                profileImageUrl: therapist.profileImageUrl,
                                radius: 42,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    therapist.fullName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (therapist.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5EC),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: Color(0xFF2E7D4F),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Verified',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2E7D4F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                IconButton(
                                  onPressed:
                                      _viewModel.isChangingFavorite(
                                        therapist.id,
                                      )
                                      ? null
                                      : () async {
                                          final wasFavorite = _viewModel
                                              .isFavorite(therapist.id);

                                          final success = await _viewModel
                                              .toggleFavorite(therapist.id);

                                          if (!mounted || !success) {
                                            return;
                                          }

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                wasFavorite
                                                    ? 'Therapist removed from favorites.'
                                                    : 'Therapist added to favorites.',
                                              ),
                                            ),
                                          );
                                        },
                                  tooltip: _viewModel.isFavorite(therapist.id)
                                      ? 'Remove from favorites'
                                      : 'Add to favorites',
                                  icon:
                                      _viewModel.isChangingFavorite(
                                        therapist.id,
                                      )
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _viewModel.isFavorite(therapist.id)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                        ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              therapist.specialization.trim().isEmpty
                                  ? 'Specialization not specified'
                                  : therapist.specialization,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF72559A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (therapist.therapyApproaches.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: therapist.therapyApproaches
                                    .map(
                                      (approach) => Chip(
                                        avatar: const Icon(
                                          Icons.psychology_outlined,
                                          size: 16,
                                        ),
                                        label: Text(approach),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 19,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    therapist.formattedLocation,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TherapistSessionModes(
                              offersOnline: therapist.offersOnline,
                              offersInPerson: therapist.offersInPerson,
                              compact: true,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              therapist.biography.isEmpty
                                  ? 'No biography added.'
                                  : therapist.biography,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Color(0xFFF2B84B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  therapist.totalReviews == 0
                                      ? 'No reviews'
                                      : '${therapist.averageRating.toStringAsFixed(1)} '
                                            '(${therapist.totalReviews})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${therapist.hourlyRate.toStringAsFixed(2)} KM / session',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                const Icon(Icons.work_outline, size: 19),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    therapist.experienceYears == 1
                                        ? '1 year of experience'
                                        : '${therapist.experienceYears} years of experience',
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
              }),
            ),
          ),
          const SizedBox(height: 20),
          const PublicFooter(),
        ],
      ),
    );
  }
}
