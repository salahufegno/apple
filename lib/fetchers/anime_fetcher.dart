import 'dart:convert';
import 'package:apple/globals.dart';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchAnimes(dynamic animeName) async {
  final progress = logger.progress('Searching $animeName anime'); // Log fetching animes
  final response = await http.get(Uri.parse('$baseUrl/search?q=$animeName&page=1'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final animes = data['data']['animes'].toList();
    progress.complete('Fetched ${animes.length} animes.'); // Log number of animes fetched
    return animes;
  } else {
    progress.fail('Coudn\'t find $animeName'); // Log error
    return [];
  }
}
