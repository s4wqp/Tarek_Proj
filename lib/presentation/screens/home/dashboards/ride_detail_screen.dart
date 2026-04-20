import 'package:flutter/material.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/ride_dashboard.dart';

class RideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Map<String, dynamic> get ride => widget.ride;

  String _startStopName = '';
  String _endStopName = '';
  final List<String> _intermediateStopNames = [];

  @override
  void initState() {
    super.initState();
    _startStopName = ride['start_stop']?['stop_name']?.toString() ??
        ride['start_stop_id']?.toString() ??
        '--';
    _endStopName = ride['end_stop']?['stop_name']?.toString() ??
        ride['end_stop_id']?.toString() ??
        '--';

    _initIntermediateStops();

    if (ride['start_stop'] == null ||
        ride['end_stop'] == null ||
        _intermediateStopNames.any((n) => int.tryParse(n) != null)) {
      _resolveStops();
    }

    // Attempt to fetch extra details (like intermediate stops) if they are missing
    _fetchDetailedTrip();
  }

  Future<void> _fetchDetailedTrip() async {
    final tripIdStr =
        ride['trip_id']?.toString() ?? ride['id']?.toString() ?? '';
    final tripId = int.tryParse(tripIdStr);
    if (tripId == null) return;

    try {
      final tripData = await WebServices().getTripById(tripId);
      if (tripData == null || !mounted) return;

      // Backend returns route_stops as an ordered array of ALL stops
      // (start, intermediate, end). Extract intermediate = everything
      // between first and last.
      final rs = tripData['route_stops'];
      if (rs is List && rs.length > 2) {
        final intermediate = rs.sublist(1, rs.length - 1);
        setState(() {
          ride['intermediate_stops'] = intermediate;
          _intermediateStopNames.clear();
          _initIntermediateStops();
          _resolveStops();
        });
        return;
      }

      // Also update start/end stop names from route_stops if available
      if (rs is List && rs.isNotEmpty) {
        setState(() {
          if (rs.first is Map && rs.first['stop_name'] != null) {
            _startStopName = rs.first['stop_name'].toString();
          }
          if (rs.last is Map && rs.last['stop_name'] != null) {
            _endStopName = rs.last['stop_name'].toString();
          }
        });
      }
    } catch (_) {}
  }

  void _initIntermediateStops() {
    final inter = ride['intermediate_stops'];
    if (inter is List) {
      for (var item in inter) {
        if (item is Map) {
          final name = item['stop']?['stop_name']?.toString() ??
              item['stop_name']?.toString();
          if (name != null) {
            _intermediateStopNames.add(name);
          } else {
            final id =
                item['stop_id']?.toString() ?? item['id']?.toString() ?? '';
            _intermediateStopNames.add(id);
          }
        } else {
          _intermediateStopNames.add(item.toString());
        }
      }
    }
  }

  Future<void> _resolveStops() async {
    try {
      final stops = await WebServices().getAllStops();
      final startId = ride['start_stop_id']?.toString();
      final endId = ride['end_stop_id']?.toString();

      bool updated = false;
      for (var s in stops) {
        if (s['id'].toString() == startId && ride['start_stop'] == null) {
          _startStopName = s['stop_name'].toString();
          updated = true;
        }
        if (s['id'].toString() == endId && ride['end_stop'] == null) {
          _endStopName = s['stop_name'].toString();
          updated = true;
        }

        for (int i = 0; i < _intermediateStopNames.length; i++) {
          final interNameOrId = _intermediateStopNames[i];
          // Check if it's matching the stop ID
          bool matchesId = interNameOrId == s['id'].toString();
          // Or if from map structure
          if (!matchesId &&
              ride['intermediate_stops'] is List &&
              ride['intermediate_stops'].length > i) {
            final rawItem = ride['intermediate_stops'][i];
            if (rawItem is Map &&
                rawItem['stop_id']?.toString() == s['id'].toString()) {
              matchesId = true;
            }
          }

          if (matchesId) {
            _intermediateStopNames[i] = s['stop_name'].toString();
            updated = true;
          }
        }
      }
      if (updated && mounted) setState(() {});
    } catch (_) {}
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _get(String key, [String fallback = '--']) =>
      (ride[key] ?? fallback).toString();

  String get _title => _get('trip_title', _get('title', 'Untitled Ride'));

  String get _distance {
    final d = ride['total_distance'] ?? ride['distance'] ?? 0;
    final km = double.tryParse(d.toString()) ?? 0;
    return '${km.toStringAsFixed(1)} km';
  }

  String get _time {
    final t = _get('trip_time', '');
    if (t.isEmpty) return '--:--';
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  bool get _isActive {
    final v = ride['is_active'];
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return true;
  }

  bool get _isRecurring {
    final v = ride['is_recurring'];
    if (v is bool) return v;
    if (v is int) return v == 1;
    return false;
  }

  int get _seats =>
      int.tryParse(ride['seats_available']?.toString() ?? '') ?? 0;

  String get _startDate => _get('start_date', '--');

  double get _reward {
    final d = ride['total_distance'] ?? 0;
    final km = double.tryParse(d.toString()) ?? 0;
    return km * 10; // 10 points per km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0E21),
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838).withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00B4D8),
                      Color(0xFF0077B6),
                      Color(0xFF0A0E21)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Body ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildWebStyleCard(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: _isActive
            ? Colors.greenAccent.withOpacity(0.15)
            : Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isActive
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isActive ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: _isActive ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStyleCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838), // A sleek premium dark shade
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web-Style Information List
          _webInfoItem(Icons.people_alt_rounded, Colors.white54,
              'Seats available: $_seats'),
          _webInfoItem(Icons.location_on_rounded, Colors.blueAccent,
              'Start: $_startStopName'),
          _webInfoItem(Icons.event_note_rounded, Colors.white54,
              'Schedule: ${_isRecurring ? 'Recurring' : 'One-time'} trip on $_startDate at $_time'),
          _webInfoItem(Icons.location_on_rounded, Colors.redAccent,
              'End: $_endStopName'),
          _webInfoItem(Icons.access_time_filled_rounded, Colors.white54,
              'Distance: $_distance'),
          _webInfoItem(Icons.merge_type_rounded, Colors.white54,
              'Intermediate stops: ${_getIntermediateCount()}'),
          _webInfoItem(Icons.star_rounded, Colors.orangeAccent,
              'Points per seat: ${_reward.toStringAsFixed(0)} points'),

          const SizedBox(height: 24),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 24),

          const Text('Route Details:',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 20),

          _buildRouteTimeline(),

          const SizedBox(height: 32),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                  icon: Icons.edit_rounded,
                  label: 'EDIT',
                  color: Colors.blueAccent,
                  onTap: () => _editTrip(context)),
              const SizedBox(width: 12),
              _buildActionButton(
                  icon: Icons.delete_rounded,
                  label: 'DELETE',
                  color: Colors.redAccent,
                  onTap: () => _deleteTrip(context)),
            ],
          )
        ],
      ),
    );
  }

  void _editTrip(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideDashboard(initialTrip: ride),
      ),
    ).then((updated) {
      if (updated == true) {
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _deleteTrip(BuildContext context) async {
    final tripIdStr =
        ride['trip_id']?.toString() ?? ride['id']?.toString() ?? '';
    final tripId = int.tryParse(tripIdStr);
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid trip ID'), backgroundColor: Colors.redAccent));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        title: const Text('Delete Trip', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to permanently delete this trip?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.redAccent)),
      );
      await WebServices().deleteTrip(tripId);
      if (!context.mounted) return;
      Navigator.pop(context); // close loading dialog
      Navigator.pop(context, true); // pop screen
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
    }
  }

  int _getIntermediateCount() {
    return _intermediateStopNames.length;
  }

  Widget _webInfoItem(IconData icon, Color iconColor, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    List<Widget> children = [];
    children.add(_timelinePill(
        _startStopName, Colors.blueAccent, Icons.location_on_rounded));

    if (_intermediateStopNames.isEmpty) {
      children.add(_timelineArrow(_distance));
    } else {
      children.add(_timelineArrow(''));
      for (int i = 0; i < _intermediateStopNames.length; i++) {
        children.add(_timelinePill(_intermediateStopNames[i],
            Colors.orangeAccent, Icons.location_on_rounded));
        if (i == _intermediateStopNames.length - 1) {
          children.add(_timelineArrow(_distance));
        } else {
          children.add(_timelineArrow(''));
        }
      }
    }

    children.add(_timelinePill(
        _endStopName, Colors.redAccent, Icons.location_on_rounded));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _timelinePill(String text, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _timelineArrow(String dist) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_downward_rounded,
              color: Colors.white38, size: 16),
          if (dist.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dist,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
