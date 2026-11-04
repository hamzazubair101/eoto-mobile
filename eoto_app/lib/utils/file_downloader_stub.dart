import 'package:url_launcher/url_launcher.dart';

Future<bool> downloadFileImpl({
  required String url,
  required String fileName,
}) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  } catch (e) {
    print("Download stub error: $e");
    return false;
  }
}

Future<void> openFileInBrowserImpl({
  required String url,
  String? title,
}) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    print("Open in browser stub error: $e");
  }
}
