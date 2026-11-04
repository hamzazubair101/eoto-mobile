import 'dart:html' as html;
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> downloadFileImpl({
  required String url,
  required String fileName,
}) async {
  try {
    // Determine accurate extension and MIME type
    final lowerUrl = url.toLowerCase();
    String ext = 'pdf';
    String mimeType = 'application/pdf';

    if (lowerUrl.contains('.png') || url.startsWith('data:image/png')) {
      ext = 'png';
      mimeType = 'image/png';
    } else if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || url.startsWith('data:image/jpeg')) {
      ext = 'jpg';
      mimeType = 'image/jpeg';
    } else if (lowerUrl.contains('.pdf') || url.startsWith('data:application/pdf')) {
      ext = 'pdf';
      mimeType = 'application/pdf';
    }

    // Ensure clean filename has correct extension
    String cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    if (!cleanFileName.toLowerCase().endsWith('.$ext')) {
      cleanFileName = '$cleanFileName.$ext';
    }

    // Case 1: Base64 Data URI
    if (url.startsWith('data:')) {
      final commaIdx = url.indexOf(',');
      if (commaIdx != -1) {
        final base64Content = url.substring(commaIdx + 1);
        final bytes = base64Decode(base64Content);
        final blob = html.Blob([bytes], mimeType);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', cleanFileName)
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();

        // Delay revoke so browser downloads with the clean filename instead of blob UUID
        Future.delayed(const Duration(seconds: 45), () {
          html.Url.revokeObjectUrl(blobUrl);
        });
        return true;
      }
    }

    // Case 2: HTTP/HTTPS Network URL (e.g. Azure Blob Storage)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final blob = html.Blob([response.bodyBytes], mimeType);
          final blobUrl = html.Url.createObjectUrlFromBlob(blob);

          final anchor = html.AnchorElement(href: blobUrl)
            ..setAttribute('download', cleanFileName)
            ..style.display = 'none';
          html.document.body?.children.add(anchor);
          anchor.click();
          anchor.remove();

          // Keep blob URL alive so browser finishes downloading with full filename & extension!
          Future.delayed(const Duration(seconds: 45), () {
            html.Url.revokeObjectUrl(blobUrl);
          });
          return true;
        }
      } catch (e) {
        print("Direct blob fetch notice, falling back to direct anchor download: $e");
      }

      // Fallback: Direct Anchor download
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', cleanFileName)
        ..setAttribute('target', '_blank')
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      return true;
    }

    return false;
  } catch (e) {
    print("Web download error: $e");
    return false;
  }
}

Future<void> openFileInBrowserImpl({
  required String url,
  String? title,
}) async {
  try {
    if (url.startsWith('data:')) {
      final commaIdx = url.indexOf(',');
      if (commaIdx != -1) {
        final meta = url.substring(0, commaIdx);
        final base64Content = url.substring(commaIdx + 1);
        final mimeType = meta.split(';').first.replaceFirst('data:', '');
        final bytes = base64Decode(base64Content);
        final blob = html.Blob([bytes], mimeType);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(blobUrl, '_blank');
        return;
      }
    }

    // Direct URL (Azure Blob, Firebase, etc.)
    html.window.open(url, '_blank');
  } catch (e) {
    print("Error opening file in browser: $e");
  }
}
