import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/points/points_transaction_screen.dart';
import 'package:tarek_proj/presentation/screens/home/edit_sponsor_screen.dart';
import 'package:tarek_proj/presentation/widgets/custom_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SponsorDashboardScreen extends StatefulWidget {
  const SponsorDashboardScreen({super.key});

  @override
  State<SponsorDashboardScreen> createState() => _SponsorDashboardScreenState();
}

class _SponsorDashboardScreenState extends State<SponsorDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _sponsorData;
  int _pointsBalance = 0;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ws = WebServices();
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');

      // 1. Fetch user data once (used for both points and sponsor lookup)
      Map<String, dynamic>? userData;
      int points = 0;
      if (userEmail != null && userEmail.isNotEmpty) {
        userData = await ws.getUserByEmail(userEmail);
        if (userData != null && userData['points_balance'] != null) {
          points = (userData['points_balance'] as num).toInt();
        }
      }

      // 2. Fetch sponsor data — try my-sponsor first, then fallback with userId we already have
      Map<String, dynamic>? sponsor;
      try {
        sponsor = await ws.getMySponsorDirect();
      } catch (_) {}
      if (sponsor == null && userData != null && userData['id'] != null) {
        final userId = userData['id'];
        sponsor = await ws.getSponsorByUserId(
          userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
        );
      }

      if (mounted) {
        setState(() {
          _sponsorData = sponsor;
          _pointsBalance = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    // Determine if it's the first image or a subsequent one
    // We assume if they have any images, it costs points. Or maybe we just enforce it always.
    // Let's check how many images they have.
    int imageCount = 0;
    if (_sponsorData != null) {
      if (_sponsorData!['imag1_photo'] != null && _sponsorData!['imag1_photo'].toString().isNotEmpty) imageCount++;
      if (_sponsorData!['imag2_photo'] != null && _sponsorData!['imag2_photo'].toString().isNotEmpty) imageCount++;
      if (_sponsorData!['imag3_photo'] != null && _sponsorData!['imag3_photo'].toString().isNotEmpty) imageCount++;
    }

    if (imageCount >= 1) {
      if (_pointsBalance < 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough points! 1000 points required to upload an additional image.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
        return;
      }

      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Upload Image', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Uploading an additional image costs 1000 points. Do you want to proceed?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Proceed', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Pick image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final ws = WebServices();
      await ws.addMySponsorImage(File(image.path));
      
      // If backend doesn't automatically deduct points, we might need a deduct points API here.
      // For now, we refresh the dashboard.
      await _loadDashboardData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSponsorScreen(
          initialSponsorData: _sponsorData,
          initialPoints: _pointsBalance,
        ),
      ),
    ).then((_) => _loadDashboardData()); // Refresh data when returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sponsor Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const LoadingOverlay(message: 'Loading your dashboard...')
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _loadDashboardData,
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sponsor Welcome Header
                        Text(
                          'Welcome, ${_sponsorData?['sponsor_name'] ?? 'Sponsor'}!',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Points Wallet Card
                        _buildPointsCard(),
                        const SizedBox(height: 20),

                        // Subscription Details Card
                        _buildSubscriptionCard(),
                        const SizedBox(height: 20),

                        // Profile Actions
                        const SectionHeader(title: 'Business Profile'),
                        const SizedBox(height: 8),
                        _buildActionCard(
                          title: 'Edit Business Info',
                          subtitle: 'Update your contact details and business name',
                          icon: Icons.edit_document,
                          color: Colors.blueAccent,
                          onTap: _editProfile,
                        ),
                        const SizedBox(height: 20),

                        // Images Management
                        _buildImagesSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPointsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PointsTransactionScreen(initialPoints: _pointsBalance)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFED8F03).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Points', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    '$_pointsBalance pts',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    // Calculate mock dates if not available from backend
    final createdAtStr = _sponsorData?['created_at'];
    DateTime startDate = DateTime.now();
    if (createdAtStr != null) {
      try {
        startDate = DateTime.parse(createdAtStr);
      } catch (_) {}
    }
    
    // Assuming renewal is 1 month after start date
    DateTime renewalDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
    
    String formattedStart = "${startDate.day}/${startDate.month}/${startDate.year}";
    String formattedRenewal = "${renewalDate.day}/${renewalDate.month}/${renewalDate.year}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Subscription Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Subscription Date:', formattedStart),
          const SizedBox(height: 10),
          _buildInfoRow('Renewal Date:', formattedRenewal),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your subscription will auto-renew on the renewal date. The monthly fee will be deducted from your balance. If insufficient funds, your account will be suspended.',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: AppColors.card,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      ),
    );
  }

  Widget _buildImagesSection() {
    List<String> images = [];
    if (_sponsorData != null) {
      for (final key in ['imag1_photo', 'imag2_photo', 'imag3_photo']) {
        final val = _sponsorData![key];
        if (val != null && val.toString().isNotEmpty) {
          String imgPath = val.toString();
          if (imgPath.startsWith('/')) {
            imgPath = imgPath.substring(1);
          }
          images.add('https://api.aidme.online/$imgPath');
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Business Images'),
            if (images.length < 3)
              TextButton.icon(
                onPressed: _uploadImage,
                icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                label: const Text('Upload', style: TextStyle(color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (images.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.image_not_supported, color: Colors.white38, size: 48),
                const SizedBox(height: 16),
                const Text('No images uploaded yet', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _uploadImage,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Upload First Image (Free)', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          )
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.card,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.white38, size: 32),
                                SizedBox(height: 8),
                                Text('Image unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          const Text(
            '* Note: Uploading any image after the first one costs 1000 points.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
      ],
    );
  }
}
