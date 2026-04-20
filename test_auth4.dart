import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";
  dio.options.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final payloads = [
    {"user_name": "admin", "user_password": "123456"},
    {"username": "admin", "password": "123456"},
    {"email": "admin", "password": "123456"},
    {"email": "ts2025", "password": "123456"},
    {"username": "ts2025", "password": "123456"},
    {"email": "admin@gmail.com", "password": "123456"},
  ];

  for (var p in payloads) {
    print("\\n--- Testing payload: $p");
    try {
      Response loginResp = await dio.post('auth/login', data: p);
      print("Status: ${loginResp.statusCode}");
      print("Data: ${loginResp.data}");
    } catch (e) {
      if (e is DioException) {
        print("Error: ${e.response?.data.toString() ?? "null"}");
      }
    }
  }
}
