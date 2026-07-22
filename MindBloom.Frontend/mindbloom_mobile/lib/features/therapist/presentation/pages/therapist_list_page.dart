import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/widgets/therapist_session_modes.dart';
import '../widgets/therapist_profile_image.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/therapist_list_viewmodel.dart';
import '../../data/models/therapist_list_arguments.dart';

class TherapistListPage extends StatefulWidget {
  final TherapistListArguments? arguments;

  const TherapistListPage({super.key, this.arguments});

  @override
  State<TherapistListPage> createState() => _TherapistListPageState();
}

class _TherapistListPageState extends State<TherapistListPage> {
  final TherapistListViewModel _viewModel =
      AppInjection.createTherapistListViewModel();

  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  String? _sortBy;
  int? _selectedTherapyApproachId;
  String? _selectedTherapyApproachName;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _selectedTherapyApproachId = widget.arguments?.therapyApproachId;

    _selectedTherapyApproachName = widget.arguments?.therapyApproachName;

    _viewModel.loadTherapists(therapyApproachId: _selectedTherapyApproachId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _nameController.dispose();
    _specializationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applyFilters() {
    _viewModel.searchTherapists(
      name: _nameController.text,
      specialization: _specializationController.text,
      therapyApproachId: _selectedTherapyApproachId,
      minPrice: double.tryParse(_minPriceController.text),
      maxPrice: double.tryParse(_maxPriceController.text),
      sortBy: _sortBy,
    );
  }

  void _clearFilters() {
    _nameController.clear();
    _specializationController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();

    setState(() {
      _sortBy = null;
      _selectedTherapyApproachId = null;
      _selectedTherapyApproachName = null;
    });

    _viewModel.loadTherapists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Therapists')),
      body: Column(
        children: [
          if (_selectedTherapyApproachId != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8C7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_alt_outlined,
                    color: Color(0xFF72559A),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected therapy approach',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF756B7D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedTherapyApproachName ?? 'Therapy approach',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF49375D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove therapy approach filter',
                    onPressed: () {
                      setState(() {
                        _selectedTherapyApproachId = null;
                        _selectedTherapyApproachName = null;
                      });

                      _applyFilters();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Search by name',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _specializationController,
            decoration: const InputDecoration(
              labelText: 'Specialization',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'rating', child: Text('Highest rating')),
              DropdownMenuItem(value: 'price', child: Text('Lowest price')),
              DropdownMenuItem(
                value: 'experience',
                child: Text('Most experience'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value;
              });
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
            ],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _viewModel.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_viewModel.therapists.isEmpty) {
      return const Center(child: Text('No therapists available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.therapists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final therapist = _viewModel.therapists[index];

        return InkWell(
          onTap: () {
            Navigator.of(
              context,
            ).pushNamed(AppRouter.therapistDetails, arguments: therapist.id);
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
                      IconButton(
                        onPressed: () async {
                          final wasFavorite = _viewModel.isFavorite(
                            therapist.id,
                          );

                          final success = await _viewModel.toggleFavorite(
                            therapist.id,
                          );

                          if (!context.mounted || !success) {
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
                        },
                        tooltip: _viewModel.isFavorite(therapist.id)
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        icon: Icon(
                          _viewModel.isFavorite(therapist.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    therapist.specialization,
                    style: const TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 19),
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
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 4),
                      Text(therapist.averageRating.toStringAsFixed(1)),
                      const Spacer(),
                      Text(
                        '${therapist.hourlyRate.toStringAsFixed(2)} KM',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text('${therapist.experienceYears} years of experience'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
