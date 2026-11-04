Future<String?> uploadToAzurePlatform({
  required List<int> bytes,
  required String uploadUrl,
  required String cleanUrl,
  required String contentType,
}) async {
  throw UnsupportedError('Cannot upload to Azure without platform implementation.');
}
