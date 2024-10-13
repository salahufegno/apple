import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:apple/fetchers/fetchers.dart';
import 'package:apple/globals.dart';
import 'package:process_run/shell.dart';

// Function to handle parallel episode downloads
Future<void> createEpisodesJson(
  dynamic episode,
) async {
  // final SendPort sendPort = params[1]; // SendPort for communication

  final episodeId = episode['episodeId'];
  final episodeTitle = episode['title'];
  final episodeNumber = episode['number'];
  final progress = logger.progress('Fetching episode servers: $episodeNumber - $episodeTitle'); // Log episode start
  var servers = [];
  try {
    servers = await fetchEpisodeServers(episodeId);
    progress.update('Fetched episode servers: $episodeNumber - $episodeTitle');
  } catch (e) {
    progress.fail('Ep: $episodeNumber has $e');
    return;
  }

  bool episodeDownloaded = false;
  for (var server in servers) {
    progress.update('Fetching episode "${server['serverName']}" server details : $episodeNumber - $episodeTitle');
    final sourcesData = await fetchEpisodeServerDetails(episodeId, server['serverName']);
    if (sourcesData.isNotEmpty) {
      progress.update('Fetched episode "${server['serverName']}" server details : $episodeNumber - $episodeTitle');
      final sources = sourcesData['sources'];
      final m3u8Url = sources[0]['url'];
      final intro = sourcesData['intro'];
      final outro = sourcesData['outro'];

      if (intro != null && outro != null) {
        final introEnd = intro['end'];
        final outroStart = outro['start'];
        // final outputFileBase = '/home/bliss/Videos/Naruto/${episode['number']} - ${episode['title']}';
        final outputDir = Directory('/home/bliss/Videos/Naruto');

        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
        }

        final jsonFilePath = '${outputDir.path}/episode_data.json';
        File jsonFile = File(jsonFilePath);

        // Check if the file exists; if not, create it
        if (!await jsonFile.exists()) {
          progress.update('Creating json file');
          await jsonFile.create(recursive: true);
          await jsonFile.writeAsString('{}'); // Initialize with an empty JSON object
          progress.update('Created new JSON file at: $jsonFilePath');
        }
        progress.update('Creating json data : $episodeNumber - $episodeTitle');
        // Read the current data
        final currentData = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        currentData['$episodeNumber'] = {
          'number': episodeNumber,
          'title': episodeTitle,
          'url': m3u8Url,
          'start': introEnd,
          'end': outroStart,
        };
        // Write back the updated data
        await jsonFile.writeAsString(jsonEncode(currentData), flush: true);
        // print('Saved episode data: ${jsonEncode(episodeData)} to $jsonFilePath');
        progress.complete('Added json data : $episodeNumber - $episodeTitle');

        // final segments = [
        //   {'start': 0, 'end': introEnd, 'outputFile': '$outputFileBase-part1.mp4'},
        //   {'start': outroStart, 'end': null, 'outputFile': '$outputFileBase-part2.mp4'}
        // ];

        // await parallelDownload(segments, m3u8Url, 2); // Assuming maxParallel is 10

        // final shell = Shell();
        // final finalOutputFile = '$outputFileBase-final.mp4';
        // await shell.run('ffmpeg -f concat -safe 0 -i <(for f in $outputFileBase-part*.mp4; do echo "file \'\$f\'"; done) -c copy $finalOutputFile');

        // progress.complete('Downloaded and merged episode: $episodeTitle'); // Log success
        episodeDownloaded = true;
        break;
      }
    }
  }

  if (!episodeDownloaded) {
    progress.fail('Failed creating data : $episodeNumber - $episodeTitle');
  }

  // sendPort.send('Episode Completed'); // Notify main isolate
}

Future<void> parallelDownload(
  List<Map<String, dynamic>> segments,
  String url,
  int maxParallel,
) async {
  final receivePort = ReceivePort();
  int activeDownloads = 0;

  Future<void> spawnIsolate(
    Map<String, dynamic> segment,
  ) async {
    if (activeDownloads < maxParallel) {
      activeDownloads++;
      await Isolate.spawn(
        downloadSegment,
        [url, segment['start'], segment['end'], segment['outputFile'], receivePort.sendPort],
      );
    }
  }

  for (var segment in segments) {
    await spawnIsolate(segment);
  }

  await for (var message in receivePort) {
    if (message == 'Segment Completed') {
      activeDownloads--;
      if (segments.isNotEmpty) {
        await spawnIsolate(segments.removeAt(0));
      }
    }
    if (segments.isEmpty && activeDownloads == 0) {
      break;
    }
  }

  receivePort.close();
}

Future<void> downloadSegment(List<dynamic> params) async {
  final String url = params[0];
  final int start = params[1];
  final int end = params[2];
  final String outputFile = params[3];
  final SendPort sendPort = params[4];

  final shell = Shell();
  final command = 'ffmpeg -i $url -ss $start -to $end -movflags +faststart -c copy $outputFile';

  try {
    await shell.run(command);
    sendPort.send('Segment Completed');
  } catch (e) {
    logger.err('Failed to download segment: $e'); // Log failure
    logger.err('Failed to download segment: $outputFile'); // Log failure
    sendPort.send('Segment Failed');
  }
}
