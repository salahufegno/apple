import 'dart:convert';
import 'dart:io';

import 'package:apple/fetchers/fetchers.dart';
import 'package:apple/globals.dart';

Future<void> createEpisodesJson(
  List<dynamic> episodes,
  dynamic animeName,
  bool skipFillers,
) async {
  final outputDir = Directory(animeFolder(animeName: animeName));

  final creatingJsonProgress = logger.progress('Checking $outputDir Available...'); // Log episode start

  var episodesData = <String, dynamic>{};

  if (!await outputDir.exists()) {
    creatingJsonProgress.update('Creating $outputDir'); // Log episode start
    await outputDir.create(recursive: true);
  }

  final jsonFilePath = animeJson(animeName: animeName, skipFillers: skipFillers);

  File jsonFile = File(jsonFilePath);

  creatingJsonProgress.update('Checking ${jsonFile.path} Available...'); // Log episode start

  // Check if the file exists; if not, create it
  if (!await jsonFile.exists()) {
    creatingJsonProgress.update('Creating ${jsonFile.path} json file');
    await jsonFile.create(recursive: true);
    await jsonFile.writeAsString('{}'); // Initialize with an empty JSON object
    creatingJsonProgress.update('Created ${jsonFile.path} json file.');
  } else {
    final overwrite = logger.confirm('\nDo you want overwrite data ?');

    if (!overwrite) {
      episodesData = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    }

    // Read the current data
  }

  creatingJsonProgress.cancel();

  for (var episode in episodes) {
    final episodeId = episode['episodeId'];
    final episodeTitle = episode['title'];
    final episodeNumber = episode['number'];

    final episodeProgress = logger.progress('Checking Already episode: $episodeNumber - $episodeTitle'); // Log episode start

    if (episodesData.containsKey('$episodeNumber')) {
      if (!episodesData['$episodeNumber']['has_error']) {
        episodeProgress.complete('Already Available episode: $episodeNumber - $episodeTitle');
        continue;
      }
    }

    episodeProgress.update('Fetching episode servers: $episodeNumber - $episodeTitle'); // Log episode start

    var servers = [];
    try {
      servers = (await fetchEpisodeServers(episodeId));
      // if (episodesData.isNotEmpty) {
        // if (episodesData['$episodeNumber'].isNotEmpty) {
        //   if (episodesData['$episodeNumber'].containsKey('used_servers')) {
        //     servers = servers.where((e) {
        //       return !(episodesData['$episodeNumber']['used_servers'] as List? ?? []).contains(e['serverName']);
        //     }).toList();
        //   }
        // }
      // }
      episodeProgress.update('Fetched episode servers: $episodeNumber - $episodeTitle');
    } catch (e) {
      episodeProgress.fail('Ep: $episodeNumber has $e');
      return;
    }
    bool episodeDownloaded = false;
    for (var server in servers) {
      episodeProgress.update('Fetching episode "${server['serverName']}" server details : $episodeNumber - $episodeTitle');
      final sourcesData = await fetchEpisodeServerDetails(episodeId, server['serverName']);
      if (sourcesData.isNotEmpty) {
        episodeProgress.update('Fetched episode "${server['serverName']}" server details : $episodeNumber - $episodeTitle');
        final sources = sourcesData['sources'];
        final m3u8Url = sources[0]['url'];
        final intro = sourcesData['intro'];
        final outro = sourcesData['outro'];

        if (intro != null && outro != null) {
          final introEnd = intro['end'];
          final outroStart = outro['start'];

          episodeProgress.update('Creating json data : $episodeNumber - $episodeTitle');

          episodesData['$episodeNumber'] = {
            'number': episodeNumber,
            'title': episodeTitle,
            'url': m3u8Url,
            'start': introEnd,
            'end': outroStart,
            'used_servers': [
              if (episodesData.isNotEmpty)
                if (episodesData['$episodeNumber'].isNotEmpty)
                  if (episodesData['$episodeNumber'].containsKey('used_servers')) ...?episodesData['$episodeNumber']['used_servers'],
              server['serverName'],
            ],
            'has_error': false,
          };

          episodeProgress.complete('Added json data : $episodeNumber - $episodeTitle');
          episodeDownloaded = true;
          break;
        }
      }
    }

    if (!episodeDownloaded) {
      episodeProgress.fail('Failed creating data : $episodeNumber - $episodeTitle');
    }
  }

  await jsonFile.writeAsString(jsonEncode(episodesData), flush: true);

  if (episodes.length == episodesData.entries.length) {
    creatingJsonProgress.complete('Successfully write ${episodesData.entries.length}/${episodes.length} data!'); // Log episode start
  } else {
    creatingJsonProgress.fail('Only Wrote ${episodesData.entries.length}/${episodes.length} data!'); // Log episode start
  }
}
