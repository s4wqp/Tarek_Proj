import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";

  try {
    Response loginResp = await dio
        .post('auth/login', data: {"user_name": "admin", "password": "123456"});
    print("Status: ${loginResp.statusCode}");
    print("Token: ${loginResp.data}");
  } catch (e) {
    if (e is DioException) {
      print("Error: ${e.response?.data.toString() ?? "null"}");
    }
  }
}
