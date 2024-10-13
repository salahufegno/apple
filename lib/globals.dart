import 'package:mason_logger/mason_logger.dart';

final logger = Logger(); // Initialize the logger

const String baseUrl = "http://localhost:4000/api/v2/hianime";

const parent = '/home/bliss/Videos/';

String animeFolder({required dynamic animeName}) {
  return '$parent$animeName/';
}

String animeJson({
  required dynamic animeName,
  required bool skipFillers,
}) {
  return '${animeFolder(animeName: animeName)}episodes_${skipFillers ? 'without_fillers_' : ''}data.json';
}

String animeFile({
  required dynamic animeName,
  required dynamic epTitle,
  required dynamic epNumber,
}) {
  return '${animeFolder(animeName: animeName)}$epNumber - $epTitle.mp4';
}
