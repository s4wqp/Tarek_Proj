import 'package:dio/dio.dart';

/// Standalone script to test all 6 sponsor API endpoints.
/// Run: dart run test_sponsors_api.dart
void main() async {
  final dio = Dio()
    ..options.baseUrl = 'https://api.aidme.online/api/'
    ..options.connectTimeout = const Duration(seconds: 30)
    ..options.receiveTimeout = const Duration(seconds: 60);

  print('========================================');
  print('  SPONSORS API ENDPOINT TESTS');
  print('========================================\n');

  // 1. GET /api/sponsors — List all
  print('1) GET /api/sponsors (List All)');
  try {
    final res = await dio.get('sponsors');
    List data = [];
    if (res.data is Map && res.data['data'] != null) {
      data = res.data['data'];
    } else if (res.data is List) {
      data = res.data;
    }
    print('   Status: ${res.statusCode}');
    print('   Count : ${data.length}');
    if (data.isNotEmpty) {
      print('   First : ${data.first}');
    }
  } catch (e) {
    print('   ERROR: $e');
  }

  print('');

  // 2. GET /api/sponsors/:id — Get by ID
  print('2) GET /api/sponsors/1 (Get By ID)');
  try {
    final res = await dio.get('sponsors/1');
    print('   Status: ${res.statusCode}');
    print('   Data  : ${res.data}');
  } catch (e) {
    print('   ERROR: $e');
  }

  print('');

  // 3. POST /api/sponsors — Create (text fields only, no images)
  print('3) POST /api/sponsors (Create - text only)');
  try {
    final formData = FormData.fromMap({
      'firm_id': 1,
      'sponsor_cat': 'Test',
      'sponsor_name': 'API Test Sponsor',
      'Mangaer_name': 'Test Manager',
      'country': 'Egypt',
      'state': 'Cairo',
      'district': 'Maadi',
      'zip_code': '11728',
      'street_name': 'Test Street',
      'building_number': '10',
      'floor_number': '2',
      'Unit_number': '5',
      'Lead_mark': 'Near park',
      'Unit_latitude': 30.05,
      'Unit_lONGITUDE': 31.23,
      'sponsor_email': 'test_api@test.com',
      'sponsor_web_site': 'https://test.com',
      'sponsor_tel_no': '01012345678',
      'sponsor_whatsapp_no': '01012345678',
      'statu': 1,
      'sponsor_Reg_no': 12345,
    });
    final res = await dio.post('sponsors', data: formData);
    print('   Status: ${res.statusCode}');
    print('   Data  : ${res.data}');
  } catch (e) {
    print('   ERROR: $e');
  }

  print('');

  // 4. PUT /api/sponsors/1 — Update
  print('4) PUT /api/sponsors/1 (Update)');
  try {
    final formData = FormData.fromMap({
      'sponsor_name': 'Updated Sponsor Name',
    });
    final res = await dio.put('sponsors/1', data: formData);
    print('   Status: ${res.statusCode}');
    print('   Data  : ${res.data}');
  } catch (e) {
    print('   ERROR: $e');
  }

  print('');

  // 5. DELETE /api/sponsors/9999 — Delete (using high ID to avoid deleting real data)
  print('5) DELETE /api/sponsors/9999 (Delete - safe high ID)');
  try {
    final res = await dio.delete('sponsors/9999');
    print('   Status: ${res.statusCode}');
    print('   Data  : ${res.data}');
  } catch (e) {
    print('   ERROR: $e');
  }

  print('');

  // 6. GET /api/sponsors/search?q=test&field=sponsor_name — Search
  print('6) GET /api/sponsors/search?q=test&field=sponsor_name (Search)');
  try {
    final res = await dio.get('sponsors/search', queryParameters: {
      'q': 'test',
      'field': 'sponsor_name',
    });
    print('   Status: ${res.statusCode}');
    print('   Data  : ${res.data}');
  } catch (e) {
    print('   ERROR: $e');
  }

  print('\n========================================');
  print('  TESTS COMPLETE');
  print('========================================');
}
