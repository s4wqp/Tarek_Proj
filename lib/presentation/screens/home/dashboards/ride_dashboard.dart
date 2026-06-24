import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/profile/ProfileScreen.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/my_rides_screen.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/location_search_delegate.dart';
import 'package:tarek_proj/config/app_secrets.dart';

class RideDashboard extends StatefulWidget {
  final bool isProvider;
  final Map<String, dynamic>? initialTrip;
  const RideDashboard({super.key, this.isProvider = false, this.initialTrip});

  @override
  State<RideDashboard> createState() => _RideDashboardState();
}

class _RideDashboardState extends State<RideDashboard> {
  int _selectedIndex = 0;

  void switchToMyRides() {
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _RideWizard(
          isProvider: widget.isProvider,
          onRideSubmitted: switchToMyRides,
          initialTrip: widget.initialTrip),
      const MyRidesScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D1B2A),
        selectedItemColor: const Color(0xFF00B4D8),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.add_road_rounded), label: 'New Ride'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_car), label: 'My Rides'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── Data Model ──────────────────────────────────────────────────────────────

class RoutePoint {
  String label;
  LatLng? latLng;
  RoutePoint({required this.label, this.latLng});
}

// ─── Ride Wizard (Main Content) ─────────────────────────────────────────────

class _RideWizard extends StatefulWidget {
  final bool isProvider;
  final VoidCallback? onRideSubmitted;
  final Map<String, dynamic>? initialTrip;
  const _RideWizard(
      {this.isProvider = false, this.onRideSubmitted, this.initialTrip});

  @override
  State<_RideWizard> createState() => _RideWizardState();
}

class _RideWizardState extends State<_RideWizard> {
  static const String _googleMapsApiKey = AppSecrets.googleMapsApiKey;
  int _currentStep = 0;
  bool _isMapExpanded = false;
  Future<_Step2Data>? _step2Future;
  String? _selectedCountryName;
  String? _selectedCountryCode;
  bool _isCountryLoading = true;
  bool _isSubmitting = false;
  int _measurementType = 1; // 1=KM, 2=Mile, 3=Hour
  bool _isTripActive = true;
  bool _isRecurring = false;

  // Route points
  RoutePoint startPoint = RoutePoint(label: '');
  List<RoutePoint> restPoints = [];
  RoutePoint endPoint = RoutePoint(label: '');

  // Controllers
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final List<TextEditingController> _restControllers = [];
  final _tripTitleController = TextEditingController();
  final _seatsController = TextEditingController(text: '1');
  final _pricePerUnitController = TextEditingController(text: '10');

  // Day/Time
  final List<String> _allDays = [
    'Sat',
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri'
  ];
  final Set<String> _selectedDays = {};
  TimeOfDay _departureTime = const TimeOfDay(hour: 7, minute: 30);

  // Map controller
  final MapController _mapController = MapController();

