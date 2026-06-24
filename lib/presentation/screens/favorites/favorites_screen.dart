import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';

/// A simple favorites/saved providers screen.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Sample data — replace with API/local storage.
  final List<_FavProvider> _favorites = [
    _FavProvider(
      name: 'Ahmed Hassan',
      service: 'Car Ride Provider',
      rating: 4.8,
      trips: 124,
      icon: Icons.directions_car,
      color: AppColors.primary,
    ),
    _FavProvider(
      name: 'Sara Mohamed',
      service: 'Home Cleaning',
      rating: 4.9,
      trips: 87,
      icon: Icons.cleaning_services,
      color: AppColors.success,
    ),
    _FavProvider(
      name: 'Dr. Khaled',
      service: 'Nursing Care',
      rating: 5.0,
      trips: 45,
      icon: Icons.local_hospital,
      color: AppColors.error,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: const Text('Saved Providers',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border,
                        size: 48, color: AppColors.error),
                  ),
                  const SizedBox(height: 20),
                  const Text('No saved providers',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap the heart icon on any provider to save them.',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorites.length,
              itemBuilder: (context, i) {
                final fav = _favorites[i];
                return _buildFavoriteTile(fav, i);
              },
            ),
    );
  }

  Widget _buildFavoriteTile(_FavProvider fav, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fav.color.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(fav.icon, color: fav.color, size: 24),
        ),
        title: Text(fav.name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(fav.service,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 16),
                const SizedBox(width: 4),
                Text('${fav.rating}',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.directions_car,
                    color: AppColors.textHint, size: 14),
                const SizedBox(width: 4),
                Text('${fav.trips} trips',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: AppColors.error),
          onPressed: () {
            setState(() => _favorites.removeAt(index));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed from favorites')),
            );
          },
        ),
      ),
    );
  }
}

class _FavProvider {
  final String name;
  final String service;
  final double rating;
  final int trips;
  final IconData icon;
  final Color color;

  _FavProvider({
    required this.name,
    required this.service,
    required this.rating,
    required this.trips,
    required this.icon,
    required this.color,
  });
}
