import 'package:http/http.dart' as http;

Future<String?> uploadToAzurePlatform({
  required List<int> bytes,
  required String uploadUrl,
  required String cleanUrl,
  required String contentType,
}) async {
  try {
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': contentType,
        'x-ms-blob-cache-control': 'public, max-age=31536000',
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('[AZURE IO STORAGE] Upload succeeded: $cleanUrl');
      return cleanUrl;
    } else {
      print('[AZURE IO STORAGE] Upload failed: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    print('[AZURE IO STORAGE] Exception during upload: $e');
    return null;
  }
}
