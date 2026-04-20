import 'package:dio/dio.dart';

void main() async {
  var dio = Dio();
  try {
    var response = await dio.get('https://api.aidme.online/api/sponsors');
    List data = response.data['data'] ?? response.data;
    if (data.isEmpty) return;
    String rawPath = data.last['imag1_photo'].toString();
    print('Raw path: $rawPath');

    // Normalize rawPath if it starts with /
    if (rawPath.startsWith('/')) rawPath = rawPath.substring(1);

    // Just a file name?
    var fileName = rawPath.split('/').last;

    var prefixes = [
      'https://api.aidme.online/',
      'https://api.aidme.online/public/',
      'http://161.35.51.188:5001/',
      'http://161.35.51.188:5001/public/',
      'https://api.aidme.online/api/',
    ];

    for (var prefix in prefixes) {
      // test with raw path
      var url1 = "\${prefix}\${rawPath}";
      try {
        var r = await dio.get(url1);
        print('SUCCESS: $url1 (Status ${r.statusCode})');
      } catch (e) {}

      // test with filename only
      var url2 = "\${prefix}uploads/\${fileName}";
      try {
        var r = await dio.get(url2);
        print('SUCCESS: $url2 (Status ${r.statusCode})');
      } catch (e) {}
    }
  } catch (e) {
    print('error: $e');
  }
}
