import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";

  final testCases = [
    {"user_name": "admin", "user_password": "123456"},
    {"UserName": "admin", "Password": "123456"},
    {"user_name": "ts2025", "user_password": "123456"}
  ];

  for (var headers in [
    Headers.jsonContentType,
    Headers.formUrlEncodedContentType
  ]) {
    for (var p in testCases) {
      print("\\n--- Testing config: \$headers with payload \$p");
      try {
        Response loginResp = await dio.post('auth/login',
            data: p, options: Options(contentType: headers));
        print("Status: \${loginResp.statusCode}");
        print("Data: \${loginResp.data}");
        return; // Stop on success
      } catch (e) {
        if (e is DioException) {
          print("Error: \${e.response?.data}");
        }
      }
    }
  }
}
