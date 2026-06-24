import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _bgColor = Color(0xff030927);
  static const Color _cardColor = Color(0xff0d173e);
  static const Color _accentColor = Color(0xff4A6CF7);

  bool _isLoading = true;
  final Map<String, dynamic> _firestoreData = {};
  Map<String, dynamic> _backendData = {};
  String _cachedCountry = '';
  String _cachedCity = '';
  String _cachedDistrict = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    _cachedCountry = (prefs.getString('user_country') ?? '').trim();
    _cachedCity = (prefs.getString('user_city') ?? '').trim();
    _cachedDistrict = (prefs.getString('user_district') ?? '').trim();
    if (email == null || email.isEmpty) return;

    // 1. Load from Firestore manually using email if still needed?
    // User requested NO Firebase. I'll remove Firestore logic completely or just bypass if not needed.
    // "not primary or assistante". Let's rely entirely on backend API.

    // 2. Fetch from backend API
    try {
      final apiUser = await WebServices().getUserByEmail(email);
      if (apiUser != null && mounted) {
        setState(() {
          _backendData = apiUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Backend fetch error: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Helper to get value from backend first, then fallback to Firestore
  String _getValue(String backendKey, String firestoreKey,
      {String fallback = '—'}) {
    final bVal = _backendData[backendKey];
    if (bVal != null && bVal.toString().isNotEmpty) return bVal.toString();
    final fVal = _firestoreData[firestoreKey];
    if (fVal != null && fVal.toString().isNotEmpty) return fVal.toString();
    return fallback;
  }

  String _getGenderText(dynamic val) {
    if (val == null) return '—';
    if (val is int) {
      if (val == 1) return 'Male';
      if (val == 2) return 'Female';
    }
    return val.toString();
  }

  String _getStatusText(dynamic val) {
    if (val == null) return '—';
    if (val is int || int.tryParse(val.toString()) != null) {
      final intVal = val is int ? val : int.parse(val.toString());
      if (intVal == 1) return 'Pending';
      if (intVal == 2) return 'Approved';
      if (intVal == 3) return 'Rejected';
    }
    return val.toString();
  }

  String _getServiceTypeText(dynamic val) {
    if (val == null) return '—';
    if (val is int || int.tryParse(val.toString()) != null) {
      final intVal = val is int ? val : int.parse(val.toString());
      if (intVal == 1) return 'Seeker';
      if (intVal == 2) return 'Provider';
      if (intVal == 3) return 'Both';
    }
    return val.toString();
  }

  String _firstNonEmpty(List<dynamic> values, {String fallback = '—'}) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  Color _getStatusColor(dynamic val) {
    if (val == null) return Colors.grey;
    final intVal = val is int ? val : (int.tryParse(val.toString()) ?? 0);
    if (intVal == 1) return Colors.orange;
    if (intVal == 2) return Colors.green;
    if (intVal == 3) return Colors.red;
    return Colors.grey;
  }

  String _getInitials() {
    final first = _getValue('user_f_name', 'firstName', fallback: '');
    final last = _getValue('user_l_name', 'lastName', fallback: '');
    String initials = '';
    if (first.isNotEmpty) initials += first[0].toUpperCase();
    if (last.isNotEmpty) initials += last[0].toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Logout error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: _accentColor,
              child: CustomScrollView(
                slivers: [
                  // ── Gradient Header ──
                  SliverToBoxAdapter(child: _buildHeader()),
                  // ── Info Sections ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildSectionTitle('Personal Information'),
                        _buildInfoCard([
                          _buildRow(Icons.person, 'Username',
                              _getValue('user_name', 'username')),
                          _buildRow(Icons.badge, 'First Name',
                              _getValue('user_f_name', 'firstName')),
                          _buildRow(Icons.badge_outlined, 'Last Name',
                              _getValue('user_l_name', 'lastName')),
                          _buildRow(Icons.translate, 'Arabic Name',
                              _getValue('user_ar_name', 'arabicName')),
                          _buildRow(Icons.email_outlined, 'Email',
                              _getValue('user_email', 'email')),
                          _buildRow(Icons.phone_android, 'Phone',
                              _getValue('user_tel_no', 'phone')),
                          _buildRow(
                              Icons.mark_chat_unread_outlined,
                              'WhatsApp',
                              _backendData['user_whatsapp_no']?.toString() ??
                                  '—'),
                          _buildRow(
                              Icons.cake_outlined,
                              'Birth Date',
                              _backendData['birth_date']
                                      ?.toString()
                                      .split('T')
                                      .first ??
                                  '—'),
                          _buildRow(Icons.wc, 'Gender',
                              _getGenderText(_backendData['Gender'])),
                          _buildRow(Icons.work_outline, 'Job Title',
                              _backendData['job']?.toString() ?? '—'),
                        ]),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Location'),
                        _buildInfoCard([
                          _buildRow(
                              Icons.public,
                              'Country',
                              _firstNonEmpty([
                                _backendData['country'],
                                _backendData['Country'],
                                _backendData['user_country'],
                                _backendData['nationality'],
                                _backendData['cnt_name'],
                                _cachedCountry,
                              ])),
                          _buildRow(
                              Icons.location_city,
                              'State / City',
                              _firstNonEmpty([
                                _backendData['state'],
                                _backendData['city'],
                                _backendData['State'],
                                _backendData['City'],
                                _cachedCity,
                              ], fallback: _getValue('state', 'city'))),
                          _buildRow(
                              Icons.map_outlined,
                              'District',
                              _firstNonEmpty([
                                _backendData['district'],
                                _backendData['District'],
                                _cachedDistrict,
                              ])),
                        ]),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Account'),
                        _buildInfoCard([
                          _buildRow(
                              Icons.category,
                              'Service Type',
                              _getServiceTypeText(_getValue(
                                  'u_type_id', 'serviceType',
                                  fallback: '—'))),
                          _buildStatusRow(),
                        ]),
                        const SizedBox(height: 20),
                        // ── Settings Section ──
                        _buildSectionTitle('Settings'),
                        _buildInfoCard([
                          _buildThemeToggleRow(),
                          _buildActionRow(
                            Icons.language,
                            'Language',
                            'English',
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Multi-language support coming soon!')),
                              );
                            },
                          ),
                          _buildActionRow(
                            Icons.info_outline,
                            'About',
                            'v1.0.0',
                            () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'Services App',
                                applicationVersion: '1.0.0',
                                applicationLegalese: '© 2026',
                              );
                            },
                          ),
                        ]),
                        const SizedBox(height: 30),
                        // ── Logout Button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text('Logout',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade200,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────
  Widget _buildHeader() {
    final fullName =
        '${_getValue('user_f_name', 'firstName', fallback: '')} ${_getValue('user_l_name', 'lastName', fallback: '')}'
            .trim();
    final serviceType = _firestoreData['serviceType']?.toString() ?? '';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff1a237e), Color(0xff4A6CF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20, bottom: 30),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: const Color(0xff0d173e),
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            fullName.isEmpty ? 'User' : fullName,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          // Service Type Badge
          if (serviceType.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                serviceType,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SECTION TITLE ────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8),
      ),
    );
  }

  // ─── INFO CARD ────────────────────────────────────────
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }

  // ─── ROW ──────────────────────────────────────────────
  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: _accentColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATUS ROW ───────────────────────────────────────
  Widget _buildStatusRow() {
    final rawStatus = _backendData['statu'] ??
        _backendData['status'] ??
        _firestoreData['approvalStatus'];
    String statusText;
    Color statusColor;

    if (rawStatus is String) {
      statusText = rawStatus[0].toUpperCase() + rawStatus.substring(1);
      statusColor = rawStatus == 'approved'
          ? Colors.green
          : rawStatus == 'rejected'
              ? Colors.red
              : Colors.orange;
    } else {
      statusText = _getStatusText(rawStatus);
      statusColor = _getStatusColor(rawStatus);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: _accentColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Status',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── THEME TOGGLE ROW ──────────────────────────────────
  Widget _buildThemeToggleRow() {
    final themeProvider = ThemeProviderScope.maybeOf(context);
    final isDark = themeProvider?.isDark ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: _accentColor,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeTrackColor: AppColors.primary,
            onChanged: (value) {
              themeProvider?.setDark(value);
            },
          ),
        ],
      ),
    );
  }

  // ─── ACTION ROW ────────────────────────────────────────
  Widget _buildActionRow(
      IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _accentColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
