import 'package:apple/globals.dart';
import 'package:apple/workers/workers.dart';

import 'fetchers/fetchers.dart';

Future<void> apple() async {
  try {
    logger.info('Welcome to apple'); // Log start of the process

    final searchedAnime = await searchAnimeWorker();

    logger.info('Starting episode downloads for anime: $searchedAnime'); // Log start of the process
    final episodes = await fetchEpisodes(searchedAnime.animeId);

    // Download episodes in parallel, limiting to 'maxParallel' number of episodes at once
    await createEpisodesJson(episodes.episodes, searchedAnime.animeName, episodes.skipFillers);

    // Download episodes
    await downloadEpisodes(searchedAnime.animeName, episodes.skipFillers);

    logger.success('All episodes downloaded successfully!'); // Log final success
  } catch (error) {
    logger.err('An error occurred during downloads: $error'); // Log general error
  }
}
