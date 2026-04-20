import 'dart:convert';
import 'lib/data/web_services/web_services.dart';

void main() async {
  final ws = WebServices();
  final user = await ws.getUserByEmail('yousef@gmail.com');
  print(jsonEncode(user));
}
