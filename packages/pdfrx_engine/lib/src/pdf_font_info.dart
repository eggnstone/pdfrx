class PdfFontInfo {
  const PdfFontInfo({required this.flags, required this.name, required this.size, required this.weight});

  static const double fontSizeEpsilon = 0.01;

  final int flags;
  final String name;
  final double size;
  final int weight;

  @override
  int get hashCode {
    return flags.hashCode ^ name.hashCode ^ size.hashCode ^ weight.hashCode;
  }

  bool isSimilarTo(PdfFontInfo other) {
    return this == other || (size - other.size).abs() < fontSizeEpsilon;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfFontInfo &&
        other.flags == flags &&
        other.name == name &&
        other.size == size &&
        other.weight == weight;
  }
}
