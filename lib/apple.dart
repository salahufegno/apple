import 'package:apple/globals.dart';

import 'fetchers/fetchers.dart';
import 'workers/create_episodes_json_workers.dart';

Future<void> apple() async {
  const animeId = "naruto-shippuden-355";

  try {
    logger.info('Starting episode downloads for anime ID: $animeId'); // Log start of the process
    final episodes = await fetchEpisodes(animeId);

    // Download episodes in parallel, limiting to 'maxParallel' number of episodes at once
    for (var episode in episodes) {
      await createEpisodesJson([episode]);
    }

    logger.success('All episodes downloaded successfully!'); // Log final success
  } catch (error) {
    logger.err('An error occurred during downloads: $error'); // Log general error
  }
}
