import 'dart:convert';
import 'package:apple/globals.dart';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchEpisodes(
  String animeId,
) async {
  final progress = logger.progress('Fetching episodes for anime ID: $animeId'); // Log fetching episodes
  final response = await http.get(Uri.parse('$baseUrl/anime/$animeId/episodes'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final episodes = data['data']['episodes'].where((anime) => !anime['isFiller']).toList();
    progress.complete('Fetched ${episodes.length} episodes.'); // Log number of episodes fetched
    return episodes;
  } else {
    progress.fail('Failed to fetch episodes for anime ID: $animeId'); // Log error
    return [];
  }
}
