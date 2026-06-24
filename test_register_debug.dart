import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(validateStatus: (s) => true));

  // 1. Login as admin
  print('1. Logging in...');
  final loginRes = await dio.post(
    'http://161.35.51.188:5001/api/auth/login',
    data: {"uname": "ts2025", "password": "123456"},
    options: Options(contentType: 'application/json'),
  );
  print('Login status: ${loginRes.statusCode}');
  print('Login body: ${loginRes.data}');
  
  final token = loginRes.data is Map ? (loginRes.data['token'] ?? loginRes.data['accessToken'] ?? '') : '';
  if (token.toString().isEmpty) {
    print('No token!');
    return;
  }
  print('Got token: ${token.toString().substring(0, 20)}...');

  final headers = {'Authorization': 'Bearer $token'};

  // Test A: sponsor_cat as name string "Restaurant" 
  print('\n--- Test A: sponsor_cat = "Restaurant" (name) ---');
  final resA = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: FormData.fromMap({
      'firm_id': 1,
      'sponsor_cat': 'Restaurant',
      'sponsor_name': 'TestA',
      'statu': 1,
      'sponsor_Reg_no': 0,
    }),
    options: Options(headers: headers),
  );
  print('Status: ${resA.statusCode} Body: ${resA.data}');

  // Test B: sponsor_cat as cat_id integer 801
  print('\n--- Test B: sponsor_cat = 801 (cat_id int) ---');
  final resB = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: FormData.fromMap({
      'firm_id': 1,
      'sponsor_cat': 801,
      'sponsor_name': 'TestB',
      'statu': 1,
      'sponsor_Reg_no': 0,
    }),
    options: Options(headers: headers),
  );
  print('Status: ${resB.statusCode} Body: ${resB.data}');

  // Test C: sponsor_cat as cat_id string "801"
  print('\n--- Test C: sponsor_cat = "801" (cat_id string) ---');
  final resC = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: FormData.fromMap({
      'firm_id': 1,
      'sponsor_cat': '801',
      'sponsor_name': 'TestC',
      'statu': 1,
      'sponsor_Reg_no': 0,
    }),
    options: Options(headers: headers),
  );
  print('Status: ${resC.statusCode} Body: ${resC.data}');

  // Test D: "Other" (worked in test_sponsor.dart on admin endpoint)
  print('\n--- Test D: sponsor_cat = "Other" ---');
  final resD = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: FormData.fromMap({
      'firm_id': 1,
      'sponsor_cat': 'Other',
      'sponsor_name': 'TestD',
      'statu': 1,
      'sponsor_Reg_no': 0,
    }),
    options: Options(headers: headers),
  );
  print('Status: ${resD.statusCode} Body: ${resD.data}');

  // Test E: JSON body instead of FormData
  print('\n--- Test E: JSON body with "Restaurant" ---');
  final resE = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: {
      'firm_id': 1,
      'sponsor_cat': 'Restaurant',
      'sponsor_name': 'TestE',
      'statu': 1,
      'sponsor_Reg_no': 0,
    },
    options: Options(headers: {...headers, 'Content-Type': 'application/json'}),
  );
  print('Status: ${resE.statusCode} Body: ${resE.data}');

  // Test F: JSON body with cat_id
  print('\n--- Test F: JSON body with cat_id 801 ---');
  final resF = await dio.post(
    'http://161.35.51.188:5001/api/sponsors/register',
    data: {
      'firm_id': 1,
      'sponsor_cat': 801,
      'sponsor_name': 'TestF',
      'statu': 1,
      'sponsor_Reg_no': 0,
    },
    options: Options(headers: {...headers, 'Content-Type': 'application/json'}),
  );
  print('Status: ${resF.statusCode} Body: ${resF.data}');
}
