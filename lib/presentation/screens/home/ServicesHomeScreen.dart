import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/profile/ProfileScreen.dart';
import 'package:tarek_proj/presentation/screens/notifications/notifications_screen.dart';
import 'package:tarek_proj/presentation/screens/favorites/favorites_screen.dart';
import 'package:tarek_proj/presentation/screens/points/points_transaction_screen.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main home screen with 4-tab bottom navigation.
class ServicesHomeScreen extends StatefulWidget {
  const ServicesHomeScreen({super.key});

  @override
  State<ServicesHomeScreen> createState() => _ServicesHomeScreenState();
}

class _ServicesHomeScreenState extends State<ServicesHomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const ServicesHomeContent(),
    const FavoritesScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.navBackground,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.navUnselected,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: _NotifBadge(child: Icon(Icons.notifications_none)),
              activeIcon: _NotifBadge(child: Icon(Icons.notifications)),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge overlay for notification icon.
class _NotifBadge extends StatelessWidget {
  final Widget child;
  const _NotifBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.navBackground, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Home tab content with search + service grid.
class ServicesHomeContent extends StatefulWidget {
  const ServicesHomeContent({super.key});

  @override
  State<ServicesHomeContent> createState() => _ServicesHomeContentState();
}

class _ServicesHomeContentState extends State<ServicesHomeContent> {
  String _searchQuery = '';
  int _pointsBalance = 0;
  bool _isLoadingPoints = true;

  @override
  void initState() {
    super.initState();
    _fetchUserPoints();
  }

  Future<void> _fetchUserPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        final userData = await WebServices().getUserByEmail(email);
        if (userData != null && userData['points_balance'] != null) {
          if (mounted) {
            setState(() {
              _pointsBalance = (userData['points_balance'] as num).toInt();
              _isLoadingPoints = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching points: $e");
    }
    if (mounted) {
      setState(() => _isLoadingPoints = false);
    }
  }

  final List<Map<String, dynamic>> serviceCategories = [
    {
      "title": "Transportation",
      "icon": Icons.directions_car_rounded,
      "color": const Color(0xFF4A7DFF),
      "services": [
        "Need Motorbike Ride",
        "Need Car Ride",
        "Need Delivery Service",
        "Need Package Courier"
      ]
    },
    {
      "title": "Home & Property",
      "icon": Icons.home_repair_service_rounded,
      "color": const Color(0xFF00BFA5),
      "services": [
        "Need Home Cleaning",
        "Need Farm Cleaning",
        "Need Gardening/Landscaping",
        "Need Handyman Services",
        "Need Pest Control"
      ]
    },
    {
      "title": "Education",
      "icon": Icons.school_rounded,
      "color": const Color(0xFFFF9800),
      "services": [
        "Need Private Teacher",
        "Need Language Tutor",
        "Need Music Instructor"
      ]
    },
    {
      "title": "Care & Health",
      "icon": Icons.health_and_safety_rounded,
      "color": const Color(0xFFE91E63),
      "services": [
        "Need Companion/Caregiver",
        "Need Babysitter",
        "Need Nursing Care",
        "Need Physical Therapy",
        "Need Elderly Assistance",
        "Need Pet Care"
      ]
    },
    {
      "title": "Professional",
      "icon": Icons.work_rounded,
      "color": const Color(0xFF9C27B0),
      "services": [
        "Need IT Support",
        "Need Graphic Design",
        "Need Event Planning",
        "Need Photography/Videography"
      ]
    },
    {
      "title": "Other",
      "icon": Icons.more_horiz_rounded,
      "color": const Color(0xFF607D8B),
      "services": ["Other Service Needed"]
    },
  ];

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty) return serviceCategories;
    final q = _searchQuery.toLowerCase();
    return serviceCategories.where((cat) {
      final titleMatch = (cat['title'] as String).toLowerCase().contains(q);
      final servicesMatch = (cat['services'] as List<String>)
          .any((s) => s.toLowerCase().contains(q));
      return titleMatch || servicesMatch;
    }).toList();
  }

  void _showSubServices(Map<String, dynamic> category) {
    final services = category['services'] as List<String>;
    final color = category['color'] as Color;
    final icon = category['icon'] as IconData;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    category['title'] as String,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Service list
              ...services.map((service) => _buildServiceRow(service, color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceRow(String service, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.arrow_forward_ios, color: color, size: 16),
        title: Text(
          service,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Looking for: $service'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          GestureDetector(
            onTap: () async {
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
            child: const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Icon(Icons.logout, color: Colors.white, size: 24),
            ),
          )
        ],
        title: const Text(
          'Services Home',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            const Text(
              "What service are you looking for?",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // ─── Points Widget ──────────────────────────────────────
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PointsTransactionScreen(initialPoints: _pointsBalance),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFED8F03).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Points',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          _isLoadingPoints
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  '$_pointsBalance pts',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Search bar ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search services...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(height: 20),
            // ─── Service Grid ───────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text(
                            'No services match "$_searchQuery"',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        final color = category['color'] as Color;
                        return GestureDetector(
                          onTap: () => _showSubServices(category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    category['icon'] as IconData,
                                    size: 34,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  category['title'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${(category['services'] as List).length} services",
                                  style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
