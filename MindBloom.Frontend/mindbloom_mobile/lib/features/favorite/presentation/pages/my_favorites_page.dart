import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/favorite_model.dart';
import '../viewmodels/favorite_list_viewmodel.dart';

class MyFavoritesPage extends StatefulWidget {
  const MyFavoritesPage({super.key});

  @override
  State<MyFavoritesPage> createState() => _MyFavoritesPageState();
}

class _MyFavoritesPageState extends State<MyFavoritesPage> {
  final FavoriteListViewModel _viewModel =
      AppInjection.createFavoriteListViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadFavorites();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() {
    return _viewModel.loadFavorites();
  }

  Future<void> _removeFavorite(FavoriteModel favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove favorite'),
          content: Text(
            'Remove ${favorite.therapistName} from your favorites?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.removeFavorite(favorite.therapistId);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist removed from favorites.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My favorites'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.favorites.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading favorite therapists...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.favorites.isEmpty) {
      return AppErrorWidget(
        title: 'Favorites could not be loaded',
        error: _viewModel.errorMessage,
        onRetry: _refresh,
      );
    }

    if (_viewModel.favorites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No favorite therapists',
          message: 'You have not added any favorite therapists yet.',
          icon: Icons.favorite_border,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount:
            _viewModel.favorites.length +
            (_viewModel.errorMessage != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_viewModel.errorMessage != null && index == 0) {
            return AppInlineError(
              title: 'Favorites could not be refreshed',
              error: _viewModel.errorMessage,
              onRetry: _refresh,
            );
          }

          final favoriteIndex =
              index - (_viewModel.errorMessage != null ? 1 : 0);

          final favorite = _viewModel.favorites[favoriteIndex];

          return Card(
            child: ListTile(
              onTap: () async {
                await Navigator.of(context).pushNamed(
                  AppRouter.therapistDetails,
                  arguments: favorite.therapistId,
                );

                if (!mounted) {
                  return;
                }

                await _viewModel.loadFavorites();
              },
              leading: CircleAvatar(
                child: Text(
                  favorite.therapistName.isNotEmpty
                      ? favorite.therapistName[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(
                favorite.therapistName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(favorite.specialization),
              trailing: IconButton(
                onPressed: () {
                  _removeFavorite(favorite);
                },
                tooltip: 'Remove from favorites',
                icon: const Icon(Icons.favorite),
              ),
            ),
          );
        },
      ),
    );
  }
}
