import 'package:flutter/material.dart';
import 'app_theme.dart';

class EmbeddedPdfViewer extends StatelessWidget {
  final String url;
  final double height;

  const EmbeddedPdfViewer({Key? key, required this.url, this.height = 360}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF1E1E22),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryLime, size: 56),
          SizedBox(height: 12),
          Text(
            'Official PDF Assessment Document',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Tap Open / Download below to inspect full document',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
