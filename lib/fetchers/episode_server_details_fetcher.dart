import 'dart:convert';
import 'package:apple/globals.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchEpisodeServerDetails(
  String episodeId,
  String serverName,
) async {
  final response = await http.get(Uri.parse('$baseUrl/episode/sources?animeEpisodeId=$episodeId&server=$serverName&category=dub'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['success'] ? data['data'] : {};
  } else {
    return {};
  }
}
