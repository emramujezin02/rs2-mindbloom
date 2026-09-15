import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/public_footer.dart';
import '../../../appointment/presentation/pages/appointment_create_page.dart';
import '../../../appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import '../../../appointment/presentation/widgets/available_slots_preview.dart';
import '../../data/models/therapist_details_model.dart';
import '../../data/models/therapist_map_data.dart';
import '../../data/models/therapist_model.dart';
import '../viewmodels/therapist_details_viewmodel.dart';
import '../widgets/therapist_location_map.dart';
import '../widgets/therapist_profile_image.dart';
import '../widgets/therapist_session_modes.dart';

const _detailsBackground = Color(0xFFFCFAFF);
const _detailsLavender = Color(0xFFF5EFFC);
const _detailsSurface = Color(0xFFFFFFFF);
const _detailsTint = Color(0xFFFAF7FE);
const _detailsBorder = Color(0xFFE8DEF3);
const _detailsPrimary = Color(0xFF6D4F91);
const _detailsText = Color(0xFF3E3152);
const _detailsBody = Color(0xFF625B6B);
const _detailsRadius = 20.0;

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

  Future<void> _openBookingPage({
    required TherapistModel therapistSummary,
    DateTime? initialSlot,
  }) async {
    final wasBooked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentCreatePage(
          therapist: therapistSummary,
          initialSlot: initialSlot,
          returnResultOnSuccess: true,
        ),
      ),
    );

    if (!mounted || wasBooked != true) {
      return;
    }

    await _appointmentPreviewViewModel.loadNextAvailableSlots(
      therapistId: widget.therapistId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _detailsBackground,
      appBar: AppBar(
        title: const Text('Therapist details'),
        backgroundColor: _detailsBackground,
        foregroundColor: _detailsText,
        surfaceTintColor: Colors.transparent,
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
      return const AppLoadingWidget.skeleton(
        message: 'Loading therapist details...',
        skeletonItemCount: 6,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.therapist == null) {
      return AppErrorWidget(
        title: 'Therapist could not be loaded',
        error: _viewModel.errorMessage,
        fallbackMessage: 'Therapist could not be loaded.',
        onRetry: _reload,
      );
    }

    final therapist = _viewModel.therapist;

    if (therapist == null) {
      return const AppEmptyStateWidget(
        title: 'Therapist unavailable',
        message: 'Therapist could not be loaded.',
        icon: Icons.psychology_outlined,
      );
    }

    final therapistSummary = therapist.toTherapistModel();

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          if (_viewModel.errorMessage != null)
            AppInlineError(
              title: 'Therapist could not be refreshed',
              error: _viewModel.errorMessage,
              fallbackMessage: 'The current therapist details are still shown.',
              onRetry: _reload,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          if (_viewModel.favoriteErrorMessage != null)
            AppInlineError(
              title: 'Favorite could not be updated',
              error: _viewModel.favoriteErrorMessage,
              fallbackMessage: 'Favorite could not be updated.',
              margin: const EdgeInsets.only(bottom: 12),
            ),
          _TherapistIdentitySection(therapist: therapist),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'About therapist',
            icon: Icons.person_outline,
            child: Text(
              therapist.displayBiography,
              style: const TextStyle(
                color: _detailsText,
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Approaches and languages',
            icon: Icons.psychology_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TagGroup(
                  values: therapist.therapyApproaches,
                  emptyText: 'No therapy approaches specified.',
                ),
                const SizedBox(height: 14),
                const _SmallSectionTitle('Languages'),
                const SizedBox(height: 8),
                _TagGroup(
                  values: therapist.languages,
                  emptyText: 'No languages specified.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Session information',
            icon: Icons.event_available_outlined,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: therapist.displayRating,
                  iconColor: const Color(0xFFF2B84B),
                ),
                const _SoftDivider(),
                _InfoRow(
                  icon: Icons.work_outline,
                  label: 'Experience',
                  value: therapist.displayExperience,
                ),
                const _SoftDivider(),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Price per session',
                  value: therapist.displayPrice,
                ),
                const _SoftDivider(),
                _InfoRow(
                  icon: Icons.video_call_outlined,
                  label: 'Session mode',
                  value: therapist.sessionModeLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LocationSection(therapist: therapist),
          const SizedBox(height: 16),
          _AvailabilitySection(therapist: therapist),
          const SizedBox(height: 16),
          _DetailsSection(
            title: 'Next available appointments',
            icon: Icons.calendar_month_outlined,
            child: AvailableSlotsPreview(
              isLoading: _appointmentPreviewViewModel.isLoadingPreview,
              groupedSlots: _appointmentPreviewViewModel.groupedPreviewSlots,
              onBookSlot: (slot) {
                _openBookingPage(
                  therapistSummary: therapistSummary,
                  initialSlot: slot,
                );
              },
              onShowAllSlots: () {
                _openBookingPage(therapistSummary: therapistSummary);
              },
            ),
          ),
          const SizedBox(height: 16),
          _ActionSection(
            therapist: therapist,
            onBook: () {
              _openBookingPage(therapistSummary: therapistSummary);
            },
            onChat: therapist.canOpenChat
                ? () {
                    Navigator.of(context).pushNamed(
                      AppRouter.chatDetails,
                      arguments: therapist.chatAppointmentId!,
                    );
                  }
                : null,
            onMembership: () {
              Navigator.of(context).pushNamed(
                AppRouter.purchaseMembership,
                arguments: therapistSummary,
              );
            },
            onReviews: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.therapistReviews, arguments: therapist.id);
            },
          ),
          const SizedBox(height: 20),
          const PublicFooter(),
        ],
      ),
    );
  }
}

