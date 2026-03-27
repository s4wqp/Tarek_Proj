import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";
  dio.options.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  try {
    print("Sending POST auth/login...");
    Response loginResp = await dio.post('auth/login',
        data: {"user_name": "admin", "user_password": "123456"});

    print("Status: \${loginResp.statusCode}");
    print("Data: \${loginResp.data}");
  } catch (e) {
    if (e is DioException) {
      print("Error Status: \${e.response?.statusCode}");
      print("Error Data: \${e.response?.data}");
    } else {
      print("Error: \$e");
    }
  }
}
