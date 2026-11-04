import 'azure_uploader_stub.dart'
    if (dart.library.html) 'azure_uploader_web.dart'
    if (dart.library.io) 'azure_uploader_io.dart';

/// Service for uploading and accessing EOTO assets in Azure Blob Storage
/// Uses scoped Write-Only SAS authorization ensuring Master Account Keys are NEVER exposed.
class AzureStorageService {
  static const String storageAccount = 'eotostorage';
  static const String containerName = 'eotocontainer';
  static const String baseUrl = 'https://$storageAccount.blob.core.windows.net/$containerName';

  // Scoped Write-Only SAS Token (Create + Write only)
  static const String _writeSasToken = 'sv=2026-06-06&st=2026-09-07T08%3A24%3A49Z&se=2027-09-07T08%3A24%3A49Z&sr=c&sp=cw&sig=13NOUOA6EIjQ%2BXUrC8%2BrIPPuJmh2i5NrsrmwGX1EkUA%3D';

  /// Upload a raw byte buffer to Azure Blob Storage (Web & Mobile native)
  static Future<String?> uploadBytes({
    required List<int> bytes,
    required String blobPath,
    String contentType = 'application/octet-stream',
  }) async {
    final uploadUrl = '$baseUrl/$blobPath?$_writeSasToken';
    final cleanUrl = '$baseUrl/$blobPath';

    return await uploadToAzurePlatform(
      bytes: bytes,
      uploadUrl: uploadUrl,
      cleanUrl: cleanUrl,
      contentType: contentType,
    );
  }

  /// Upload file from disk
  static Future<String?> uploadFile({
    required dynamic file,
    required String blobPath,
    String? contentType,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      String determinedType = contentType ?? 'image/jpeg';
      final String filePath = file.path.toString();
      if (filePath.toLowerCase().endsWith('.pdf')) {
        determinedType = 'application/pdf';
      } else if (filePath.toLowerCase().endsWith('.png')) {
        determinedType = 'image/png';
      }

      return await uploadBytes(
        bytes: bytes,
        blobPath: blobPath,
        contentType: determinedType,
      );
    } catch (e) {
      print('[AZURE STORAGE] File read error: $e');
      return null;
    }
  }

  /// Upload Teacher / Volunteer Registration Document
  static Future<String?> uploadRegistrationDoc({
    required dynamic file,
    required String userId,
    required String docType, // 'cnic_front', 'cnic_back', 'academic_proof'
  }) async {
    final String filePath = file.path.toString();
    final ext = filePath.split('.').last;
    final blobPath = 'registration_docs/${userId}_${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return await uploadFile(file: file, blobPath: blobPath);
  }

  /// Upload Teacher / Volunteer Registration Document from raw bytes (cross-platform Web/Mobile)
  static Future<String?> uploadRegistrationDocBytes({
    required List<int> bytes,
    required String userId,
    required String docType, // 'cnic_front', 'cnic_back', 'academic_proof'
    String fileName = 'doc.jpg',
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final blobPath = 'registration_docs/${userId}_${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    String contentType = 'image/jpeg';
    if (ext.toLowerCase() == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext.toLowerCase() == 'png') {
      contentType = 'image/png';
    }
    return await uploadBytes(bytes: bytes, blobPath: blobPath, contentType: contentType);
  }

  /// Upload Solved Baseline Assessment Paper
  static Future<String?> uploadBaselineAssessment({
    required dynamic file,
    required String learnerId,
  }) async {
    final String filePath = file.path.toString();
    final ext = filePath.split('.').last;
    final blobPath = 'baseline_assessments/learner_${learnerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return await uploadFile(file: file, blobPath: blobPath);
  }

  /// Upload Solved Baseline Assessment Paper from raw bytes (cross-platform Web/Mobile)
  static Future<String?> uploadBaselineAssessmentBytes({
    required List<int> bytes,
    required String learnerId,
    String fileName = 'baseline.jpg',
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final blobPath = 'baseline_assessments/learner_${learnerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    String contentType = 'image/jpeg';
    if (ext.toLowerCase() == 'pdf') contentType = 'application/pdf';
    else if (ext.toLowerCase() == 'png') contentType = 'image/png';
    return await uploadBytes(bytes: bytes, blobPath: blobPath, contentType: contentType);
  }

  /// Upload Solved Midterm Assessment Paper
  static Future<String?> uploadMidtermAssessment({
    required dynamic file,
    required String learnerId,
  }) async {
    final String filePath = file.path.toString();
    final ext = filePath.split('.').last;
    final blobPath = 'midterm_assessments/learner_${learnerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return await uploadFile(file: file, blobPath: blobPath);
  }

  /// Upload Solved Midterm Assessment Paper from raw bytes (cross-platform Web/Mobile)
  static Future<String?> uploadMidtermAssessmentBytes({
    required List<int> bytes,
    required String learnerId,
    String fileName = 'midterm.jpg',
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final blobPath = 'midterm_assessments/learner_${learnerId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    String contentType = 'image/jpeg';
    if (ext.toLowerCase() == 'pdf') contentType = 'application/pdf';
    else if (ext.toLowerCase() == 'png') contentType = 'image/png';
    return await uploadBytes(bytes: bytes, blobPath: blobPath, contentType: contentType);
  }
}
