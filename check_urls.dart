import 'package:dio/dio.dart';

void main() async {
  var dio = Dio();
  var urlsToTest = [
    'https://api.aidme.online/public/uploads/1774626000087_out1774626645023.jpg',
    'https://api.aidme.online/uploads/1774626000087_out1774626645023.jpg',
    'http://161.35.51.188:5001/public/uploads/1774626000087_out1774626645023.jpg',
    'http://161.35.51.188:5001/uploads/1774626000087_out1774626645023.jpg',
  ];

  for (var url in urlsToTest) {
    try {
      var res = await dio.get(url);
      print('=== SUCCESS: $url (Status ${res.statusCode}) ===');
    } catch (e) {
      // ignore
    }
  }
}
