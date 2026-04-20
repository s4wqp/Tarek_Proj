import 'package:dio/dio.dart';

/// Comprehensive test for ALL endpoints across both base URLs.
/// Run: dart run test_all_endpoints.dart
void main() async {
  final urls = [
    'https://api.aidme.online/api',
    'http://161.35.51.188:5001/api',
  ];

  for (final baseUrl in urls) {
    final dio = Dio()
      ..options.baseUrl = '$baseUrl/'
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 30);

    print('');
    print('=' * 60);
    print('  TESTING: $baseUrl');
    print('=' * 60);

    // --- SPONSORS ---
    await _test(dio, 'GET', 'sponsors', 'List sponsors');
    await _test(dio, 'GET', 'sponsors/1', 'Get sponsor #1');
    await _test(dio, 'GET', 'sponsors/search?q=test&field=sponsor_name',
        'Search sponsors');

    // --- STOPS ---
    await _test(dio, 'GET', 'stops', 'List stops');
    await _test(dio, 'GET', 'stops/1', 'Get stop #1');
    await _test(dio, 'GET', 'stops/search/cairo', 'Search stops');
    await _test(dio, 'GET', 'stops/locations/distinct', 'Distinct locations');
    await _test(dio, 'GET', 'stops/coordinates/1', 'Stop coordinates #1');

    // --- TRIPS (need auth) ---
    // Try to get a token first
    String? token;
    try {
      final loginRes = await Dio().post(
        '$baseUrl/auth/login',
        data: {"uname": "ts2025", "password": "123456"},
      );
      token = loginRes.data?['token'] ?? loginRes.data?['accessToken'];
      print(
          '\n  AUTH: Got token = ${token != null ? "YES (${token.substring(0, 10)}...)" : "NO"}');
    } catch (e) {
      print('\n  AUTH: Login failed - $e');
    }

    final authOpts = token != null
        ? Options(headers: {"Authorization": "Bearer $token"})
        : null;

    await _test(dio, 'GET', 'trips/my', 'My trips', opts: authOpts);
    await _test(dio, 'GET', 'trips/upcoming', 'Upcoming trips', opts: authOpts);
    await _test(dio, 'GET', 'trips/stats/summary', 'Trip stats',
        opts: authOpts);
    await _test(dio, 'GET', 'trips/1', 'Get trip #1', opts: authOpts);
    await _test(dio, 'GET', 'trips/1/schedule', 'Trip #1 schedule',
        opts: authOpts);
    await _test(dio, 'GET', 'trips/1/route', 'Trip #1 route', opts: authOpts);
  }

  print('\n${"=" * 60}');
  print('  ALL TESTS COMPLETE');
  print('=' * 60);
}

Future<void> _test(Dio dio, String method, String path, String label,
    {Options? opts}) async {
  try {
    Response res;
    if (method == 'GET') {
      res = await dio.get(path, options: opts);
    } else {
      res = await dio.post(path, options: opts);
    }

    // Summarize data
    String dataSummary;
    if (res.data is List) {
      dataSummary = 'List[${(res.data as List).length}]';
    } else if (res.data is Map) {
      final map = res.data as Map;
      if (map.containsKey('data') && map['data'] is List) {
        dataSummary = 'List[${(map['data'] as List).length}]';
      } else {
        dataSummary = 'Map{${map.keys.take(5).join(", ")}}';
      }
    } else {
      dataSummary = '${res.data}';
    }

    print('  ✅ $label ($method /$path) → ${res.statusCode} | $dataSummary');
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 'N/A';
    print('  ❌ $label ($method /$path) → $code');
  } catch (e) {
    print('  ❌ $label ($method /$path) → ERROR: $e');
  }
}
