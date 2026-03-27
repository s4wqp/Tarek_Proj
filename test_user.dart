import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final response = await dio.get('https://api.aidme.online/api/users');
    print(response.data);
  } on DioException catch (e) {
    print('Error: ${e.response?.statusCode}');
    print(e.response?.data);
  }
}
