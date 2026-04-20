import 'package:tarek_proj/data/web_services/web_services.dart';
void main() async {
  final api = WebServices();
  // Fetch trips or stops
  final stops = await api.getAllStops();
  print(stops);
}
