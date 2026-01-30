part of 'pdf_text.dart';

/// A container for the rich text result.
class PdfPageRichText {
  const PdfPageRichText({
    required this.pageNumber,
    required this.fullText,
    required this.charRects,
    required this.fragments,
  });

  /// Page number. The first page is 1.
  final int pageNumber;

  /// Full text of the page.
  final String fullText;

  /// Bounds corresponding to characters in the full text.
  final List<PdfRect> charRects;

  /// Get text fragments that organizes the full text structure.
  ///
  /// The [fullText] is the composed result of all fragments' text.
  /// Any character in [fullText] must be included in one of the fragments.
  final List<PdfPageRichTextFragment> fragments;

  PdfPageText toPdfPageText() {
    return PdfPageText(pageNumber: pageNumber, fullText: fullText, charRects: charRects, fragments: fragments);
  }
}

class PdfPageRichRawText {
  PdfPageRichRawText(this.fullText, this.charRects, this.fontSizes);

  /// Full text of the page.
  final String fullText;

  /// Bounds corresponding to characters in the full text.
  final List<PdfRect> charRects;

  final List<double> fontSizes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfPageRichRawText &&
        other.fullText == fullText &&
        listEquals(other.charRects, charRects) &&
        listEquals(other.fontSizes, fontSizes);
  }

  @override
  int get hashCode => fullText.hashCode ^ charRects.hashCode ^ fontSizes.hashCode;
}

/// A subclass of [PdfPageTextFragment] that includes font styling metadata.
class PdfPageRichTextFragment extends PdfPageTextFragment {
  PdfPageRichTextFragment({
    required PdfPageRichText pageText,
    required this.fontSize,
    required this.fontWeight,
    required this.isItalic,
    required this.isForceBold,
    required super.index,
    required super.length,
    required super.bounds,
    required super.charRects,
    required super.direction,
  }) : super(pageText: pageText.toPdfPageText());

  /// Font size in PDF points (approx 1/72 inch).
  final double fontSize;

  /// The visual weight (e.g., 400=Normal, 700=Bold).
  final FontWeight fontWeight;

  /// True if the text is Italic.
  final bool isItalic;

  /// True if the PDF forces a fake bold effect.
  final bool isForceBold;

  /// Helper to check effective bold (either True Bold or Force Bold).
  bool get isEffectiveBold => fontWeight.index >= FontWeight.w600.index || isForceBold;
}
