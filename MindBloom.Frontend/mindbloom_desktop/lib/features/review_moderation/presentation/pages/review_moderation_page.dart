import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/features/review_moderation/presentation/viewmodels/review_moderation_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),

        if (_viewModel.errorMessage != null) _buildError(),

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
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.reviews.isEmpty) {
      return const Center(
        child: Text('No reviews match the selected filters.'),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _viewModel.reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = _viewModel.reviews[index];

        return Card(
          child: InkWell(
            onTap: () {
              _openDetails(review.id);
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Text(review.rating.toString())),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${review.clientName} → '
                                '${review.therapistName}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            _RatingStars(rating: review.rating),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          review.comment,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              formatter.format(review.createdAtUtc.toLocal()),
                            ),

                            Chip(
                              avatar: const Icon(Icons.person, size: 17),
                              label: Text('Therapist #${review.therapistId}'),
                              visualDensity: VisualDensity.compact,
                            ),

                            _ModerationStatusChip(
                              status: review.moderationStatus,
                            ),

                            Chip(
                              label: Text(
                                review.hasTherapistReply
                                    ? 'Therapist replied'
                                    : 'No therapist reply',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Text('${_viewModel.totalCount} reviews'),

          const Spacer(),

          const Text('Rows per page:'),

          const SizedBox(width: 8),

          DropdownButton<int>(
            value: _viewModel.pageSize,
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      _viewModel.changePageSize(value);
                    }
                  },
          ),

          const SizedBox(width: 18),

          Text(
            _viewModel.totalPages == 0
                ? 'Page 0 of 0'
                : 'Page ${_viewModel.pageNumber} '
                      'of ${_viewModel.totalPages}',
          ),

          IconButton(
            onPressed: _viewModel.hasPreviousPage && !_viewModel.isLoading
                ? _viewModel.previousPage
                : null,
            icon: const Icon(Icons.chevron_left),
          ),

          IconButton(
            onPressed: _viewModel.hasNextPage && !_viewModel.isLoading
                ? _viewModel.nextPage
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _viewModel.errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
