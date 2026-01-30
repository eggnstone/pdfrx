part of 'pdfrx_pdfium.dart';

extension _PdfrxPdfiumRichExtension on _PdfPagePdfium {
  Future<PdfPageRichRawText?> _loadRichRawText() async {
    if (document.isDisposed || !isLoaded) return null;
    return await BackgroundWorker.computeWithArena((arena, params) {
      final doubleSize = sizeOf<Double>();
      final rectBuffer = arena<Double>(4);
      final doc = pdfium_bindings.FPDF_DOCUMENT.fromAddress(params.docHandle);
      final page = pdfium.FPDF_LoadPage(doc, params.pageNumber - 1);
      final textPage = pdfium.FPDFText_LoadPage(page);
      try {
        final charCount = pdfium.FPDFText_CountChars(textPage);
        final sb = StringBuffer();
        final charRects = <PdfRect>[];
        final fontSizes = <double>[];
        final fontWeights = <int>[];
        final fontNames = <String>[];
        final fontFlags = <int>[];

        // Allocate memory for the name buffer and flags buffer
        const bufferSize = 256;
        final nameBuffer = calloc<Uint8>(bufferSize);
        final flagsBuffer = calloc<Int>();

        for (var i = 0; i < charCount; i++) {
          sb.writeCharCode(pdfium.FPDFText_GetUnicode(textPage, i));

          pdfium.FPDFText_GetCharBox(
            textPage,
            i,
            rectBuffer, // L
            rectBuffer.offset(doubleSize * 2), // R
            rectBuffer.offset(doubleSize * 3), // B
            rectBuffer.offset(doubleSize), // T
          );
          charRects.add(_PdfPagePdfium._rectFromLTRBBuffer(rectBuffer, params.bbLeft, params.bbBottom));

          fontSizes.add(pdfium.FPDFText_GetFontSize(textPage, i));

          fontWeights.add(pdfium.FPDFText_GetFontWeight(textPage, i));

          final actualNameLength = pdfium.FPDFText_GetFontInfo(
            textPage,
            i,
            nameBuffer.cast<Void>(),
            bufferSize,
            flagsBuffer,
          );

          if (actualNameLength > 0) {
            final fontName = nameBuffer.cast<Utf8>().toDartString();
            final fontFlags1 = flagsBuffer.value;
            fontNames.add(fontName);
            fontFlags.add(fontFlags1);
          } else {
            fontNames.add('');
            fontFlags.add(0);
          }
        }

        // Free allocated memory
        calloc.free(nameBuffer);
        calloc.free(flagsBuffer);

        return PdfPageRichRawText(sb.toString(), charRects, fontSizes);
      } finally {
        pdfium.FPDFText_ClosePage(textPage);
        pdfium.FPDF_ClosePage(page);
      }
    }, (docHandle: document.document.address, pageNumber: pageNumber, bbLeft: bbLeft, bbBottom: bbBottom));
  }
}
