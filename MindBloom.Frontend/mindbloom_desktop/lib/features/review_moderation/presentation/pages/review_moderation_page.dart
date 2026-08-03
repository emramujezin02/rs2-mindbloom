import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';
import 'package:mindbloom_desktop/features/review_moderation/presentation/viewmodels/review_moderation_viewmodel.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';

class ReviewModerationPage extends StatefulWidget {
  const ReviewModerationPage({super.key});

  @override
  State<ReviewModerationPage> createState() => _ReviewModerationPageState();
}

class _ReviewModerationPageState extends State<ReviewModerationPage> {
  final ReviewModerationViewModel _viewModel =
      AppInjection.createReviewModerationViewModel();

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _therapistIdController = TextEditingController();

  int? _selectedRating;

  int? _selectedStatus;

  String _selectedReply = 'all';

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);

    _viewModel.dispose();

    _searchController.dispose();

    _therapistIdController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool? _replyFilter() {
    switch (_selectedReply) {
      case 'replied':
        return true;

      case 'notReplied':
        return false;

      default:
        return null;
    }
  }

  int? _therapistIdFilter() {
    final value = _therapistIdController.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return int.tryParse(value);
  }

  Future<void> _applyFilters() async {
    final therapistText = _therapistIdController.text.trim();

    if (therapistText.isNotEmpty && int.tryParse(therapistText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist ID must be a valid number.')),
      );

      return;
    }

    await _viewModel.applyFilters(
      search: _searchController.text,
      rating: _selectedRating,
      therapistId: _therapistIdFilter(),
      status: _selectedStatus,
      hasReply: _replyFilter(),
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    _therapistIdController.clear();

    setState(() {
      _selectedRating = null;
      _selectedStatus = null;
      _selectedReply = 'all';
    });

    await _viewModel.clearFilters();
  }

  Future<void> _openDetails(int reviewId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.reviewModerationDetails, arguments: reviewId);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.load();
    }
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _therapistIdController.text.trim().isNotEmpty ||
        _selectedRating != null ||
        _selectedStatus != null ||
        _selectedReply != 'all';
  }

  String _reviewStatusLabel(int value) {
    switch (value) {
      case 1:
        return 'Na čekanju';
      case 2:
        return 'Odobrena';
      case 3:
        return 'Odbijena';
      case 4:
        return 'Sakrivena';
      default:
        return value.toString();
    }
  }

  Widget _buildActiveFilters() {
    if (!_hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_searchController.text.trim().isNotEmpty)
            Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
          if (_therapistIdController.text.trim().isNotEmpty)
            Chip(
              label: Text('Terapeut ID: ${_therapistIdController.text.trim()}'),
            ),
          if (_selectedRating != null)
            Chip(label: Text('Ocjena: $_selectedRating')),
          if (_selectedStatus != null)
            Chip(
              label: Text('Status: ${_reviewStatusLabel(_selectedStatus!)}'),
            ),
          if (_selectedReply != 'all')
            Chip(
              label: Text(
                _selectedReply == 'replied'
                    ? 'Odgovor terapeuta: Da'
                    : 'Odgovor terapeuta: Ne',
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Resetuj filtere'),
            onPressed: _viewModel.isLoading ? null : _clearFilters,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),

        _buildActiveFilters(),

        if (_viewModel.errorMessage != null && _viewModel.reviews.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: AppErrorBanner(
              message: _viewModel.errorMessage!,
              onDismiss: _viewModel.clearError,
            ),
          ),

        Expanded(child: _buildBody()),

        if (_viewModel.reviews.isNotEmpty) _buildPagination(),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1150;

            final search = TextField(
              controller: _searchController,
              onChanged: _viewModel.updateSearch,
              enabled: !_viewModel.isLoading,
              onSubmitted: (_) {
                _applyFilters();
              },
              decoration: const InputDecoration(
                labelText: 'Search reviews',
                hintText: 'Client name, email, therapist or comment',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            );

            final therapist = TextField(
              controller: _therapistIdController,
              enabled: !_viewModel.isLoading,
              keyboardType: TextInputType.number,
              onSubmitted: (_) {
                _applyFilters();
              },
              decoration: const InputDecoration(
                labelText: 'Therapist ID',
                prefixIcon: Icon(Icons.person_search),
                border: OutlineInputBorder(),
              ),
            );

            final rating = DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_selectedRating),
              initialValue: _selectedRating,
              decoration: const InputDecoration(
                labelText: 'Rating',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('All ratings')),
                DropdownMenuItem<int?>(value: 1, child: Text('1 star')),
                DropdownMenuItem<int?>(value: 2, child: Text('2 stars')),
                DropdownMenuItem<int?>(value: 3, child: Text('3 stars')),
                DropdownMenuItem<int?>(value: 4, child: Text('4 stars')),
                DropdownMenuItem<int?>(value: 5, child: Text('5 stars')),
              ],
              onChanged: _viewModel.isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRating = value;
                      });
                    },
            );

            final status = DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_selectedStatus),
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Moderation status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                DropdownMenuItem<int?>(value: 1, child: Text('Pending')),
                DropdownMenuItem<int?>(value: 2, child: Text('Approved')),
                DropdownMenuItem<int?>(value: 3, child: Text('Rejected')),
                DropdownMenuItem<int?>(value: 4, child: Text('Hidden')),
              ],
              onChanged: _viewModel.isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
            );

            final reply = DropdownButtonFormField<String>(
              initialValue: _selectedReply,
              decoration: const InputDecoration(
                labelText: 'Therapist reply',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All reviews')),
                DropdownMenuItem(value: 'replied', child: Text('Has reply')),
                DropdownMenuItem(value: 'notReplied', child: Text('No reply')),
              ],
              onChanged: _viewModel.isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedReply = value ?? 'all';
                      });
                    },
            );

            final actions = Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _applyFilters,
                    icon: const Icon(Icons.search),
                    label: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            );

            if (compact) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 320, child: search),
                  SizedBox(width: 180, child: therapist),
                  SizedBox(width: 180, child: rating),
                  SizedBox(width: 220, child: status),
                  SizedBox(width: 200, child: reply),
                  SizedBox(width: 260, child: actions),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 12),
                Expanded(child: therapist),
                const SizedBox(width: 12),
                Expanded(child: rating),
                const SizedBox(width: 12),
                Expanded(child: status),
                const SizedBox(width: 12),
                Expanded(child: reply),
                const SizedBox(width: 12),
                SizedBox(width: 250, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.reviews.isEmpty) {
      return const AdminTableLoadingState(message: 'Učitavanje recenzija...');
    }

    if (_viewModel.errorMessage != null && _viewModel.reviews.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.load();
        },
      );
    }

    if (_viewModel.reviews.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.reviews_outlined,
        title: 'Nema recenzija',
        message: 'Nijedna recenzija ne odgovara odabranim filterima.',
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AdminTableContainer(
        minimumWidth: 1450,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Klijent')),
            DataColumn(label: Text('Terapeut')),
            DataColumn(label: Text('Ocjena')),
            DataColumn(label: Text('Komentar')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Odgovor')),
            DataColumn(label: Text('Kreirano')),
            DataColumn(label: Text('Akcije')),
          ],
          rows: _viewModel.reviews.map((review) {
            return DataRow(
              cells: [
                DataCell(Text('#${review.id}')),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Text(
                      review.clientName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Text(
                      review.therapistName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_RatingStars(rating: review.rating)),
                DataCell(
                  SizedBox(
                    width: 280,
                    child: Tooltip(
                      message: review.comment,
                      child: Text(
                        review.comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  _ModerationStatusChip(status: review.moderationStatus),
                ),
                DataCell(
                  Icon(
                    review.hasTherapistReply
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                  ),
                ),
                DataCell(Text(formatter.format(review.createdAtUtc.toLocal()))),
                DataCell(
                  AdminTableActionMenu<String>(
                    enabled: !_viewModel.isLoading,
                    actions: const [
                      AdminTableAction<String>(
                        value: 'details',
                        label: 'Detalji',
                        icon: Icons.visibility_outlined,
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'details') {
                        _openDetails(review.id);
                      }
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: AdminTablePagination(
        pageNumber: _viewModel.pageNumber,
        pageSize: _viewModel.pageSize,
        totalCount: _viewModel.totalCount,
        totalPages: _viewModel.totalPages,
        isLoading: _viewModel.isLoading,
        onPreviousPage: _viewModel.hasPreviousPage
            ? _viewModel.previousPage
            : null,
        onNextPage: _viewModel.hasNextPage ? _viewModel.nextPage : null,
        onPageSizeChanged: _viewModel.changePageSize,
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) =>
            Icon(index < rating ? Icons.star : Icons.star_border, size: 19),
      ),
    );
  }
}

class _ModerationStatusChip extends StatelessWidget {
  final String status;

  const _ModerationStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    IconData icon;

    switch (normalized) {
      case 'approved':
        icon = Icons.check_circle;
        break;

      case 'rejected':
        icon = Icons.cancel;
        break;

      case 'hidden':
        icon = Icons.visibility_off;
        break;

      default:
        icon = Icons.hourglass_top;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(status),
      visualDensity: VisualDensity.compact,
    );
  }
}
