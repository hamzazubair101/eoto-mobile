import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJsService {
  // ==========================================
  // CONFIGURATION: Customize these for your EmailJS account
  // ==========================================
  static String serviceId = 'service_j973ib9';
  static String templateId = 'template_ub2qv9h';
  static String publicKey = 'YDGh9CkVuoc7l1bdk';
  // ==========================================

  /// Sends a secure 6-digit OTP code to the recipient's email address
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': recipientEmail,
            'otp_code': otpCode,
            'app_name': 'EOTO Literacy Program',
          },
        }),
      );

      if (response.statusCode == 200) {
        print("EmailJS Success: OTP code $otpCode sent to $recipientEmail");
        return true;
      } else {
        print("EmailJS Error Response: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("EmailJS Exception: $e");
      return false;
    }
  }
}
