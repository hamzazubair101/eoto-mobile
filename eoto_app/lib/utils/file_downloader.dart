import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart';

Future<bool> downloadFileToDevice({
  required String url,
  required String fileName,
}) => downloadFileImpl(url: url, fileName: fileName);

Future<void> openFileInBrowser({
  required String url,
  String? title,
}) => openFileInBrowserImpl(url: url, title: title);