  // Reward rate: 10 points per km
  static const double _rewardPerKm = 10.0;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadUserCountryRestriction();
    _loadInitialTrip();
  }

  void _loadInitialTrip() {
    if (widget.initialTrip == null) return;

    final t = widget.initialTrip!;
    _tripTitleController.text =
        (t['trip_title'] ?? t['title'] ?? '').toString();
    _seatsController.text = (t['seats_available'] ?? 1).toString();
    _pricePerUnitController.text = (t['price_per_seat_mu'] ?? 10).toString();

    if (t['is_active'] != null) {
      _isTripActive = t['is_active'] == 1 ||
          t['is_active'] == true ||
          t['is_active'] == '1';
    }

    if (t['is_recurring'] != null) {
      _isRecurring = t['is_recurring'] == 1 ||
          t['is_recurring'] == true ||
          t['is_recurring'] == '1';
    }

    final d = t['days_of_week'];
    if (d is List) {
      _selectedDays.addAll(d.map((e) => e.toString()));
    } else if (d is String && d.isNotEmpty) {
      _selectedDays.addAll(d.split(','));
    }

    _measurementType =
        int.tryParse(t['measurement_type']?.toString() ?? '') ?? 1;

    if (t['start_stop'] != null && t['start_stop'] is Map) {
      startPoint.label = t['start_stop']['stop_name']?.toString() ?? '';
      _startController.text = startPoint.label;
    }
    if (t['end_stop'] != null && t['end_stop'] is Map) {
      endPoint.label = t['end_stop']['stop_name']?.toString() ?? '';
      _endController.text = endPoint.label;
    }
  }

  Future<void> _loadUserCountryRestriction() async {
    // Temporary override: force location search scope to Egypt only.
    if (mounted) {
      setState(() {
        _selectedCountryName = 'Egypt';
        _selectedCountryCode = 'eg';
        _isCountryLoading = false;
      });
      return;
    }
    _selectedCountryName = 'Egypt';
    _selectedCountryCode = 'eg';
    _isCountryLoading = false;
  }

  Future<RoutePoint?> _openLocationSearch() async {
    if (_isCountryLoading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading your country restriction...')),
        );
      }
      return null;
    }

    if ((_selectedCountryName ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Country is not available for this account. Please update your profile country.')),
        );
      }
      return null;
    }

    return showSearch<RoutePoint?>(
      context: context,
      delegate: LocationSearchDelegate(
        countryCode: _selectedCountryCode,
        countryName: _selectedCountryName,
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _tripTitleController.dispose();
    _seatsController.dispose();
    _pricePerUnitController.dispose();
    for (var c in _restControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── GPS Detection ────────────────────────────────────────────────────────
  Future<LatLng?> _detectCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Please enable location services in your phone settings.')),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Location permission is permanently denied. Please enable it in Android settings.')),
          );
        }
        return null;
      }

      // Show a temporary snackbar to let the user know we are searching
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Detecting location...'),
              duration: Duration(seconds: 1)),
        );
      }

      // Try for immediate last known position first (fastest)
      Position? position = await Geolocator.getLastKnownPosition();

      // If null, get current position with a timeout so it doesn't hang on emulators
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not detect location automatically. Please search manually.')),
        );
      }
      return null;
    }
  }

  // Fake geocode removed since we use real coordinates from Nominatim now.

  // ─── Distance calculation (Haversine) ──────────────────────────────────
  double _distanceKm(LatLng a, LatLng b) {
    const Distance distance = Distance();
    double m = distance.as(LengthUnit.Meter, a, b);
    return m / 1000.0;
  }

  List<LatLng> _getAllLatLngs() {
    List<LatLng> all = [];
    if (startPoint.latLng != null) all.add(startPoint.latLng!);
    for (var rp in restPoints) {
      if (rp.latLng != null) all.add(rp.latLng!);
    }
    if (endPoint.latLng != null) all.add(endPoint.latLng!);
    return all;
  }

  Future<_RouteMetrics> _fetchRouteMetrics(LatLng from, LatLng to) async {
    final key =
        '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}|${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
    if (_routeCache.containsKey(key)) return _routeCache[key]!;

    // Prefer Google Directions for closer parity with Google Maps.
    if (_googleMapsApiKey.isNotEmpty) {
      try {
        final googleResponse = await _dio.get(
          'https://maps.googleapis.com/maps/api/directions/json',
          queryParameters: {
            'origin': '${from.latitude},${from.longitude}',
            'destination': '${to.latitude},${to.longitude}',
            'mode': 'driving',
            'key': _googleMapsApiKey,
          },
        );
        if (googleResponse.statusCode == 200) {
          final data = googleResponse.data as Map<String, dynamic>? ?? {};
          final routes = data['routes'] as List<dynamic>? ?? [];
          if (routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final legs = route['legs'] as List<dynamic>? ?? [];
            final encoded = ((route['overview_polyline'] ?? {})
                    as Map<String, dynamic>)['points']
                ?.toString();
            if (legs.isNotEmpty && encoded != null && encoded.isNotEmpty) {
              final leg = legs.first as Map<String, dynamic>;
              final distanceMeters = ((leg['distance'] ?? {})
                      as Map<String, dynamic>)['value'] as num? ??
                  0;
              final points = _decodeGooglePolyline(encoded);
              final metrics = _RouteMetrics(
                distanceKm: distanceMeters.toDouble() / 1000.0,
                polylinePoints: points,
              );
              _routeCache[key] = metrics;
              return metrics;
            }
          }
        }
      } catch (_) {}
    }

    try {
      final response = await _dio.get(
        'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': false,
          'steps': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>? ?? {};
        final routes = data['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final geometry = route['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geometry['coordinates'] as List<dynamic>? ?? [];
          final points = coords
              .whereType<List<dynamic>>()
              .where((c) => c.length >= 2)
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          final metrics = _RouteMetrics(
            distanceKm: distanceMeters / 1000.0,
            polylinePoints: points,
          );
          _routeCache[key] = metrics;
          return metrics;
        }
      }
    } catch (_) {}

    // Fallback to straight-line distance if routing API fails.
    final fallbackKm = _distanceKm(from, to);
    final fallback =
        _RouteMetrics(distanceKm: fallbackKm, polylinePoints: [from, to]);
    _routeCache[key] = fallback;
    return fallback;
  }

  List<LatLng> _decodeGooglePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  final Map<String, _RouteMetrics> _routeCache = {};

  Future<_Step2Data> _buildStep2Data() async {
    final chain = [startPoint, ...restPoints, endPoint];
    final List<_LegInfo> legs = [];
    final List<LatLng> fullPolyline = [];

    for (int i = 0; i < chain.length - 1; i++) {
      final a = chain[i];
      final b = chain[i + 1];
      if (a.latLng == null || b.latLng == null) continue;

      final metrics = await _fetchRouteMetrics(a.latLng!, b.latLng!);
      final reward = metrics.distanceKm * _rewardPerKm;
      legs.add(_LegInfo(
        from: a.label.isEmpty ? 'Point ${i + 1}' : a.label,
        to: b.label.isEmpty ? 'Point ${i + 2}' : b.label,
        distanceKm: metrics.distanceKm,
        rewardPoints: reward,
      ));

      if (metrics.polylinePoints.isNotEmpty) {
        if (fullPolyline.isNotEmpty &&
            fullPolyline.last == metrics.polylinePoints.first) {
          fullPolyline.addAll(metrics.polylinePoints.skip(1));
        } else {
          fullPolyline.addAll(metrics.polylinePoints);
        }
      }
    }

    final totalKm = legs.fold<double>(0, (sum, l) => sum + l.distanceKm);
    final totalReward = legs.fold<double>(0, (sum, l) => sum + l.rewardPoints);
    return _Step2Data(
      legs: legs,
      fullPolyline: fullPolyline,
      totalKm: totalKm,
      totalReward: totalReward,
    );
  }

  // ─── Add Rest Point ───────────────────────────────────────────────────
  void _addRestPoint() {
    if (restPoints.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 rest points allowed.')),
      );
      return;
    }
    setState(() {
      restPoints.add(RoutePoint(label: ''));
      _restControllers.add(TextEditingController());
    });
  }

  void _removeRestPoint(int index) {
    setState(() {
      restPoints.removeAt(index);
      _restControllers[index].dispose();
      _restControllers.removeAt(index);
    });
  }

  // ─── Build Steps ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        automaticallyImplyLeading: false,
        title: Text(
          widget.isProvider ? 'Ride Provider' : 'Find a Ride',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),
          // Step content
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildStep1_Route(),
                _buildStep2_Rewards(),
                _buildStep3_Days(),
                _buildStep4_Time(),
                _buildStep5_Confirm(),
              ],
            ),
          ),
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  // ─── Step Indicator ─────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final labels = ['Route', 'Rewards', 'Days', 'Time', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          bool isActive = i == _currentStep;
          bool isDone = i < _currentStep;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF00B4D8)
                        : isActive
                            ? const Color(0xFF0077B6)
                            : const Color(0xFF1B2838),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF00B4D8)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text('${i + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white38,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Navigation Buttons ─────────────────────────────────────────────────
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep -= 1;
                    // Rebuild step 2 data when returning to the route step.
                    if (_currentStep == 0) _step2Future = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00B4D8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back',
                    style: TextStyle(color: Color(0xFF00B4D8), fontSize: 16)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _onNextPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _currentStep == 4 ? 'Submit Ride' : 'Next',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNextPressed() {
    if (_currentStep == 0) {
      // Validate route
      if (_startController.text.trim().isEmpty ||
          _endController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please set both Start and End points.')),
        );
        return;
      }
      // We no longer fake geocode on next pressed, because points are picked in UI.
      // But we still validate they have real coordinates.
      if (startPoint.latLng == null || endPoint.latLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please select Start and End points accurately from the search suggestion or GPS.')),
        );
        return;
      }
      for (int i = 0; i < restPoints.length; i++) {
        if (restPoints[i].latLng == null && restPoints[i].label.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Please select valid coordinates for Rest Stop ${i + 1}.')),
          );
          return;
        }
      }
    }

    if (_currentStep == 2) {
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select at least one working day.')),
        );
        return;
      }
    }

    if (_currentStep < 4) {
      setState(() {
        if (_currentStep == 0) {
          _step2Future = _buildStep2Data();
        }
        _currentStep++;
      });
    } else {
      // Submit
      _submitRide();
    }
  }

  int? _nearestStopIdForPoint(
    LatLng point,
    List<dynamic> stops, {
    double thresholdKm = 1.0,
  }) {
    double bestKm = double.infinity;
    int? bestId;

    for (final s in stops) {
      if (s is! Map) continue;

      final idVal = s['id'];
      final latVal = s['latitude'];
      final lonVal = s['longitude'];

      final id = idVal is int ? idVal : int.tryParse(idVal?.toString() ?? '');
      final lat = latVal is num
          ? latVal.toDouble()
          : double.tryParse(latVal?.toString() ?? '');
      final lon = lonVal is num
          ? lonVal.toDouble()
          : double.tryParse(lonVal?.toString() ?? '');

      if (id == null || lat == null || lon == null) continue;

      final km = _distanceKm(point, LatLng(lat, lon));
      if (km < bestKm) {
        bestKm = km;
        bestId = id;
      }
    }

    if (bestId == null) return null;
    if (bestKm > thresholdKm) return null;
    return bestId;
  }

  Future<void> _submitRide() async {
    if (_isSubmitting) return;

    if (startPoint.label.isEmpty || endPoint.label.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select valid Start and End points.')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final routeData = await _buildStep2Data();
      final totalDistance = routeData.totalKm;

      // Stop Resolver Helper
      Future<int?> resolveStop(
          RoutePoint pt, List<dynamic> stops, String fallbackName) async {
        if (pt.label.isEmpty && pt.latLng == null) return null;
        int? sId;
        if (pt.latLng != null) {
          sId = _nearestStopIdForPoint(pt.latLng!, stops);
          if (sId == null) {
            try {
              final res = await WebServices().createStop({
                'stop_name': pt.label.isNotEmpty ? pt.label : fallbackName,
                'latitude': pt.latLng!.latitude.toString(),
                'longitude': pt.latLng!.longitude.toString(),
              });
              sId = res.data['id'] ??
                  (res.data['data'] != null ? res.data['data']['id'] : null);
            } catch (_) {}
          }
        } else {
          final match = stops
              .where((s) => s['stop_name'].toString() == pt.label)
              .toList();
          if (match.isNotEmpty) sId = match.first['id'];
        }
        return sId;
      }

      int? startId = widget.initialTrip != null
          ? widget.initialTrip!['start_stop_id']
          : null;
      int? endId = widget.initialTrip != null
          ? widget.initialTrip!['end_stop_id']
          : null;
      List<int> finalRestIds = [];

      try {
        final stops = await WebServices().getAllStops();
        startId =
            await resolveStop(startPoint, stops, 'Origin Stop') ?? startId;
        endId = await resolveStop(endPoint, stops, 'Destination Stop') ?? endId;

        for (int i = 0; i < restPoints.length; i++) {
          final rId =
              await resolveStop(restPoints[i], stops, 'Rest Stop ${i + 1}');
          if (rId != null) finalRestIds.add(rId);
        }
      } catch (e) {
        print("Stop resolution error: $e");
      }

      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));

      String fmtDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final tripTime =
          '${_departureTime.hour.toString().padLeft(2, '0')}:${_departureTime.minute.toString().padLeft(2, '0')}:00';

      final seats = int.tryParse(_seatsController.text.trim()) ?? 1;
      final pricePerUnit =
          double.tryParse(_pricePerUnitController.text.trim()) ?? _rewardPerKm;
      final tripTitle = _tripTitleController.text.trim().isNotEmpty
          ? _tripTitleController.text.trim()
          : 'Ride: ${startPoint.label} -> ${endPoint.label}';

      final payload = <String, dynamic>{
        'cat_id': 201,
        'start_stop_id': startId ?? 0,
        'end_stop_id': endId ?? 0,
        'trip_title': tripTitle,
        'seats_available': seats < 1 ? 1 : seats,
        'measurement_type': _measurementType,
        'total_distance': double.parse(totalDistance.toStringAsFixed(2)),
        'price_per_seat_mu': double.parse(pricePerUnit.toStringAsFixed(2)),
        'is_active': _isTripActive,
        'is_recurring': _isRecurring,
        'schedule': {
          'trip_time': tripTime,
          'days_of_week': _selectedDays.toList(),
          'start_date': fmtDate(now),
          'end_date': fmtDate(endDate),
        },
        // Backend expects route_stops as a plain array of intermediate stop IDs
        'route_stops': finalRestIds,
      };

      // Attempt backend submission (BLOCKING)
      try {
        int? targetTripId;
        if (widget.initialTrip != null) {
          final tripIdStr = widget.initialTrip!['trip_id']?.toString() ??
              widget.initialTrip!['id']?.toString() ??
              '';
          targetTripId = int.tryParse(tripIdStr);
          if (targetTripId != null) {
            await WebServices().updateTrip(targetTripId, payload);
          }
        } else {
          final res = await WebServices().createTrip(payload);
          targetTripId =
              res.data['success'] == true ? res.data['trip_id'] : null;
        }

        if (mounted) {
          if (widget.initialTrip != null) {
            Navigator.pop(context, true); // Return back
            return;
          } else {
            _showSuccessDialog();
          }
        }
      } on DioException catch (e) {
        if (mounted) {
          final errorData = e.response?.data;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Submission failed: ${e.response?.statusCode} - $errorData'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        print("DioException in createTrip: ${e.response?.data}");
        return; // Halt without success
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        print("Error in createTrip: $e");
        return; // Halt without success
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Operation error: $msg')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00B4D8), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text('Ride Submitted!',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        content: const Text(
          'Your ride route has been saved successfully. You will start receiving ride requests based on your schedule.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onRideSubmitted?.call(); // Switch to My Rides tab
            },
            child: const Text('View My Rides',
                style: TextStyle(
                    color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: ROUTE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1_Route() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set Your Route',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Add start, rest stops (max 5), and end point.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),

          // Start Point
          _buildLocationInput(
            label: 'Start Point',
            controller: _startController,
            icon: Icons.trip_origin,
            color: Colors.greenAccent,
            onGps: () async {
              LatLng? loc = await _detectCurrentLocation();
              if (loc != null) {
                if (!mounted) return;
                setState(() {
                  startPoint.latLng = loc;
                  _startController.text =
                      'My Location (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
                  startPoint.label = _startController.text;
                });
              }
            },
            onSearch: () async {
              RoutePoint? result = await _openLocationSearch();
              if (result != null) {
                setState(() {
                  startPoint = result;
                  _startController.text = result.label;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Rest Points
          ...List.generate(restPoints.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLocationInput(
                label: 'Rest Stop ${i + 1}',
                controller: _restControllers[i],
                icon: Icons.local_cafe,
                color: Colors.orangeAccent,
                onGps: () async {
                  LatLng? loc = await _detectCurrentLocation();
                  if (loc != null) {
                    if (!mounted) return;
                    setState(() {
                      restPoints[i].latLng = loc;
                      _restControllers[i].text =
                          'My Location (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
                      restPoints[i].label = _restControllers[i].text;
                    });
                  }
                },
                onRemove: () => _removeRestPoint(i),
                onSearch: () async {
                  RoutePoint? result = await _openLocationSearch();
                  if (result != null) {
                    setState(() {
                      restPoints[i] = result;
                      _restControllers[i].text = result.label;
                    });
                  }
                },
              ),
            );
          }),

          // Add Rest Point Button
          if (restPoints.length < 5)
            TextButton.icon(
              onPressed: _addRestPoint,
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF00B4D8)),
              label: const Text('Add Rest Stop',
                  style: TextStyle(color: Color(0xFF00B4D8))),
            ),
          const SizedBox(height: 12),

          // End Point
          _buildLocationInput(
            label: 'End Point',
            controller: _endController,
            icon: Icons.location_on,
            color: Colors.redAccent,
            onGps: () async {
              LatLng? loc = await _detectCurrentLocation();
              if (loc != null) {
                if (!mounted) return;
                setState(() {
                  endPoint.latLng = loc;
                  _endController.text =
                      'My Location (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
                  endPoint.label = _endController.text;
                });
              }
            },
            onSearch: () async {
              RoutePoint? result = await _openLocationSearch();
              if (result != null) {
                setState(() {
                  endPoint = result;
                  _endController.text = result.label;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required VoidCallback onGps,
    required VoidCallback onSearch,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child:
                      const Icon(Icons.close, color: Colors.white38, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  onTap: onSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tap to search for a location...',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFF0A0E21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onGps,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.my_location, color: color, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: REWARDS + MAP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2_Rewards() {
    // Build markers once from selected points.
    List<Marker> markers = [];
    List<RoutePoint> chain = [startPoint, ...restPoints, endPoint];
    final markerColors = [
      Colors.greenAccent,
      ...List.filled(restPoints.length, Colors.orangeAccent),
      Colors.redAccent
    ];
    final markerIcons = [
      Icons.trip_origin,
      ...List.filled(restPoints.length, Icons.local_cafe),
      Icons.location_on
    ];

    for (int i = 0; i < chain.length; i++) {
      if (chain[i].latLng != null) {
        final color = i < markerColors.length ? markerColors[i] : Colors.white;
        final iconData = i < markerIcons.length ? markerIcons[i] : Icons.place;
        markers.add(Marker(
          point: chain[i].latLng!,
          width: 40,
          height: 40,
          builder: (ctx) => Icon(iconData, color: color, size: 30),
        ));
      }
    }

    return FutureBuilder<_Step2Data>(
      future: _step2Future ??= _buildStep2Data(),
      builder: (context, snapshot) {
        final routeData = snapshot.data;
        final allPoints = routeData?.fullPolyline ?? _getAllLatLngs();
        final totalKm = routeData?.totalKm ?? 0.0;
        final totalReward = routeData?.totalReward ?? 0.0;
        final legs = routeData?.legs ?? const <_LegInfo>[];

        LatLng center = allPoints.isNotEmpty
            ? LatLng(
                allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                    allPoints.length,
                allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                    allPoints.length,
              )
            : const LatLng(30.0444, 31.2357);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Distance & Rewards',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                  'See your route on the map and your reward for each leg.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  IconButton(
                    tooltip: _isMapExpanded ? 'Minimize map' : 'Maximize map',
                    onPressed: () {
                      setState(() {
                        _isMapExpanded = !_isMapExpanded;
                      });
                    },
                    icon: Icon(
                      _isMapExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF00B4D8),
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _isMapExpanded ? 380 : 220,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: center,
                      zoom: 11.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.tarek.proj',
                      ),
                      if (allPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: allPoints,
                              strokeWidth: 4,
                              color: const Color(0xFF00B4D8),
                            ),
                          ],
                        ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Calculating real road distance...',
                      style: TextStyle(color: Colors.white54)),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalStat('Total Distance',
                        '${totalKm.toStringAsFixed(1)} km', Icons.straighten),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildTotalStat('Total Reward',
                        '${totalReward.toStringAsFixed(0)} pts', Icons.star),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...legs.map((leg) => _buildLegCard(leg)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildLegCard(_LegInfo leg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_right_alt, color: Color(0xFF00B4D8), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${leg.from} → ${leg.to}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text('${leg.distanceKm.toStringAsFixed(1)} km',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFF00B4D8), size: 16),
                const SizedBox(width: 4),
                Text('${leg.rewardPoints.toStringAsFixed(0)} pts',
                    style: const TextStyle(
                        color: Color(0xFF00B4D8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: DAYS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3_Days() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Working Days',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Select which days this ride will be available.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _allDays.map((day) {
              bool selected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00B4D8)
                        : const Color(0xFF1B2838),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFF00B4D8) : Colors.white12,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (_selectedDays.length == _allDays.length) {
                  _selectedDays.clear();
                } else {
                  _selectedDays.addAll(_allDays);
                }
              });
            },
            icon: Icon(
              _selectedDays.length == _allDays.length
                  ? Icons.deselect
                  : Icons.select_all,
              color: const Color(0xFF00B4D8),
            ),
            label: Text(
              _selectedDays.length == _allDays.length
                  ? 'Deselect All'
                  : 'Select All Days',
              style: const TextStyle(color: Color(0xFF00B4D8)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: TIME
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4_Time() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Departure Time',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Set the time you will depart from your start point.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _departureTime,
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00B4D8),
                        surface: Color(0xFF1B2838),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _departureTime = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2838),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_filled,
                      color: Color(0xFF00B4D8), size: 36),
                  const SizedBox(width: 16),
                  Text(
                    _departureTime.format(context),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Tap to change time',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          _buildTripConfigCard(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTripConfigCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Settings (Temporary UI)',
            style: TextStyle(
                color: Color(0xFF00B4D8),
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 10),
          _darkInput(
            controller: _tripTitleController,
            hint: 'Trip title (example: Nasr City to Maadi)',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _darkInput(
                  controller: _seatsController,
                  hint: 'Seats available',
                  helper: 'How many passengers?',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _darkInput(
                  controller: _pricePerUnitController,
                  hint: 'Points per unit',
                  helper: _measurementType == 1
                      ? 'Points per KM'
                      : _measurementType == 2
                          ? 'Points per Mile'
                          : 'Points per Hour',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _measurementType,
            dropdownColor: const Color(0xFF0A0E21),
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Measurement'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('KM')),
              DropdownMenuItem(value: 2, child: Text('Mile')),
              DropdownMenuItem(value: 3, child: Text('Hour')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _measurementType = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Trip Active',
                style: TextStyle(color: Colors.white)),
            value: _isTripActive,
            onChanged: (v) => setState(() => _isTripActive = v),
            activeThumbColor: const Color(0xFF00B4D8),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring Trip',
                style: TextStyle(color: Colors.white)),
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
            activeThumbColor: const Color(0xFF00B4D8),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF0A0E21),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _darkInput({
    required TextEditingController controller,
    required String hint,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(hint).copyWith(
        helperText: helper,
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5: CONFIRM
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep5_Confirm() {
    List<String> sortedDays =
        _allDays.where((d) => _selectedDays.contains(d)).toList();

    return FutureBuilder<_Step2Data>(
      // Use the same road-distance metrics used in Step 2 to avoid mismatches.
      future: _buildStep2Data(),
      builder: (context, snapshot) {
        final routeData = snapshot.data;
        final totalKm = routeData?.totalKm ?? 0.0;
        final totalReward = routeData?.totalReward ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm Your Ride',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Review everything before submitting.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Text(
                  'Calculating real road distance...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              const SizedBox(height: 12),

              // Route Summary
              _buildSummarySection('Route', Icons.route, [
                '📍 Start: ${startPoint.label}',
                ...restPoints.map((rp) => '☕ Rest: ${rp.label}'),
                '🏁 End: ${endPoint.label}',
              ]),
              const SizedBox(height: 12),

              // Distance & Rewards (road distance)
              _buildSummarySection('Distance & Rewards', Icons.star, [
                '📏 Total Distance: ${totalKm.toStringAsFixed(1)} km',
                '⭐ Total Reward: ${totalReward.toStringAsFixed(0)} points',
              ]),
              const SizedBox(height: 12),

              // Days
              _buildSummarySection('Working Days', Icons.calendar_today, [
                '📅 ${sortedDays.join(', ')}',
              ]),
              const SizedBox(height: 12),

              // Time
              _buildSummarySection('Departure Time', Icons.access_time, [
                '🕐 ${_departureTime.format(context)}',
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showPayloadPreview(routeData),
                icon: const Icon(Icons.preview, color: Color(0xFF00B4D8)),
                label: const Text(
                  'Preview API Payload (Temp)',
                  style: TextStyle(color: Color(0xFF00B4D8)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00B4D8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPayloadPreview(_Step2Data? routeData) async {
    final totalDistance = routeData?.totalKm ?? 0.0;
    final seats = int.tryParse(_seatsController.text.trim()) ?? 1;
    final pricePerUnit =
        double.tryParse(_pricePerUnitController.text.trim()) ?? _rewardPerKm;
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final tripTime =
        '${_departureTime.hour.toString().padLeft(2, '0')}:${_departureTime.minute.toString().padLeft(2, '0')}:00';
    final tripTitle = _tripTitleController.text.trim().isNotEmpty
        ? _tripTitleController.text.trim()
        : 'Ride: ${startPoint.label} -> ${endPoint.label}';

    final previewPayload = {
      'cat_id': 201,
      'trip_title': tripTitle,
      'seats_available': seats < 1 ? 1 : seats,
      'measurement_type': _measurementType,
      'total_distance': double.parse(totalDistance.toStringAsFixed(2)),
      'price_per_seat_mu': double.parse(pricePerUnit.toStringAsFixed(2)),
      'is_active': _isTripActive,
      'is_recurring': _isRecurring,
      'trip_time': tripTime,
      'days_of_week': _selectedDays.toList(),
      'start_date': fmtDate(now),
      'end_date': fmtDate(endDate),
      'trip_route_stops_note':
          'Will be sent when backend endpoint for trip_route_stops is available',
    };

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        title: const Text('Payload Preview',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            previewPayload.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF00B4D8))),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, IconData icon, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00B4D8), size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF00B4D8),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(item,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              )),
        ],
      ),
    );
  }
}

// ─── Leg Info Model ─────────────────────────────────────────────────────────

class _LegInfo {
  final String from;
  final String to;
  final double distanceKm;
  final double rewardPoints;

  _LegInfo({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.rewardPoints,
  });
}

class _RouteMetrics {
  final double distanceKm;
  final List<LatLng> polylinePoints;
  _RouteMetrics({required this.distanceKm, required this.polylinePoints});
}

class _Step2Data {
  final List<_LegInfo> legs;
  final List<LatLng> fullPolyline;
  final double totalKm;
  final double totalReward;
  _Step2Data({
    required this.legs,
    required this.fullPolyline,
    required this.totalKm,
    required this.totalReward,
  });
}