class _TherapistIdentitySection extends StatelessWidget {
  final TherapistDetailsModel therapist;

  const _TherapistIdentitySection({required this.therapist});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _detailsLavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _detailsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TherapistProfileImage(
            fullName: therapist.displayName,
            profileImageUrl: therapist.profileImageUrl,
            radius: 58,
          ),
          const SizedBox(height: 16),
          Text(
            therapist.displayName,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _detailsText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            therapist.displaySpecialization,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _detailsPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.star_rounded,
                label: therapist.displayRating,
                iconColor: const Color(0xFFF2B84B),
              ),
              _MetaPill(
                icon: Icons.location_on_outlined,
                label: therapist.formattedLocation,
              ),
              _MetaPill(
                icon: Icons.payments_outlined,
                label: therapist.displayPrice,
              ),
              _MetaPill(
                icon: Icons.verified_outlined,
                label: therapist.displayVerificationStatus,
                iconColor: const Color(0xFF2E7D4F),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _detailsSurface,
        borderRadius: BorderRadius.circular(_detailsRadius),
        border: Border.all(color: _detailsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _detailsPrimary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _detailsText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  final TherapistDetailsModel therapist;

  const _LocationSection({required this.therapist});

  @override
  Widget build(BuildContext context) {
    return _DetailsSection(
      title: 'Location and session type',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: therapist.formattedLocation,
          ),
          if (therapist.offersInPerson) ...[
            const _SoftDivider(),
            _InfoRow(
              icon: Icons.home_work_outlined,
              label: 'Address',
              value: therapist.formattedAddress,
            ),
          ],
          const _SoftDivider(),
          const _SmallSectionTitle('Available session types'),
          const SizedBox(height: 10),
          TherapistSessionModes(
            offersOnline: therapist.offersOnline,
            offersInPerson: therapist.offersInPerson,
          ),
          if (therapist.offersInPerson && therapist.hasValidCoordinates) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: TherapistLocationMap(
                mapData: TherapistMapData(
                  therapistName: therapist.displayName,
                  address: therapist.formattedAddress,
                  latitude: therapist.latitude!,
                  longitude: therapist.longitude!,
                ),
                height: 230,
                interactive: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  final TherapistDetailsModel therapist;

  const _AvailabilitySection({required this.therapist});

  @override
  Widget build(BuildContext context) {
    return _DetailsSection(
      title: 'Regular availability',
      icon: Icons.schedule_outlined,
      child: therapist.availabilities.isEmpty
          ? const AppInlineEmptyState(
              message: 'The therapist has not published regular availability.',
              icon: Icons.event_busy_outlined,
            )
          : Column(
              children: therapist.availabilities
                  .map(
                    (availability) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 20,
                            color: _detailsPrimary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              availability.dayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _detailsText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              '${availability.formattedStartTime}'
                              ' - '
                              '${availability.formattedEndTime}',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _detailsBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final TherapistDetailsModel therapist;
  final VoidCallback onBook;
  final VoidCallback? onChat;
  final VoidCallback onMembership;
  final VoidCallback onReviews;

  const _ActionSection({
    required this.therapist,
    required this.onBook,
    required this.onChat,
    required this.onMembership,
    required this.onReviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _detailsTint,
        borderRadius: BorderRadius.circular(_detailsRadius),
        border: Border.all(color: _detailsBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onBook,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Book appointment'),
          ),
          if (onChat != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onChat,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Contact therapist'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onMembership,
            icon: const Icon(Icons.card_membership),
            label: const Text('Buy membership package'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onReviews,
            icon: const Icon(Icons.star_outline),
            label: Text(
              therapist.totalReviews > 0
                  ? 'View reviews (${therapist.totalReviews})'
                  : 'View reviews',
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallSectionTitle extends StatelessWidget {
  final String value;

  const _SmallSectionTitle(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(color: _detailsText, fontWeight: FontWeight.w800),
    );
  }
}

class _TagGroup extends StatelessWidget {
  final List<String> values;
  final String emptyText;

  const _TagGroup({required this.values, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return AppInlineEmptyState(message: emptyText, icon: Icons.spa_outlined);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map((value) => _MetaPill(icon: Icons.spa_outlined, label: value))
          .toList(),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _MetaPill({
    required this.icon,
    required this.label,
    this.iconColor = _detailsPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _detailsSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _detailsBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailsBody,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = _detailsPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _detailsText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: _detailsBody, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: _detailsBorder),
    );
  }
}
