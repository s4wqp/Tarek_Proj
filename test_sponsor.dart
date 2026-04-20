import 'package:dio/dio.dart';

void main() async {
  var dio = Dio(BaseOptions(
    baseUrl: 'https://api.aidme.online/api/',
    validateStatus: (s) => true,
  ));

  // Login to get token
  var loginRes = await dio
      .post('auth/login', data: {'uname': 'ts2025', 'password': '123456'});

  var token = '';
  if (loginRes.data is Map) {
    if (loginRes.data['token'] != null) {
      token = loginRes.data['token'];
    } else if (loginRes.data['data'] != null &&
        loginRes.data['data']['token'] != null) {
      token = loginRes.data['data']['token'];
    }
  }

  if (token.isEmpty) {
    print("Could not get token: ${loginRes.data}");
    return;
  }

  print("Got token: $token");
  dio.options.headers['Authorization'] = 'Bearer $token';

  var data = {
    "firm_id": 1,
    "sponsor_cat": "Other",
    "sponsor_name": "Test App Sponsor",
    "Mangaer_name": "App Manager",
    "country": "Egypt",
    "state": "Cairo",
    "district": "Maadi",
    "zip_code": "12345",
    "street_name": "Test St",
    "building_number": "10",
    "floor_number": "2",
    "Unit_number": "5",
    "Lead_mark": "Near Park",
    "Unit_latitude": 30.0,
    "Unit_lONGITUDE": 31.0,
    "sponsor_email": "test@test.com",
    "sponsor_web_site": "http://test.com",
    "sponsor_tel_no": "01012345678",
    "sponsor_whatsapp_no": "01012345678",
    "statu": 1,
    "sponsor_Reg_no": 12345
  };

  var formData = FormData.fromMap(data);
  print('Trying POST /sponsors');
  var res1 = await dio.post('sponsors', data: formData);
  print('Res1: ${res1.statusCode}\n${res1.data}');
}
