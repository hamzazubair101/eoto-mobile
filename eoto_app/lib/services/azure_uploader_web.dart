import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<String?> uploadToAzurePlatform({
  required List<int> bytes,
  required String uploadUrl,
  required String cleanUrl,
  required String contentType,
}) async {
  final completer = Completer<String?>();
  try {
    final request = html.HttpRequest();
    request.open('PUT', uploadUrl, async: true);
    request.setRequestHeader('x-ms-blob-type', 'BlockBlob');
    request.setRequestHeader('Content-Type', contentType);
    request.setRequestHeader('x-ms-blob-cache-control', 'public, max-age=31536000');

    request.onLoad.listen((_) {
      if (request.status == 200 || request.status == 201) {
        print('[AZURE WEB STORAGE] Upload succeeded (HTTP ${request.status}): $cleanUrl');
        completer.complete(cleanUrl);
      } else {
        print('[AZURE WEB STORAGE] Upload failed: HTTP ${request.status} - ${request.responseText}');
        completer.complete(null);
      }
    });

    request.onError.listen((e) {
      print('[AZURE WEB STORAGE] XHR network error: $e');
      completer.complete(null);
    });

    final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    request.send(uint8List);
  } catch (e) {
    print('[AZURE WEB STORAGE] Exception during upload: $e');
    completer.complete(null);
  }
  return completer.future;
}
