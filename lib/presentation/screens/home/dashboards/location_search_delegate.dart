import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:tarek_proj/presentation/screens/home/dashboards/ride_dashboard.dart'; // To get RoutePoint
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:tarek_proj/config/app_secrets.dart';

class LocationSearchDelegate extends SearchDelegate<RoutePoint?> {
  final Dio _dio = Dio();
  final String? countryCode;
  final String? countryName;

  LocationSearchDelegate({this.countryCode, this.countryName});

  @override
  String get searchFieldLabel => 'Search for a location...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1B2A),
        elevation: 0,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0E21),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white70),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SuggestionDisplay(
      searchQuery: query,
      dio: _dio,
      onSelected: (point) => close(context, point),
      countryCode: countryCode,
      countryName: countryName,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SuggestionDisplay(
      searchQuery: query,
      dio: _dio,
      onSelected: (point) => close(context, point),
      countryCode: countryCode,
      countryName: countryName,
    );
  }
}

class _SuggestionDisplay extends StatefulWidget {
  final String searchQuery;
  final Dio dio;
  final ValueChanged<RoutePoint> onSelected;
  final String? countryCode;
  final String? countryName;

  const _SuggestionDisplay({
    required this.searchQuery,
    required this.dio,
    required this.onSelected,
    this.countryCode,
    this.countryName,
  });

  @override
  State<_SuggestionDisplay> createState() => _SuggestionDisplayState();
}

class _SuggestionDisplayState extends State<_SuggestionDisplay> {
  static const String _googlePlacesApiKey = AppSecrets.googleMapsApiKey;

  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;
  String _googleSessionToken = '';

  @override
  void initState() {
    super.initState();
    _handleSearch();
  }

