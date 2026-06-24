import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PointsTransactionScreen extends StatefulWidget {
  final int initialPoints;

  const PointsTransactionScreen({super.key, this.initialPoints = 0});

  @override
  State<PointsTransactionScreen> createState() => _PointsTransactionScreenState();
}

class _PointsTransactionScreenState extends State<PointsTransactionScreen> {

  int _pointsBalance = 0;
  int _totalEarned = 0;
  int _totalSpent = 0;
  String _lastTransactionDate = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pointsBalance = widget.initialPoints;
    _fetchUserWalletData();
  }

  Future<void> _fetchUserWalletData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      if (email != null && email.isNotEmpty) {
        final userData = await WebServices().getUserByEmail(email);
        if (userData != null && mounted) {
          final wallets = userData['wallets'];
          final pointsWallet = wallets != null ? wallets['points'] : null;

          setState(() {
            _pointsBalance = (userData['points_balance'] as num?)?.toInt() ?? widget.initialPoints;
            _totalEarned = (userData['total_points_earned'] as num?)?.toInt() ??
                (pointsWallet != null ? (pointsWallet['total_points_earned'] as num?)?.toInt() ?? 0 : 0);
            _totalSpent = (userData['total_points_spent'] as num?)?.toInt() ??
                (pointsWallet != null ? (pointsWallet['total_points_spent'] as num?)?.toInt() ?? 0 : 0);
            _lastTransactionDate = pointsWallet != null
                ? (pointsWallet['last_points_date']?.toString() ?? '')
                : '';
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching wallet data: $e");
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Points Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUserWalletData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Balance Card ───────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFED8F03).withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.white, size: 36),
                              const SizedBox(width: 8),
                              Text(
                                '$_pointsBalance',
                                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Text('pts', style: TextStyle(color: Colors.white, fontSize: 20)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Stats Row ──────────────────────────
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Earned', '+$_totalEarned', Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Total Spent', '-$_totalSpent', Colors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Wallet Info ─────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet Details',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Points Balance', '$_pointsBalance pts'),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoRow('Total Earned', '$_totalEarned pts'),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoRow('Total Spent', '$_totalSpent pts'),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoRow('Last Transaction', _formatDate(_lastTransactionDate)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Info Note ───────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Earn points by completing rides, referrals, and daily logins. Use points to unlock premium features!',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
