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
    {"username": "ts2025", "password": "123456"},
    {"email": "admin", "password": "123456"},
    {"user_name": "ts2025", "user_password": "123456"},
  ];

  for (var p in payloads) {
    print("\\nTesting payload: " + p.toString());
    try {
      Response loginResp = await dio.post('auth/login', data: p);
      print("Status: " + loginResp.statusCode.toString());
      print("Data: " + loginResp.data.toString());
      return; // Stop on success
    } catch (e) {
      if (e is DioException) {
        print("Error: " + (e.response?.data.toString() ?? "null"));
      }
    }
  }
}
