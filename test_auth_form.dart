import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";

  try {
    print("Sending POST auth/login with FormData...");
    Response loginResp = await dio.post('auth/login',
        data: FormData.fromMap(
            {"user_name": "admin", "user_password": "123456"}));

    print("Status: " + loginResp.statusCode.toString());
    print("Data: " + loginResp.data.toString());
  } catch (e) {
    if (e is DioException) {
      print("Error Status: " + (e.response?.statusCode.toString() ?? "null"));
      print("Error Data: " + (e.response?.data.toString() ?? "null"));
    } else {
      print("Error: " + e.toString());
    }
  }
}
