import 'dart:convert';
import 'dart:io';

import 'package:apple/globals.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:process_run/shell.dart';

// Function to handle parallel episode downloads
Future<void> downloadEpisodes(
  dynamic animeName,
  bool skipFillers,
) async {
  final progress = logger.progress('Checking Anime Json File Available...'); // Log episode start

  final animeJsonFile = File(animeJson(animeName: animeName, skipFillers: skipFillers));

  if (!await animeJsonFile.exists()) {
    progress.fail('Couldn\'t find $animeJsonFile file!');
    return;
  }

  final episodesData = jsonDecode(await animeJsonFile.readAsString()) as Map<String, dynamic>;

  progress.complete('Got Anime Json');

  final overwrite = logger.confirm('Do you want to overwrite downloaded episodes?');

  const int maxConcurrentDownloads = 10; // Limit the number of concurrent downloads
  List<Future<void>> downloadTasks = [];
  List hasErrorEpisodesNumbers = [];
  List<String> outputFiles = [];

  for (final episode in episodesData.values) {
    final String episodeUrl = episode['url'];
    final int episodeStart = episode['start'];
    final int episodeEnd = episode['end'];
    final int episodeNumber = episode['number'];
    final String episodeTitle = episode['title'];
    final String outputFile = animeFile(animeName: animeName, epTitle: episodeTitle, epNumber: episodeNumber);

    if (!overwrite && await File(outputFile).exists()) {
      logger.info('Already have episode : $episodeNumber - $episodeTitle');
      outputFiles.add(outputFile); // Keep track of output files even if they are already downloaded
      continue;
    }

    // Add the download task to the list
    downloadTasks.add(() async {
      final animeProgress = Logger().progress('Creating episode : $episodeNumber - $episodeTitle');
      final shell = Shell(verbose: false);
      final command = 'ffmpeg -i $episodeUrl -ss $episodeStart -to $episodeEnd -movflags +faststart -c copy "$outputFile"';

      try {
        await shell.run(command);
        outputFiles.add(outputFile); // Add the downloaded file to the list
        animeProgress.complete('Created episode : $episodeNumber - $episodeTitle');
      } catch (e) {
        animeProgress.fail('Failed to create episode : $episodeNumber - $episodeTitle  ( $e )');
        hasErrorEpisodesNumbers.add(episodeNumber);
      }
    }());

    // If we reached the max concurrent downloads, wait for them to complete
    if (downloadTasks.length >= maxConcurrentDownloads) {
      await Future.wait(downloadTasks);
      downloadTasks.clear(); // Clear the list to start the next batch
    }
  }

  // Wait for any remaining download tasks to finish
  if (downloadTasks.isNotEmpty) {
    await Future.wait(downloadTasks);
  }

  if (hasErrorEpisodesNumbers.isNotEmpty) {
    // for (var episode in episodesData.values) {
    //   final episodeNumber = episode['number'];
    //   episodesData['$episodeNumber']['has_error'] = false;
    // }

    for (var episodeNmmber in hasErrorEpisodesNumbers) {
      episodesData['$episodeNmmber']['has_error'] = true;
    }
    await animeJsonFile.writeAsString(jsonEncode(episodesData), flush: true);
    logger.err('$hasErrorEpisodesNumbers  ${hasErrorEpisodesNumbers.length}/${episodesData.length} episodes not downloaded!');
  } else {
    logger.info('All episodes downloaded successfully.');
    // Combine all the downloaded episodes into one video
    await combineEpisodesIntoMultipleParts(animeName, animeFolder(animeName: animeName), outputFiles);
  }
}

// Function to combine episodes into multiple video files with a 2-hour limit per part
Future<void> combineEpisodesIntoMultipleParts(String animeName, String animeFolder, List<String> outputFiles) async {
  final progress = logger.progress('Combining episodes into 2-hour parts...');
  final partDurationLimit = 7200; // 2 hours in seconds

  int currentPart = 1;
  int currentDuration = 0;
  List<String> currentPartFiles = [];

  // ffmpeg shell
  final shell = Shell(verbose: false);

  final overwrite = logger.confirm('Do you want to overwrite created parts?');

  for (final outputFile in outputFiles) {
    final episodeDuration = await getEpisodeDuration(outputFile);
    currentDuration += episodeDuration;
    currentPartFiles.add(outputFile);

    if (currentDuration >= partDurationLimit) {
      // Combine the current files into a part
      await _combineEpisodes(animeName, animeFolder, currentPart, currentPartFiles, shell, overwrite);
      currentPart++;
      currentDuration = 0;
      currentPartFiles.clear(); // Reset for the next part
    }
  }

  // Combine any remaining files into a final part
  if (currentPartFiles.isNotEmpty) {
    await _combineEpisodes(animeName, animeFolder, currentPart, currentPartFiles, shell, overwrite);
  }

  progress.complete('Episodes successfully combined into 2-hour parts.');
}

// Helper function to get the duration of an episode using ffmpeg
Future<int> getEpisodeDuration(String filePath) async {
  final result = await Process.run('ffmpeg', ['-i', filePath, '-hide_banner']);
  final regex = RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})');
  final match = regex.firstMatch(result.stderr);
  if (match != null) {
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    return hours * 3600 + minutes * 60 + seconds;
  }
  return 0; // Return 0 if unable to parse the duration
}

// Function to combine the current part of episodes into a video file
Future<void> _combineEpisodes(String animeName, String animeFolder, int partNumber, List<String> partFiles, Shell shell, bool overwrite) async {
  final progress = logger.progress('Combining part $partNumber...');

  // Create a temporary file listing all the part files
  var animeFolderMovies = '${animeFolder}Movies/';

  // Define the output file for the combined part video
  final combinedOutputFile = '${animeFolderMovies}_part_$partNumber.mp4';

  if (!overwrite && await File(combinedOutputFile).exists()) {
    progress.complete('Already available part $partNumber...');
    return;
  }

  final listFile = File('${animeFolderMovies}concat_list_part_$partNumber.txt');
  if (!await listFile.exists()) {
    await listFile.create(recursive: true);
  }
  // Create a temporary file listing all the part files with proper quoting for paths
  final listContent = partFiles.map((file) => "file '${file.replaceAll("'", "'\\''")}'").join('\n');
  await listFile.writeAsString(listContent, flush: true);

  // ffmpeg command to concatenate the files
  final concatCommand = 'ffmpeg -f concat -safe 0 -i "${listFile.path}" -c copy "$combinedOutputFile"';

  try {
    await shell.run(concatCommand);
    progress.complete('Created part $partNumber: $combinedOutputFile');
  } catch (e) {
    progress.fail('Failed to create part $partNumber: $e');
  } finally {
    // Clean up the list file after concatenation
    if (await listFile.exists()) {
      await listFile.delete();
    }
  }
}
