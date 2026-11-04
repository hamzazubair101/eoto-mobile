import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors based on the UI specifications
  static const Color primaryLime = Color(0xFFCCFF00);
  static const Color backgroundLight = Color(0xFFF9F9F9); // Light grayish-white
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF0F0F0); // Light gray filled containers
  static const Color textBlack = Color(0xFF000000);
  static const Color textGrey = Color(0xFF757575);
  
  // Status Colors for Badges/Tags
  static const Color statusPending = Colors.orangeAccent;
  static const Color statusActive = primaryLime;
  static const Color statusRejected = Colors.redAccent;
  
  // ThemeData configuration
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryLime,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primaryLime,
        secondary: textBlack,
        surface: cardLight,
        error: statusRejected,
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textBlack, fontSize: 32, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textBlack, fontSize: 24, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textBlack, fontSize: 16, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: textGrey, fontSize: 14),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLime,
          foregroundColor: Colors.black, // Dark text on lime green button
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Pill shape
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
          elevation: 0,
        ),
      ),

      // Input Decoration (Text Fields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLime, width: 2),
        ),
        hintStyle: const TextStyle(color: textGrey),
      ),

      // SnackBar Theme (High-contrast, modern floating card)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryLime,
        contentTextStyle: const TextStyle(
          color: textBlack,
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFA6DB00), width: 1.5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a high-contrast success notification with signature lime background and deep jet-black text & icon
  static void showSuccessSnackBar(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryLime,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFA6DB00), width: 1.5),
        ),
        duration: duration,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows an info or progress notification in a sleek dark floating card with lime accent
  static void showInfoSnackBar(BuildContext context, String message, {Duration duration = const Duration(seconds: 2), bool isLoading = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        content: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryLime),
              )
            else
              const Icon(Icons.info_outline_rounded, color: primaryLime, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows an error notification in an urgent red floating card
  static void showErrorSnackBar(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration,
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
