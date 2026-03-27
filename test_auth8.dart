import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final urls = [
    'https://api.aidme.online/api/auth/login',
    'http://161.35.51.188:5001/api/auth/login'
  ];

  for (var url in urls) {
    try {
      print("\\nTesting POST \$url");
      Response loginResp =
          await dio.post(url, data: {"uname": "ts2025", "password": "123456"});
      print("Status: \${loginResp.statusCode}");
      print("Data: \${loginResp.data}");

      String token = loginResp.data['token'];
      print("Got Token: \$token");

      // Test GET users
      Response getResp = await dio.get(
          url.replaceFirst('/auth/login', '/users'),
          options: Options(headers: {"Authorization": "Bearer \$token"}));
      print("Users fetch status: \${getResp.statusCode}");
      print("Users returned: \${(getResp.data['data'] as List).length}");
      break;
    } catch (e) {
      if (e is DioException) {
        print("Error: \${e.response?.statusCode} - \${e.response?.data}");
      } else {
        print("Error: \$e");
      }
    }
  }
}
