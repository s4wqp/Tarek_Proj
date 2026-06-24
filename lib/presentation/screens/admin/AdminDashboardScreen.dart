import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/services/AddSponsorScreen.dart';
import 'package:tarek_proj/presentation/screens/admin/manage_users_screen.dart';
import 'package:tarek_proj/presentation/widgets/custom_widgets.dart';

/// Admin Dashboard — fetches real stats from the API.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String _totalTrips = '—';
  String _activeTrips = '—';
  String _pendingTrips = '—';
  String _totalSponsors = '—';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ws = WebServices();

      // Fetch sponsors count
      List<dynamic>? sponsors;
      try {
        sponsors = await ws.getAllSponsors();
      } catch (_) {}

      // Fetch trip stats
      Map<String, dynamic>? tripStats;
      try {
        tripStats = await ws.getTripStats();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalSponsors = sponsors != null ? '${sponsors.length}' : '—';
          if (tripStats != null) {
            _totalTrips =
                '${tripStats['total_trips'] ?? tripStats['totalTrips'] ?? '—'}';
            _activeTrips =
                '${tripStats['active_trips'] ?? tripStats['activeTrips'] ?? '—'}';
            _pendingTrips =
                '${tripStats['pending_trips'] ?? tripStats['pendingTrips'] ?? '—'}';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load stats: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              } catch (e) {
                debugPrint("Logout error: $e");
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const LoadingOverlay(message: 'Loading dashboard...')
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _loadStats,
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview title
                        const SectionHeader(title: 'Overview Analytics'),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.3,
                          children: [
                            StatCard(
                              title: 'Total Trips',
                              value: _totalTrips,
                              icon: Icons.route,
                              color: AppColors.primary,
                            ),
                            StatCard(
                              title: 'Active Trips',
                              value: _activeTrips,
                              icon: Icons.directions_car,
                              color: AppColors.secondary,
                            ),
                            StatCard(
                              title: 'Pending Trips',
                              value: _pendingTrips,
                              icon: Icons.pending_actions,
                              color: AppColors.error,
                            ),
                            StatCard(
                              title: 'Sponsors',
                              value: _totalSponsors,
                              icon: Icons.business,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        // Quick Actions
                        const SectionHeader(title: 'Quick Actions'),
                        const SizedBox(height: 8),
                        _buildActionCard(
                          context,
                          'Add Business Sponsor',
                          'Create and manage advertising sponsors',
                          Icons.add_business,
                          Colors.purpleAccent,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AddSponsorScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildActionCard(
                          context,
                          'Manage Users',
                          'View, approve, or reject user registrations',
                          Icons.admin_panel_settings,
                          Colors.indigoAccent,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageUsersScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildActionCard(
                          context,
                          'App Settings',
                          'Configure core application behaviors',
                          Icons.settings,
                          Colors.blueGrey,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('App Settings coming soon!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle,
      IconData icon, Color iconColor, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white54, size: 16),
      ),
    );
  }
}
