import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  const apiKey = 'K88039721588957';
  const endpoint = 'https://api.ocr.space/parse/imageurl';

  try {
    // Testing with a random URL of a license plate
    final formFields = {
      'apikey': apiKey,
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Egypt_license_plate_7047_-_%D8%AF_%D8%A8_%D9%82.jpg/800px-Egypt_license_plate_7047_-_%D8%AF_%D8%A8_%D9%82.jpg',
      'language': 'ara',
      'OCREngine': '1',
    };

    final response = await dio.post(
      endpoint,
      data: FormData.fromMap(formFields),
    );

    print("Status: ${response.statusCode}");
    print("Response: ${response.data}");
  } on DioException catch (e) {
    print("Error: ${e.response?.data ?? e}");
  } catch (e) {
    print("Error: $e");
  }
}
