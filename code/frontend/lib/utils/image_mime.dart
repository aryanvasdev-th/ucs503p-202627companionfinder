import 'package:http_parser/http_parser.dart';

/// `http.MultipartFile.fromPath` guesses content-type from the file
/// extension using package:mime's lookup table, which doesn't know about
/// .heic/.heif — those upload as application/octet-stream and get rejected
/// server-side. Picking the type ourselves keeps HEIC uploads (the default
/// photo format on iOS/macOS) working.
MediaType mediaTypeForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'heic':
      return MediaType('image', 'heic');
    case 'heif':
      return MediaType('image', 'heif');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'jpg':
    case 'jpeg':
    default:
      return MediaType('image', 'jpeg');
  }
}
