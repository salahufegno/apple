import 'dart:convert';
import 'package:apple/globals.dart';
import 'package:http/http.dart' as http;

Future<List<dynamic>> fetchEpisodeServers(
  String episodeId,
) async {
  final response = await http.get(Uri.parse('$baseUrl/episode/servers?animeEpisodeId=$episodeId'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['data']['dub'];
  } else {
    throw 'Failed to fetch servers for episode ID: $episodeId'; // Log error
  }
}
