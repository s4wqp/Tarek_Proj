import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tarek_proj/config/app_colors.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/widgets/custom_widgets.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  String _filter = 'pending';
  String? _error;
  Set<int> _sponsorUserIds = {};
  String _adminToken = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_filter == 'all') return _allUsers;
    int statusCode = _filter == 'pending'
        ? 1
        : _filter == 'approved'
            ? 2
            : 3;
    return _allUsers
        .where((u) => (u['statu'] ?? u['status'] ?? 1) == statusCode)
        .toList();
  }

  int get _pendingCount {
    return _allUsers
        .where((u) => (u['statu'] ?? u['status'] ?? 1) == 1)
        .length;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Authenticate as admin
      String adminToken = '';
      try {
        Response loginResp = await Dio().post(
          'http://161.35.51.188:5001/api/auth/login',
          data: {"user_name": "ts2025", "user_password": "123456"},
          options: Options(contentType: 'application/json'),
        );
        if (loginResp.statusCode == 200 && loginResp.data != null) {
          adminToken = loginResp.data['token'] ?? '';
        }
      } catch (e) {
        print('Admin Login Error: $e');
      }

      if (adminToken.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'Failed to authenticate as admin.';
            _isLoading = false;
          });
        }
        return;
      }

      _adminToken = adminToken;

      Response response = await Dio().get(
        'http://161.35.51.188:5001/api/users?limit=10000',
        options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
      );

      List<Map<String, dynamic>> users = [];
      if (response.statusCode == 200) {
        List<dynamic> rawUsers = [];
        if (response.data is Map && response.data.containsKey('data')) {
          rawUsers = response.data['data'];
        } else if (response.data is List) {
          rawUsers = response.data;
        }

        for (var u in rawUsers) {
          if (u is Map) {
            final userMap = Map<String, dynamic>.from(u);
            // Normalize status field
            if (userMap.containsKey('status') &&
                !userMap.containsKey('statu')) {
              userMap['statu'] = userMap['status'];
            }
            users.add(userMap);
          }
        }
      }

      // Fetch all sponsors to identify sponsor users
      Set<int> sponsorIds = {};
      try {
        final allSponsors = await WebServices().getAllSponsors();
        for (var sponsor in allSponsors) {
          if (sponsor is Map) {
            final uid = sponsor['user_id'];
            if (uid != null) {
              final id = uid is int ? uid : int.tryParse(uid.toString());
              if (id != null) sponsorIds.add(id);
            }
          }
        }
      } catch (e) {
        print('Fetch sponsors for identification error: $e');
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _sponsorUserIds = sponsorIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Load Users Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserStatus(int userId, int newStatus) async {
    try {
      await Dio().put(
        'http://161.35.51.188:5001/api/users/$userId',
        data: {'statu': newStatus},
        options: Options(headers: {
          'Authorization': 'Bearer $_adminToken',
          'Content-Type': 'application/json',
        }),
      );
      await _loadUsers();
    } catch (e) {
      print('Update User Status Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    final userId = user['id'];
    if (userId == null) return;

    final int parsedUserId =
        userId is int ? userId : int.tryParse(userId.toString()) ?? 0;

    await _updateUserStatus(parsedUserId, 2);

    final email = user['user_email']?.toString() ?? user['email']?.toString();
    final whatsapp = user['user_whatsapp_no']?.toString();
    final firstName = user['user_f_name']?.toString() ?? '';
    final lastName = user['user_l_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();

    // Check if this user is a sponsor
    bool isSponsor = _sponsorUserIds.contains(parsedUserId);
    if (!isSponsor) {
      // Double-check via API in case _sponsorUserIds wasn't fully loaded
      try {
        final sponsorRecord =
            await WebServices().getSponsorByUserId(parsedUserId);
        isSponsor = sponsorRecord != null;
        if (isSponsor) {
          _sponsorUserIds.add(parsedUserId);
        }
      } catch (e) {
        print('Sponsor check error: $e');
      }
    }

    // Send email notification
    if (email != null && email.isNotEmpty) {
      try {
        String emailSubject;
        String emailBody;

        if (isSponsor) {
          // Sponsor-specific approval email
          emailSubject = '\uD83C\uDF89 Sponsor Account Approved — AidMe';
          emailBody = 'Dear ${name.isNotEmpty ? name : 'Valued Sponsor'},\n\n'
              'Congratulations! Your account has been approved successfully, '
              'and your image (or logo) will now be displayed among the Sponsor '
              'images in the app\'s top App Bar.\n\n'
              'Your brand is now live and visible to all AidMe users immediately! '
              'We are thrilled to have you as a valued sponsor partner.\n\n'
              'Thank you for supporting AidMe!\n\n'
              'Warm regards,\n'
              'The AidMe Team';
        } else {
          // Generic approval email for non-sponsor users
          emailSubject = 'Account Approved — AidMe';
          emailBody =
              'Dear $name,\n\nCongratulations! Your AidMe account has been approved.\n\nYou can now login and start using our services.\n\nBest regards,\nAidMe Team';
        }

        final emailUri = Uri(
          scheme: 'mailto',
          path: email,
          queryParameters: {
            'subject': emailSubject,
            'body': emailBody,
          },
        );
        await launchUrl(emailUri);
      } catch (e) {
        print('Email launch error: $e');
      }
    }

    // Send WhatsApp notification
    if (whatsapp != null && whatsapp.isNotEmpty) {
      try {
        String phone = whatsapp.replaceAll(RegExp(r'[^0-9+]'), '');
        if (!phone.startsWith('+')) phone = '+2$phone'; // Egypt default

        String waMessage;
        if (isSponsor) {
          waMessage =
              'Dear ${name.isNotEmpty ? name : 'Valued Sponsor'}, '
              'congratulations! Your account has been approved successfully, '
              'and your image (or logo) will now be displayed among the Sponsor '
              'images in the app\'s top App Bar. '
              'Your brand is now live! — AidMe Team';
        } else {
          waMessage =
              'Dear $name, your AidMe account has been approved! '
              'You can now login and use our services. — AidMe Team';
        }

        final waUrl = Uri.parse(
            'https://wa.me/$phone?text=${Uri.encodeComponent(waMessage)}');
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('WhatsApp launch error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${name.isNotEmpty ? name : 'User'} approved!${isSponsor ? ' (Sponsor)' : ''}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    final userId = user['id'];
    if (userId == null) return;

    final firstName = user['user_f_name']?.toString() ?? '';
    final lastName = user['user_l_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('Reject User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject ${name.isNotEmpty ? name : 'this user'}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _updateUserStatus(
        userId is int ? userId : int.tryParse(userId.toString()) ?? 0, 3);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${name.isNotEmpty ? name : 'User'} rejected.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // ── UI Helpers ──

  String _getStatusLabel(int status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Approved';
      case 3:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.amber;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String _getUserTypeLabel(dynamic typeId, {int? userId}) {
    final id = typeId is int ? typeId : int.tryParse(typeId?.toString() ?? '');
    if (id == 2 && userId != null && _sponsorUserIds.contains(userId)) {
      return 'Sponsor';
    }
    switch (id) {
      case 1:
        return 'Seeker';
      case 2:
        return 'Provider';
      default:
        return 'User';
    }
  }

  Color _getUserTypeColor(dynamic typeId, {int? userId}) {
    final id = typeId is int ? typeId : int.tryParse(typeId?.toString() ?? '');
    if (id == 2 && userId != null && _sponsorUserIds.contains(userId)) {
      return Colors.amber;
    }
    switch (id) {
      case 1:
        return AppColors.info;
      case 2:
        return AppColors.secondary;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterChip(String label, String value, {int? badge}) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final firstName = user['user_f_name']?.toString() ?? '';
    final lastName = user['user_l_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final email =
        user['user_email']?.toString() ?? user['email']?.toString() ?? '';
    final username = user['user_name']?.toString() ?? '';
    final status = user['statu'] ?? user['status'] ?? 1;
    final statusInt = status is int ? status : int.tryParse(status.toString()) ?? 1;
    final userType = user['u_type_id'];
    final rawUserId = user['id'];
    final int? parsedUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    final initial =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withAlpha(60),
                child: Text(
                  initial,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'No Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(statusInt).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(statusInt).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _getStatusLabel(statusInt),
                  style: TextStyle(
                    color: _getStatusColor(statusInt),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Email row
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // User type badge
          if (userType != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getUserTypeColor(userType, userId: parsedUserId).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getUserTypeLabel(userType, userId: parsedUserId),
                      style: TextStyle(
                        color: _getUserTypeColor(userType, userId: parsedUserId),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Action buttons
          if (statusInt == 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveUser(user),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectUser(user),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Users',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingOverlay(message: 'Loading users...')
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _loadUsers,
                )
              : Column(
                  children: [
                    // Filter tabs
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            _buildFilterChip('Pending', 'pending',
                                badge: _pendingCount),
                            _buildFilterChip('Approved', 'approved'),
                            _buildFilterChip('Rejected', 'rejected'),
                          ],
                        ),
                      ),
                    ),
                    // User count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} user${filtered.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                          Text(
                            'Total: ${_allUsers.length}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // User list
                    Expanded(
                      child: filtered.isEmpty
                          ? EmptyState(
                              icon: Icons.people_outline,
                              title: 'No users found',
                              subtitle:
                                  'No users match the "$_filter" filter.',
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _loadUsers,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return _buildUserCard(
                                      filtered[index]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
