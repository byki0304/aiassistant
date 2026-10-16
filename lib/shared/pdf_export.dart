import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web/web.dart';

const _fontUrl = 'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf';

Future<void> downloadScriptPdf({required String title, required String body}) async {
  final response = await http.get(Uri.parse(_fontUrl));
  if (response.statusCode != 200) {
    throw StateError('pdf-font');
  }
  final font = pw.Font.ttf(ByteData.sublistView(response.bodyBytes));
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 16)),
          pw.SizedBox(height: 12),
          pw.Text(body, style: pw.TextStyle(font: font, fontSize: 11)),
        ],
      ),
    ),
  );
  final bytes = await doc.save();
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: 'application/pdf'));
  final url = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = url
    ..download = 'news-script.pdf';
  anchor.click();
  URL.revokeObjectURL(url);
}
