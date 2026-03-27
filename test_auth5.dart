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
    {"userName": "admin", "userPassword": "123456"},
    {"user_email": "ts2025", "user_password": "123456"},
  ];

  for (var p in payloads) {
    try {
      Response loginResp = await dio.post('auth/login', data: p);
      if (loginResp.statusCode == 200) {
        print("SUCCESS PAYLOAD: " + p.toString());
        print("TOKEN: " + loginResp.data.toString());
        return;
      }
    } catch (e) {
      // ignore errors
    }
  }
  print("ALL PAYLOADS FAILED");
}
