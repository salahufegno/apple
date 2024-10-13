import 'dart:convert';
import 'package:apple/globals.dart';
import 'package:http/http.dart' as http;

Future<({List<dynamic> episodes, bool skipFillers})> fetchEpisodes(
  String animeId,
) async {
  final skipFillers = logger.confirm('Do you want skip filler episodes ?'); // Asking skip filler episodes

  final progress = logger.progress('Fetching episodes for anime : $animeId'); // Log fetching episodes
  final response = await http.get(Uri.parse('$baseUrl/anime/$animeId/episodes'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    var episodes = data['data']['episodes'] as List;
    if (skipFillers) {
      episodes = episodes.where((anime) => !anime['isFiller']).toList();
    }
    progress.complete('Fetched ${episodes.length} episodes.'); // Log number of episodes fetched
    return (skipFillers: skipFillers, episodes: episodes);
  } else {
    progress.fail('Failed to fetch episodes for anime ID: $animeId'); // Log error
    return (skipFillers: skipFillers, episodes: []);
  }
}
