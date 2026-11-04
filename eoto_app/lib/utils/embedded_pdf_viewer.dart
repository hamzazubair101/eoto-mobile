import 'package:flutter/material.dart';
import 'embedded_pdf_viewer_stub.dart'
    if (dart.library.html) 'embedded_pdf_viewer_web.dart' as impl;

class EmbeddedPdfViewer extends StatelessWidget {
  final String url;
  final double height;

  const EmbeddedPdfViewer({Key? key, required this.url, this.height = 360}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return impl.EmbeddedPdfViewer(url: url, height: height);
  }
}
