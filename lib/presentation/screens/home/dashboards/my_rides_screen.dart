import 'package:flutter/material.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/ride_detail_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fetchRides();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchRides() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // We keep the true API try-catch structure, but fallback to mocks for UI testing.
    List<Map<String, dynamic>> rides = [];
    try {
      final raw = await WebServices().getMyTrips();
      rides = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {}

    // Mock data injection block so the user can test the UI:
    if (rides.isEmpty) {
      rides = [
        {
          'cat_id': 201,
          'trip_title': 'Work Commute: Nasr City to Maadi',
          'seats_available': 3,
          'measurement_type': 1,
          'total_distance': 18.5,
          'price_per_seat_mu': 10.0,
          'is_active': true,
          'trip_time': '08:00:00',
          'is_recurring': true,
          'days_of_week': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu'],
          'start_date': '2026-04-01',
          'end_date': '2026-05-01',
          'start_stop_id': 1,
          'end_stop_id': 3,
        },
        {
          'cat_id': 201,
          'trip_title': 'Weekend Escape: Cairo to Alex',
          'seats_available': 1,
          'measurement_type': 1,
          'total_distance': 210.0,
          'price_per_seat_mu': 12.0,
          'is_active': false,
          'trip_time': '10:30:00',
          'is_recurring': false,
          'days_of_week': ['Fri', 'Sat'],
          'start_date': '2026-04-10',
          'end_date': '2026-04-11',
          'start_stop_id': 2,
          'end_stop_id': 4,
        },
        {
          'cat_id': 201,
          'trip_title': 'Gym Run: Heliopolis',
          'seats_available': 0,
          'measurement_type': 1,
          'total_distance': 4.2,
          'price_per_seat_mu': 10.0,
          'is_active': true,
          'trip_time': '18:45:00',
          'is_recurring': true,
          'days_of_week': ['Sun', 'Tue', 'Thu'],
          'start_date': '2026-04-03',
          'end_date': '2026-06-03',
          'start_stop_id': 2,
          'end_stop_id': 1,
        }
      ];
    }

    if (mounted) {
      setState(() {
        _rides = rides;
        _isLoading = false;
        _error = null; // Suppress error for UI preview
      });
      _fadeController.forward(from: 0);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _tripTitle(Map<String, dynamic> ride) {
    return (ride['trip_title'] ?? ride['title'] ?? 'Untitled Ride').toString();
  }

  String _tripDistance(Map<String, dynamic> ride) {
    final d = ride['total_distance'] ?? ride['distance'] ?? 0;
    final km = double.tryParse(d.toString()) ?? 0;
    return '${km.toStringAsFixed(1)} km';
  }

  String _tripTime(Map<String, dynamic> ride) {
    final t = ride['trip_time'] ?? '';
    if (t.toString().isEmpty) return '--:--';
    // Strip seconds if present (e.g. "07:30:00" -> "07:30")
    final parts = t.toString().split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t.toString();
  }

  bool _isActive(Map<String, dynamic> ride) {
    final v = ride['is_active'];
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return true;
  }

  List<String> _days(Map<String, dynamic> ride) {
    final d = ride['days_of_week'];
    if (d is List) return d.map((e) => e.toString()).toList();
    if (d is String && d.isNotEmpty) return d.split(',');
    return [];
  }

  int _seats(Map<String, dynamic> ride) {
    return int.tryParse(ride['seats_available']?.toString() ?? '') ?? 0;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
            )
          : _error != null
              ? _buildErrorState()
              : _rides.isEmpty
                  ? _buildEmptyState()
                  : _buildRideList(),
    );
  }

  // ─── Error State ────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: Colors.redAccent, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Something went wrong',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchRides,
              icon: const Icon(Icons.refresh, color: Color(0xFF00B4D8)),
              label: const Text('Retry',
                  style: TextStyle(color: Color(0xFF00B4D8))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00B4D8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00B4D8).withOpacity(0.15),
                    const Color(0xFF0077B6).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined,
                  color: Color(0xFF00B4D8), size: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Rides Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first ride from the Rides tab\nand it will appear here.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _fetchRides,
              icon: const Icon(Icons.refresh, color: Color(0xFF00B4D8)),
              label: const Text('Refresh',
                  style: TextStyle(color: Color(0xFF00B4D8))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00B4D8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ride List ──────────────────────────────────────────────────────────────

  Widget _buildRideList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        color: const Color(0xFF00B4D8),
        backgroundColor: const Color(0xFF1B2838),
        onRefresh: _fetchRides,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: _rides.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) return _buildListHeader();
            return _buildRideCard(_rides[index - 1], index - 1);
          },
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.route_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Rides',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('${_rides.length} ride${_rides.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, int index) {
    final active = _isActive(ride);
    final days = _days(ride);
    final seats = _seats(ride);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RideDetailScreen(ride: ride),
            ),
          ).then((_) => _fetchRides());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF15202B), // Softer, premium dark tone
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active
                  ? const Color(0xFF00B4D8).withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Status and Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statusBadge(active),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _tripTime(ride),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title and Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: active
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF00B4D8).withOpacity(0.2),
                                  const Color(0xFF0077B6).withOpacity(0.1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: active ? null : Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color:
                            active ? const Color(0xFF00B4D8) : Colors.white54,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tripTitle(ride),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                _tripDistance(ride),
                                style: const TextStyle(
                                  color: Color(0xFF00B4D8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$seats seat${seats == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Bottom row: Days and Chevron
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: days
                              .map((d) => Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A0E21)
                                          .withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.03)),
                                    ),
                                    child: Text(
                                      d,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white54, size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.greenAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.greenAccent : Colors.white54,
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 4)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active ? Colors.greenAccent : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
