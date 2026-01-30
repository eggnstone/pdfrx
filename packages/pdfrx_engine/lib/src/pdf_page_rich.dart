part of 'pdf_page.dart';

extension PdfPageRichExtension on PdfPage {
  Future<PdfPageRichText> loadRichText({bool ensureLoaded = true}) =>
      PdfTextFormatter.loadRichText(this, pageNumberOverride: pageNumber);
}
