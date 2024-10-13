import 'package:apple/fetchers/anime_fetcher.dart';
import 'package:apple/globals.dart';

Future<({dynamic animeId, dynamic animeName})> searchAnimeWorker() async {
  final animeName = logger.prompt('Search anime :');

  final animes = await fetchAnimes(animeName);

  if (animes.isEmpty) {
    return searchAnimeWorker();
  }

  final selectedAnimeName = logger.chooseOne(
    'Select anime :',
    choices: [
      ...animes.map((e) => '${e['name'] ?? ''} - ${e['episodes']['dub']} episodes'),
    ],
  );

  final selectedAnime = animes.firstWhere((e) => e['name'] == selectedAnimeName.split(' - ').first);

  return (animeId: selectedAnime['id'], animeName: selectedAnime['name']);
}
