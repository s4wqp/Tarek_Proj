import 'package:tarek_proj/data/web_services/web_services.dart';

void main() async {
  final api = WebServices();
  // Get token by logging in
  final token = await api.loginUserForToken(
      'testuser@example.com', 'password123'); // or maybe use an existing one?
  // Let's just fetch trips using admin or mock it, we can hit it directly since we saw the code
  // Wait, I see login logic in WebServices for "ts2025" and "123456" for admin token.
  // Let's just do a dio request directly like admin logging in.
}
