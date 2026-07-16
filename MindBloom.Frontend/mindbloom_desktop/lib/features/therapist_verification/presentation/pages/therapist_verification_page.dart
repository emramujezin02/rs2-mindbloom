import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/therapist_verification_viewmodel.dart';

class TherapistVerificationPage extends StatefulWidget {
  const TherapistVerificationPage({super.key});

  @override
  State<TherapistVerificationPage> createState() =>
      _TherapistVerificationPageState();
}

class _TherapistVerificationPageState extends State<TherapistVerificationPage> {
  final TherapistVerificationViewModel _viewModel =
      AppInjection.createTherapistVerificationViewModel();

  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _openDetails(int therapistId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistVerificationDetails, arguments: therapistId);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.load(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (value) {
                      _viewModel.searchTherapists(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search pending therapists',
                      hintText: 'Name, email or specialization',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _viewModel.isLoading
                      ? null
                      : () {
                          _viewModel.searchTherapists(_searchController.text);
                        },
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _viewModel.isLoading
                      ? null
                      : () {
                          _searchController.clear();

                          _viewModel.clearSearch();
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildContent()),
        _buildPagination(),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.therapists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.therapists.isEmpty) {
      return Center(child: Text(_viewModel.errorMessage!));
    }

    if (_viewModel.therapists.isEmpty) {
      return const Center(
        child: Text('There are no therapists waiting for verification.'),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _viewModel.therapists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final therapist = _viewModel.therapists[index];

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: CircleAvatar(
              radius: 28,
              child: Text(
                therapist.fullName.isEmpty
                    ? '?'
                    : therapist.fullName[0].toUpperCase(),
              ),
            ),
            title: Text(
              therapist.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${therapist.email}\n'
                '${therapist.specialization} • '
                '${therapist.experienceYears} years experience\n'
                '${therapist.documentCount} documents • '
                'Applied ${formatter.format(therapist.registeredAtUtc.toLocal())}',
              ),
            ),
            isThreeLine: true,
            trailing: ElevatedButton.icon(
              onPressed: () {
                _openDetails(therapist.therapistId);
              },
              icon: const Icon(Icons.visibility),
              label: const Text('Review'),
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _viewModel.totalPages == 0
                ? 'Page 0 of 0'
                : 'Page ${_viewModel.pageNumber} '
                      'of ${_viewModel.totalPages}',
          ),
          const SizedBox(width: 12),
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
}
