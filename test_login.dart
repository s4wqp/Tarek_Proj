import 'package:dio/dio.dart';

void main() async {
  try {
    var dio = Dio();
    print("Testing admin login...");
    var resp1 = await dio.post('http://161.35.51.188:5001/api/auth/login',
        data: {"uname": "ts2025", "password": "123456"});
    print("Admin login: ${resp1.statusCode}");

    print("Testing user aa2026 login...");
    var resp2 =
        await dio.post('http://161.35.51.188:5001/api/auth/login', data: {
      "uname": "aa2026",
      "password":
          "123" // Just guessing a simple password, or we can just see the error.
    });
    print("User login: ${resp2.statusCode} - ${resp2.data}");
  } catch (e) {
    if (e is DioException) {
      print("Error: ${e.response?.statusCode} - ${e.response?.data}");
    } else {
      print("Error: $e");
    }
  }
}
