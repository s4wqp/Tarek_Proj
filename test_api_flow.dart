import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.validateStatus = (status) => true;

  try {
    print('1. Registering user...');
    final userRes = await dio.post('http://161.35.51.188:5001/api/users', data: {
      'user_name': 'testsponsor123',
      'user_email': 'testsponsor123@test.com',
      'password': 'StrongPass123!',
      'user_tel_no': '01012345678',
      'user_f_name': 'Test',
      'user_l_name': 'Sponsor',
      'statu': 1
    });
    print('User Reg: ${userRes.statusCode} ${userRes.data}');

    print('2. Logging in...');
    final loginRes = await dio.post('http://161.35.51.188:5001/api/auth/login', data: {
      'uname': 'testsponsor123',
      'password': 'StrongPass123!'
    });
    print('Login: ${loginRes.statusCode} ${loginRes.data}');
    
    if (loginRes.statusCode != 200) return;
    
    final token = loginRes.data['token'];

    print('3. Registering sponsor...');
    final sponsorRes = await dio.post('http://161.35.51.188:5001/api/sponsors/register', 
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      data: {
        'sponsor_name': 'Test Sponsor Inc',
        'sponsor_cat': 'Gym'
      }
    );
    print('Sponsor Reg: ${sponsorRes.statusCode} ${sponsorRes.data}');
  } catch(e) {
    print('Error: $e');
  }
}
