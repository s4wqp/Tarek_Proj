import 'package:dio/dio.dart';

void main() async {
  var dio = Dio();
  try {
    var response = await dio.get('https://api.aidme.online/api/sponsors');
    List data = [];
    if (response.data is Map && response.data['data'] != null) {
      data = response.data['data'];
    } else if (response.data is List) {
      data = response.data;
    }

    int successCount = 0;
    for (var sponsor in data) {
      if (sponsor['imag1_photo'] != null) {
        String path = sponsor['imag1_photo'];
        if (path.startsWith('/')) path = path.substring(1);
        var url = "https://api.aidme.online/$path";
        try {
          var r = await dio.head(url);
          if (r.statusCode == 200) {
            print('SUCCESS: $url');
            successCount++;
          }
        } catch (e) {
          // ignore
        }
      }
    }
    print('Total images tested ok: $successCount');
  } catch (e) {
    print('error');
  }
}
