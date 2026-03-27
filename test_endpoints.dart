import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  List<String> endpoints = [
    'https://api.aidme.online/api/user/redhode909@gmail.com',
    'https://api.aidme.online/api/status/redhode909@gmail.com',
    'https://api.aidme.online/api/check-status?email=redhode909@gmail.com',
    'https://api.aidme.online/api/users?email=redhode909@gmail.com'
  ];

  for (var url in endpoints) {
    try {
      print('Testing $url...');
      final response = await dio.get(url);
      print('Status: ${response.statusCode}');
      print('Data: ${response.data}');
    } on DioException catch (e) {
      print('Failed ${e.response?.statusCode}: ${e.response?.data}');
    }
  }
}