  @override
  void didUpdateWidget(_SuggestionDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _handleSearch();
    }
  }

  void _handleSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (widget.searchQuery.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    if (_googleSessionToken.isEmpty) {
      _googleSessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final suggestions = _googlePlacesApiKey.isNotEmpty
            ? await _fetchGoogleAutocomplete(widget.searchQuery.trim())
            : await _fetchNominatimSuggestions(widget.searchQuery.trim());

        if (!mounted) return;
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchGoogleAutocomplete(
      String query) async {
    try {
      final primary = await _callGoogleAutocomplete(query);
      if (primary.length >= 5 || !query.contains(' ')) {
        return _rankGoogleSuggestions(primary, query);
      }

      // If exact phrase is too restrictive, broaden the phrase to increase
      // useful matches similar to Google Maps UI behavior.
      final words = query.split(' ');
      final broaderQuery = words.take(words.length - 1).join(' ').trim();
      if (broaderQuery.isEmpty) {
        return _rankGoogleSuggestions(primary, query);
      }

      final secondary = await _callGoogleAutocomplete(broaderQuery);
      final arabicVariants = _buildArabicQueryVariants(query);
      final variantResults = <Map<String, dynamic>>[];
      for (final variant in arabicVariants) {
        final results = await _callGoogleAutocomplete(variant);
        variantResults.addAll(results);
      }

      final merged = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      for (final item in [...primary, ...secondary, ...variantResults]) {
        final id = (item['place_id'] ?? '').toString();
        if (id.isEmpty || seenIds.contains(id)) continue;
        seenIds.add(id);
        merged.add(item);
      }
      return _rankGoogleSuggestions(merged, query);
    } catch (_) {}

    // Reliable fallback in case key/quota/network issues happen.
    return _fetchNominatimSuggestions(query);
  }

  Future<List<Map<String, dynamic>>> _callGoogleAutocomplete(String query) async {
    final response = await widget.dio.get(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: {
        'input': query,
        'key': _googlePlacesApiKey,
        'language': 'ar',
        'sessiontoken': _googleSessionToken,
        'region': (widget.countryCode ?? '').toLowerCase(),
        if ((widget.countryCode ?? '').isNotEmpty)
          'components': 'country:${widget.countryCode!.toLowerCase()}',
      },
    );

    if (response.statusCode != 200) return [];
    final data = response.data as Map<String, dynamic>? ?? {};
    final status = (data['status'] ?? '').toString();
    final predictions = data['predictions'] as List<dynamic>? ?? [];
    // If Google denies the request (bad key, restrictions, billing, quota, etc.)
    // throw so the caller falls back to Nominatim instead of showing an empty list.
    if (status != 'OK') {
      final errorMessage = (data['error_message'] ?? '').toString();
      throw Exception('Google autocomplete failed: $status $errorMessage');
    }
    if (predictions.isEmpty) return [];

    return predictions.map<Map<String, dynamic>>((p) {
      final item = p as Map<String, dynamic>;
      final formatting = item['structured_formatting'] as Map<String, dynamic>? ?? {};
      final types = (item['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      return {
        'source': 'google',
        'place_id': (item['place_id'] ?? '').toString(),
        'name':
            (formatting['main_text'] ?? item['description'] ?? 'Unknown place')
                .toString(),
        'display_name': (item['description'] ?? '').toString(),
        'secondary_text': (formatting['secondary_text'] ?? '').toString(),
        'types': types,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _rankGoogleSuggestions(
      List<Map<String, dynamic>> items, String query) {
    final q = query.trim().toLowerCase();
    int score(Map<String, dynamic> item) {
      int s = 0;
      final name = (item['name'] ?? '').toString().toLowerCase();
      final display = (item['display_name'] ?? '').toString().toLowerCase();
      final types = (item['types'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      if (name.startsWith(q)) s += 120;
      if (display.startsWith(q)) s += 90;
      if (name.contains(q)) s += 55;
      if (display.contains(q)) s += 30;

      if (types.contains('street_address') || types.contains('route')) s += 22;
      if (types.contains('establishment') || types.contains('point_of_interest')) {
        s += 18;
      }
      if (types.contains('locality') || types.contains('sublocality')) s += 12;
      return s;
    }

    items.sort((a, b) => score(b).compareTo(score(a)));
    return items.take(25).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNominatimSuggestions(
      String query) async {
    final response = await widget.dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': _buildCountryScopedQuery(query),
        'format': 'json',
        'addressdetails': 1,
        'limit': 40,
        'namedetails': 1,
        'dedupe': 1,
        if ((widget.countryCode ?? '').isNotEmpty)
          'countrycodes': widget.countryCode!.toLowerCase(),
      },
      options: Options(
        headers: {
          'User-Agent': 'PowerPulseApp/1.0',
          'Accept-Language': 'ar,en',
        },
      ),
    );

    if (response.statusCode != 200) return [];
    final List<dynamic> data = response.data as List<dynamic>;
    final normalized = _normalizeSuggestions(data);

    if (normalized.isNotEmpty || !query.contains(' ')) return normalized;

    // Broader fallback query when user typed a long phrase.
    final words = query.split(' ');
    final broaderQuery = words.take(words.length - 1).join(' ');
    if (broaderQuery.isEmpty) return normalized;

    final fallbackResponse = await widget.dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': _buildCountryScopedQuery(broaderQuery),
        'format': 'json',
        'addressdetails': 1,
        'limit': 30,
        'namedetails': 1,
        if ((widget.countryCode ?? '').isNotEmpty)
          'countrycodes': widget.countryCode!.toLowerCase(),
      },
      options: Options(
        headers: {
          'User-Agent': 'PowerPulseApp/1.0',
          'Accept-Language': 'ar,en',
        },
      ),
    );

    if (fallbackResponse.statusCode != 200) return normalized;
    final fallbackData = fallbackResponse.data as List<dynamic>? ?? [];
    final broaderResults = _normalizeSuggestions(fallbackData);
    if (broaderResults.isNotEmpty) return broaderResults;

    // Last fallback for Arabic colloquial phrasing (e.g., "اول مكرم").
    final variants = _buildArabicQueryVariants(query);
    for (final variant in variants) {
      final variantResponse = await widget.dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': _buildCountryScopedQuery(variant),
          'format': 'json',
          'addressdetails': 1,
          'limit': 30,
          'namedetails': 1,
          if ((widget.countryCode ?? '').isNotEmpty)
            'countrycodes': widget.countryCode!.toLowerCase(),
        },
        options: Options(
          headers: {
            'User-Agent': 'PowerPulseApp/1.0',
            'Accept-Language': 'ar,en',
          },
        ),
      );
      if (variantResponse.statusCode != 200) continue;
      final variantData = variantResponse.data as List<dynamic>? ?? [];
      final variantNormalized = _normalizeSuggestions(variantData);
      if (variantNormalized.isNotEmpty) return variantNormalized;
    }

    return broaderResults;
  }

  String _buildCountryScopedQuery(String query) {
    final trimmed = query.trim();
    final country = (widget.countryName ?? '').trim();
    if (country.isEmpty) return trimmed;

    final lowerQuery = trimmed.toLowerCase();
    final lowerCountry = country.toLowerCase();
    if (lowerQuery.contains(lowerCountry)) return trimmed;
    return '$trimmed, $country';
  }

  List<String> _buildArabicQueryVariants(String query) {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final variants = <String>{};
    variants.add(q.replaceAll('اول', 'أول'));
    variants.add(q.replaceAll('شارع ', ''));
    variants.add('شارع $q');

    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      final reversed = words.reversed.join(' ');
      variants.add(reversed);
    }

    variants.remove(q);
    variants.removeWhere((v) => v.trim().isEmpty);
    return variants.toList();
  }

  bool _matchesCountry(Map<String, dynamic> item) {
    final code = (widget.countryCode ?? '').trim().toLowerCase();
    final countryName = (widget.countryName ?? '').trim().toLowerCase();
    if (code.isEmpty && countryName.isEmpty) return true;

    final address = item['address'] is Map
        ? Map<String, dynamic>.from(item['address'] as Map)
        : <String, dynamic>{};

    final countryCodeFromAddress =
        (address['country_code'] ?? item['country_code'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (code.isNotEmpty && countryCodeFromAddress.isNotEmpty) {
      return countryCodeFromAddress == code;
    }

    final haystack = [
      item['display_name'],
      item['secondary_text'],
      address['country'],
      address['state'],
    ].map((e) => (e ?? '').toString().toLowerCase()).join(' | ');

    for (final token in _countryTokens(countryName, code)) {
      if (token.isNotEmpty && haystack.contains(token)) return true;
    }
    return false;
  }

  Set<String> _countryTokens(String name, String code) {
    final tokens = <String>{name};
    const aliases = <String, List<String>>{
      'eg': ['egypt', 'مصر'],
      'sa': ['saudi arabia', 'ksa', 'السعودية', 'المملكة العربية السعودية'],
      'ae': ['united arab emirates', 'uae', 'الإمارات', 'الامارات'],
      'kw': ['kuwait', 'الكويت'],
      'qa': ['qatar', 'قطر'],
      'bh': ['bahrain', 'البحرين'],
      'om': ['oman', 'عمان'],
      'jo': ['jordan', 'الأردن', 'الاردن'],
      'lb': ['lebanon', 'لبنان'],
      'us': ['united states', 'usa', 'us', 'الولايات المتحدة'],
      'gb': ['united kingdom', 'uk', 'britain', 'المملكة المتحدة'],
    };

    if (aliases.containsKey(code)) {
      tokens.addAll(aliases[code]!);
    }
    if (name.isNotEmpty) {
      for (final entry in aliases.entries) {
        if (entry.value.contains(name)) {
          tokens.add(entry.key);
          tokens.addAll(entry.value);
        }
      }
    }
    tokens.removeWhere((t) => t.trim().isEmpty);
    return tokens;
  }

  Future<RoutePoint?> _resolveGooglePlaceToRoutePoint(
      Map<String, dynamic> place) async {
    final placeId = (place['place_id'] ?? '').toString();
    if (placeId.isEmpty) return null;

    final response = await widget.dio.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      queryParameters: {
        'place_id': placeId,
        'key': _googlePlacesApiKey,
        'language': 'ar',
        'fields': 'name,formatted_address,geometry/location',
      },
    );

    if (response.statusCode != 200) return null;
    final data = response.data as Map<String, dynamic>? ?? {};
    if ((data['status'] ?? '').toString() != 'OK') return null;

    final result = data['result'] as Map<String, dynamic>? ?? {};
    final geometry = result['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final label = (result['name'] ?? place['name'] ?? '').toString();
    return RoutePoint(label: label, latLng: LatLng(lat, lng));
  }

  List<Map<String, dynamic>> _normalizeSuggestions(List<dynamic> rawItems) {
    final queryLower = widget.searchQuery.trim().toLowerCase();
    final seen = <String>{};
    final parsed = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (!_matchesCountry(item)) continue;
      final displayName = (item['display_name'] ?? '').toString().trim();
      final lat = (item['lat'] ?? '').toString();
      final lon = (item['lon'] ?? '').toString();
      if (displayName.isEmpty || lat.isEmpty || lon.isEmpty) continue;

      final uniqueKey = '$displayName|$lat|$lon';
      if (seen.contains(uniqueKey)) continue;
      seen.add(uniqueKey);
      parsed.add(item);
    }

    int scoreFor(Map<String, dynamic> item) {
      final display = (item['display_name'] ?? '').toString().toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final type = (item['type'] ?? '').toString().toLowerCase();
      final klass = (item['class'] ?? '').toString().toLowerCase();
      int score = 0;

      if (name.startsWith(queryLower)) score += 200;
      if (display.startsWith(queryLower)) score += 120;
      if (name.contains(queryLower)) score += 70;
      if (display.contains(queryLower)) score += 40;
      if (klass == 'place' || type == 'city' || type == 'town') score += 12;

      final importance = double.tryParse((item['importance'] ?? '0').toString());
      if (importance != null) score += (importance * 100).round();
      return score;
    }

    parsed.sort((a, b) => scoreFor(b).compareTo(scoreFor(a)));
    return parsed.take(25).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00B4D8)));
    }

    if (_suggestions.isEmpty) {
      if (widget.searchQuery.trim().isEmpty) {
        return const Center(
          child: Text(
            'Type a location...',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Keep typing for more specific locations or check your spelling...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final place = _suggestions[index];
        final displayName = (place['display_name'] ?? '').toString();

        final addressDetails = place['address'] ?? {};

        // Improve name selection:
        // 1. Specific place name (KFC, etc.)
        // 2. Road/Street
        // 3. Suburb/Neighborhood
        // 4. First part of display_name
        String name = place['name']?.toString() ?? "";
        if (name.isEmpty) {
          name = addressDetails['road']?.toString() ??
              addressDetails['suburb']?.toString() ??
              addressDetails['neighbourhood']?.toString() ??
              displayName.split(',').first;
        }

        return ListTile(
          leading: const Icon(Icons.location_on, color: Color(0xFF00B4D8)),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            (place['source'] == 'google' &&
                    (place['secondary_text'] ?? '').toString().isNotEmpty)
                ? (place['secondary_text'] ?? '').toString()
                : displayName,
            style: const TextStyle(color: Colors.white54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            if (place['source'] == 'google') {
              try {
                final resolved = await _resolveGooglePlaceToRoutePoint(place);
                if (!mounted || resolved == null) return;
                _googleSessionToken = '';
                widget.onSelected(resolved);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open this location right now.'),
                  ),
                );
              }
              return;
            }

            final lat = double.tryParse(place['lat']?.toString() ?? '');
            final lon = double.tryParse(place['lon']?.toString() ?? '');
            if (lat == null || lon == null) return;

            widget.onSelected(
              RoutePoint(
                label: name,
                latLng: LatLng(lat, lon),
              ),
            );
          },
        );
      },
    );
  }
}
