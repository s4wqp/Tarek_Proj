import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = "https://api.aidme.online/api/";
  dio.options.headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String email = "redhode909@gmail.com";

  try {
    print("1. Authenticating as admin...");
    String token = "";
    try {
      Response loginResp = await dio.post('auth/login',
          data: {"user_name": "admin", "user_password": "123456"});

      print("Login response: \${loginResp.statusCode}");
      print("Login data: \${loginResp.data}");

      if (loginResp.statusCode == 200 && loginResp.data != null) {
        token = loginResp.data['accessToken'] ?? loginResp.data['token'] ?? "";
      }
    } catch (e) {
      if (e is DioException) {
        print(
            "Admin Login Error: \${e.response?.statusCode} - \${e.response?.data}");
      } else {
        print("Admin Login Error: \$e");
      }
      return;
    }

    if (token.isEmpty) {
      print("Error: No admin token received.");
      return;
    }
    print("Token received successfully.");

    print("2. Fetching users...");
    Response response = await dio.get(
      'users',
      options: Options(
        headers: {
          "Authorization": "Bearer \$token",
        },
      ),
    );

    print("Users fetched: \${response.statusCode}");
    List<dynamic> users = [];

    if (response.statusCode == 200) {
      if (response.data is Map && response.data.containsKey('data')) {
        users = response.data['data'];
      } else if (response.data is List) {
        users = response.data;
      }

      print("Total users parsed: \${users.length}");

      final validUsers = users.where((element) => element is Map).toList();
      print("Valid users (maps): \${validUsers.length}");

      final user = validUsers.firstWhere(
          (u) =>
              (u['user_email'] as String?)?.toLowerCase() ==
              email.toLowerCase(),
          orElse: () => null);

      if (user != null) {
        print("User found! Data: \$user");
        print("Status code: \${user['statu']}");
      } else {
        print("User email '\$email' not found in the list.");
        if (validUsers.isNotEmpty) {
          print("Sample user: \${validUsers.first}");
        }
      }
    }
  } catch (e) {
    if (e is DioException) {
      print(
          "Get User By Email Error: \${e.response?.statusCode} - \${e.response?.data}");
    } else {
      print("Get User By Email Error: \$e");
    }
  }
}
