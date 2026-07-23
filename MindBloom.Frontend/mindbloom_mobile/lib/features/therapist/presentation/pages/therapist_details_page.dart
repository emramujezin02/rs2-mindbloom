import 'package:flutter/material.dart';
import '../../../appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/therapist_map_data.dart';
import '../viewmodels/therapist_details_viewmodel.dart';
import '../widgets/therapist_location_map.dart';
import '../widgets/therapist_profile_image.dart';
import '../widgets/therapist_session_modes.dart';
import '../../../appointment/presentation/pages/appointment_create_page.dart';
import '../../../appointment/presentation/widgets/available_slots_preview.dart';
import '../../../../core/widgets/public_footer.dart';

class TherapistDetailsPage extends StatefulWidget {
  final int therapistId;

  const TherapistDetailsPage({super.key, required this.therapistId});

  @override
  State<TherapistDetailsPage> createState() => _TherapistDetailsPageState();
}

class _TherapistDetailsPageState extends State<TherapistDetailsPage> {
  final TherapistDetailsViewModel _viewModel =
      AppInjection.createTherapistDetailsViewModel();
  final AppointmentCreateViewModel _appointmentPreviewViewModel =
      AppInjection.createAppointmentViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _appointmentPreviewViewModel.addListener(_onViewModelChanged);

    _viewModel.loadTherapist(widget.therapistId);

    _appointmentPreviewViewModel.loadNextAvailableSlots(
      therapistId: widget.therapistId,
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _appointmentPreviewViewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();
    _appointmentPreviewViewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() async {
    await Future.wait([
      _viewModel.loadTherapist(widget.therapistId),
      _appointmentPreviewViewModel.loadNextAvailableSlots(
        therapistId: widget.therapistId,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist details'),
        actions: [
          IconButton(
            onPressed: _viewModel.isChangingFavorite
                ? null
                : () async {
                    final wasFavorite = _viewModel.isFavorite;

                    final success = await _viewModel.toggleFavorite();

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
            tooltip: _viewModel.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            icon: _viewModel.isChangingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _viewModel.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.therapist == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.therapist == null) {
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final therapist = _viewModel.therapist;

    if (therapist == null) {
      return const Center(child: Text('Therapist could not be loaded.'));
    }

    final therapistSummary = therapist.toTherapistModel();

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TherapistProfileImage(
                  fullName: therapist.fullName,
                  profileImageUrl: therapist.profileImageUrl,
                  radius: 54,
                ),

                const SizedBox(height: 20),

                Text(
                  therapist.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  therapist.specialization,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.star,
                          label: 'Rating',
                          value:
                              '${therapist.averageRating.toStringAsFixed(1)} '
                              '(${therapist.totalReviews} reviews)',
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.work,
                          label: 'Experience',
                          value: '${therapist.experienceYears} years',
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.payments,
                          label: 'Price',
                          value:
                              '${therapist.hourlyRate.toStringAsFixed(2)} KM',
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.email,
                          label: 'Email',
                          value: therapist.email,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Location and session type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.public,
                          label: 'Country',
                          value: therapist.country.trim().isEmpty
                              ? 'Not specified'
                              : therapist.country,
                        ),

                        const Divider(),

                        _InfoRow(
                          icon: Icons.location_city,
                          label: 'City',
                          value: therapist.city.trim().isEmpty
                              ? 'Not specified'
                              : therapist.city,
                        ),

                        if (therapist.offersInPerson) ...[
                          const Divider(),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Address',
                            value: therapist.address.trim().isEmpty
                                ? 'Not specified'
                                : therapist.address,
                          ),
                        ],

                        const Divider(),

                        const Text(
                          'Available session types',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 10),

                        TherapistSessionModes(
                          offersOnline: therapist.offersOnline,
                          offersInPerson: therapist.offersInPerson,
                        ),
                      ],
                    ),
                  ),
                ),

                if (therapist.offersInPerson) ...[
                  const SizedBox(height: 20),

                  const Text(
                    'Therapist location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  TherapistLocationMap(
                    mapData: TherapistMapData(
                      therapistName: therapist.fullName,
                      address: therapist.formattedAddress,
                      latitude: therapist.latitude ?? 0,
                      longitude: therapist.longitude ?? 0,
                    ),
                    height: 250,
                    interactive: true,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          therapist.formattedAddress,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                const Text(
                  'Biography',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  therapist.biography.trim().isEmpty
                      ? 'No biography added.'
                      : therapist.biography,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Regular availability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                if (therapist.availabilities.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'The therapist has not published regular availability.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: therapist.availabilities
                            .map(
                              (availability) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        availability.dayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${availability.formattedStartTime}'
                                      ' – '
                                      '${availability.formattedEndTime}',
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                const Text(
                  'Next available appointments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                AvailableSlotsPreview(
                  isLoading: _appointmentPreviewViewModel.isLoadingPreview,
                  groupedSlots:
                      _appointmentPreviewViewModel.groupedPreviewSlots,
                  onBookSlot: (slot) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentCreatePage(
                          therapist: therapistSummary,
                          initialSlot: slot,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRouter.appointmentCreate,
                      arguments: therapistSummary,
                    );
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Book appointment'),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRouter.purchaseMembership,
                      arguments: therapistSummary,
                    );
                  },
                  icon: const Icon(Icons.card_membership),
                  label: const Text('Buy membership package'),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRouter.therapistReviews,
                      arguments: therapist.id,
                    );
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('View reviews'),
                ),
              ],
            ),
          ),
          const PublicFooter(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
