import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final endpoints = [
    'https://api.aidme.online/api/login',
    'https://api.aidme.online/api/admin/login',
    'https://admin.aidme.online/api/login'
  ];

  for (var url in endpoints) {
    try {
      print('\\nTesting POST \$url');
      final response = await dio.post(url, data: {
        'username': 'ts2025',
        'email': 'ts2025',
        'password': '123456'
      });
      print('Status: \${response.statusCode}');
      print('Data: \${response.data}');
    } catch (e) {
      if (e is DioException) {
        print('Failed \${e.response?.statusCode}: \${e.response?.data}');
      } else {
        print('Error: \$e');
      }
    }
  }
}
