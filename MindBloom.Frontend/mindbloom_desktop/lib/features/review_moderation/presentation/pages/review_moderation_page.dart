import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/features/review_moderation/presentation/viewmodels/review_moderation_viremodel.dart';

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

  int? _selectedRating;

  String _selectedReply = 'all';

  String _selectedStatus = 'active';

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

  bool? _deletedFilter() {
    switch (_selectedStatus) {
      case 'active':
        return false;

      case 'deleted':
        return true;

      default:
        return null;
    }
  }

  Future<void> _applyFilters() {
    return _viewModel.applyFilters(
      search: _searchController.text,
      rating: _selectedRating,
      hasReply: _replyFilter(),
      isDeleted: _deletedFilter(),
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedRating = null;
      _selectedReply = 'all';
      _selectedStatus = 'active';
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
            final compact = constraints.maxWidth < 1000;

            final search = TextField(
              controller: _searchController,
              onSubmitted: (_) {
                _applyFilters();
              },
              decoration: const InputDecoration(
                labelText: 'Search reviews',
                hintText: 'Client, therapist, email or comment',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            );

            final rating = DropdownButtonFormField<int>(
              initialValue: _selectedRating,
              decoration: const InputDecoration(
                labelText: 'Rating',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 star')),
                DropdownMenuItem(value: 2, child: Text('2 stars')),
                DropdownMenuItem(value: 3, child: Text('3 stars')),
                DropdownMenuItem(value: 4, child: Text('4 stars')),
                DropdownMenuItem(value: 5, child: Text('5 stars')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRating = value;
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
              onChanged: (value) {
                setState(() {
                  _selectedReply = value ?? 'all';
                });
              },
            );

            final status = DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'deleted', child: Text('Removed')),
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'active';
                });
              },
            );

            final actions = Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _applyFilters,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
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
              return Column(
                children: [
                  search,
                  const SizedBox(height: 12),
                  rating,
                  const SizedBox(height: 12),
                  reply,
                  const SizedBox(height: 12),
                  status,
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 12),
                Expanded(child: rating),
                const SizedBox(width: 12),
                Expanded(child: reply),
                const SizedBox(width: 12),
                Expanded(child: status),
                const SizedBox(width: 12),
                SizedBox(width: 260, child: actions),
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
      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                                '${review.clientName} → ${review.therapistName}',
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
                              label: Text(
                                review.hasTherapistReply
                                    ? 'Therapist replied'
                                    : 'No therapist reply',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(
                                review.isDeleted ? 'Removed' : 'Active',
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
      child: Text(
        _viewModel.errorMessage!,
        style: const TextStyle(color: Colors.red),
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
