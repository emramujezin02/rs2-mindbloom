import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.loadFavorites();
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

    if (confirmed != true) {
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
      appBar: AppBar(title: const Text('My favorites')),
      body: _buildBody(),
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
                onPressed: _viewModel.loadFavorites,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You have not added any favorite therapists yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _viewModel.favorites.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final favorite = _viewModel.favorites[index];

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
