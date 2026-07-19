import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/therapist_client_model.dart';
import '../viewmodels/therapist_clients_viewmodel.dart';

class TherapistClientsPage extends StatefulWidget {
  const TherapistClientsPage({super.key});

  @override
  State<TherapistClientsPage> createState() =>
      _TherapistClientsPageState();
}

class _TherapistClientsPageState
    extends State<TherapistClientsPage> {
  late final TherapistClientsViewModel viewModel;

  final TextEditingController searchController =
      TextEditingController();

  final FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    viewModel =
        AppInjection.createTherapistClientsViewModel();

    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadClients();
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    viewModel.removeListener(
      _onViewModelChanged,
    );

    viewModel.dispose();

    searchController.dispose();
    searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> _openClientDetails(
    TherapistClientModel client,
  ) async {
    await Navigator.of(context).pushNamed(
      AppRouter.therapistClientDetails,
      arguments: client.clientId,
    );

    if (mounted) {
      await viewModel.refresh();
    }
  }

  void _onSearchChanged(String value) {
    viewModel.onSearchChanged(value);
  }

  Future<void> _submitSearch() async {
    searchFocusNode.unfocus();

    await viewModel.submitSearch();
  }

  Future<void> _clearSearch() async {
    searchController.clear();
    searchFocusNode.unfocus();

    await viewModel.clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Clients',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                viewModel.isLoading
                    ? null
                    : viewModel.refresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading &&
        viewModel.totalClients == 0) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(
            child:
                CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (viewModel.errorMessage != null &&
        viewModel.totalClients == 0) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          _ErrorState(
            message:
                viewModel.errorMessage!,
            onRetry:
                viewModel.refresh,
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
                  maxWidth: 1000,
                ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _HeaderSection(
                  totalClients:
                      viewModel.totalClients,
                ),
                const SizedBox(height: 22),
                _SearchSection(
                  controller:
                      searchController,
                  focusNode:
                      searchFocusNode,
                  isLoading:
                      viewModel.isLoading,
                  hasSearch:
                      viewModel.hasSearch,
                  onChanged:
                      _onSearchChanged,
                  onSubmitted: (_) {
                    _submitSearch();
                  },
                  onSearch:
                      _submitSearch,
                  onClear:
                      _clearSearch,
                ),
                const SizedBox(height: 22),
                _buildResultsHeader(),
                const SizedBox(height: 14),
                if (viewModel.clients.isEmpty)
                  _EmptyState(
                    hasSearch:
                        viewModel.hasSearch,
                    onClearSearch:
                        _clearSearch,
                  )
                else
                  ...viewModel.clients.map(
                    (client) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                              bottom: 15,
                            ),
                        child: _ClientCard(
                          client: client,
                          onTap: () {
                            _openClientDetails(
                              client,
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader() {
    final clientCount =
        viewModel.totalClients;

    final title =
        viewModel.hasSearch
            ? 'Search results'
            : 'Clients';

    final countText =
        clientCount == 1
            ? '1 client'
            : '$clientCount clients';

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color:
                  Color(0xFF40334D),
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
          decoration: BoxDecoration(
            color:
                const Color(0xFFEDE5FA),
            borderRadius:
                BorderRadius.circular(30),
          ),
          child: Text(
            countText,
            style: const TextStyle(
              color:
                  Color(0xFF72559A),
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final int totalClients;

  const _HeaderSection({
    required this.totalClients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 650;

          if (isWide) {
            return Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildTextContent(),
                ),
                const SizedBox(width: 18),
                _ClientCountBadge(
                  totalClients: totalClients,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextContent(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ClientCountBadge(
                totalClients: totalClients,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE5FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.people_outline,
        color: Color(0xFF72559A),
        size: 30,
      ),
    );
  }

  Widget _buildTextContent() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Therapist Clients',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'View clients who have booked appointments with you and access their appointment history.',
          style: TextStyle(
            color: Color(0xFF756D79),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ClientCountBadge extends StatelessWidget {
  final int totalClients;

  const _ClientCountBadge({
    required this.totalClients,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        totalClients == 1
            ? '1 client'
            : '$totalClients clients';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEFA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            color: Color(0xFF72559A),
            size: 20,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF72559A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final bool hasSearch;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchSection({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.hasSearch,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 620;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  child: _buildTextField(),
                ),
                const SizedBox(width: 12),
                _buildSearchButton(),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(),
              const SizedBox(height: 12),
              _buildSearchButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !isLoading,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        prefixIcon: const Icon(
          Icons.search,
        ),
        suffixIcon:
            hasSearch
                ? IconButton(
                  tooltip: 'Clear search',
                  onPressed:
                      isLoading
                          ? null
                          : onClear,
                  icon: const Icon(
                    Icons.close,
                  ),
                )
                : null,
        filled: true,
        fillColor: const Color(0xFFFAF8FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE0D5EA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE0D5EA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFF72559A),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return FilledButton.icon(
      onPressed:
          isLoading
              ? null
              : onSearch,
      icon:
          isLoading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
              : const Icon(
                Icons.search,
              ),
      label: const Text(
        'Search',
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
      ),
    );
  }
}
class _ClientCard extends StatelessWidget {
  final TherapistClientModel client;
  final VoidCallback onTap;

  const _ClientCard({
    required this.client,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClientAvatar(
                    fullName: client.fullName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.fullName,
                          style: const TextStyle(
                            color: Color(0xFF40334D),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          client.email,
                          style: const TextStyle(
                            color: Color(0xFF766F7A),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF8063A4),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                children: [
                  _ClientStatistic(
                    icon: Icons.calendar_month_outlined,
                    label: 'Appointments',
                    value: client.totalAppointments.toString(),
                  ),
                  _ClientStatistic(
                    icon: Icons.task_alt_outlined,
                    label: 'Completed',
                    value: client.completedAppointments.toString(),
                  ),
                ],
              ),
              if (client.lastAppointmentUtc != null) ...[
                const SizedBox(height: 17),
                _InformationRow(
                  icon: Icons.history_outlined,
                  value:
                      'Last appointment: '
                      '${_formatDate(client.lastAppointmentUtc!.toLocal())}',
                ),
              ],
              if (client.nextAppointmentUtc != null) ...[
                const SizedBox(height: 10),
                _InformationRow(
                  icon: Icons.upcoming_outlined,
                  value:
                      'Next appointment: '
                      '${_formatDate(client.nextAppointmentUtc!.toLocal())} '
                      'at ${_formatTime(client.nextAppointmentUtc!.toLocal())}',
                ),
              ],
              const SizedBox(height: 19),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.visibility_outlined,
                  ),
                  label: const Text(
                    'View details',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ClientAvatar extends StatelessWidget {
  final String fullName;

  const _ClientAvatar({
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(fullName);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE5FA),
        borderRadius: BorderRadius.circular(17),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF72559A),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _getInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _ClientStatistic extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ClientStatistic({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 145,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE8DFEF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF8063A4),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF40334D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF756D79),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InformationRow({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF8063A4),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF625B68),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.hasSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 55,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5DBEF),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 66,
            color: Color(0xFF8063A4),
          ),
          const SizedBox(height: 18),
          Text(
            hasSearch
                ? 'No clients found'
                : 'No clients yet',
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? 'Try a different search term or clear the current search.'
                : 'Clients will appear here after they schedule an appointment with you.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF756D79),
              height: 1.4,
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear),
              label: const Text(
                'Clear search',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE5DBEF),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 58,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 18),
            const Text(
              'Clients could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF40334D),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF756D79),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Try again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}