part of 'pdf_text_formatter.dart';

extension PdfTextFormatterRichExtension on PdfTextFormatter {
  static Future<PdfPageRichText> loadRichText(PdfPage page, {required int? pageNumberOverride}) async {
    pageNumberOverride ??= page.pageNumber;
    final raw = await _loadRichText(page);
    if (raw == null) {
      return PdfPageRichText(pageNumber: pageNumberOverride, fullText: '', charRects: [], fragments: []);
    }
    final inputCharRects = raw.charRects;
    final inputFullText = raw.fullText;
    final inputFontInfos = raw.fontInfos;

    final fragmentsTmp = <({int length, PdfTextDirection direction, PdfFontInfo fontInfo})>[];

    /// Ugly workaround for WASM+Safari StringBuffer issue (#483).
    final outputText = createStringBufferForWorkaroundSafariWasm();
    final outputCharRects = <PdfRect>[];

    PdfTextDirection vector2direction(Vector2 v) {
      if (v.x.abs() > v.y.abs()) {
        return v.x > 0 ? PdfTextDirection.ltr : PdfTextDirection.rtl;
      } else {
        return PdfTextDirection.vrtl;
      }
    }

    PdfTextDirection getLineDirection(int start, int end) {
      if (start == end || start + 1 == end) return PdfTextDirection.unknown;
      return vector2direction(inputCharRects[start].center.differenceTo(inputCharRects[end - 1].center));
    }

    PdfFontInfo getFontInfo(int start, int end) {
      if (start == end || start + 1 == end) return PdfFontInfo(name: '', size: 0, weight: 0, flags: 0);
      // All characters in the line are expected to have the same font size.
      return inputFontInfos[start];
    }

    void addWord(
      int wordStart,
      int wordEnd,
      PdfTextDirection dir,
      PdfFontInfo fontInfo,
      PdfRect bounds, {
      bool isSpace = false,
      bool isNewLine = false,
    }) {
      if (wordStart < wordEnd) {
        final pos = outputText.length;
        if (isSpace) {
          if (wordStart > 0 && wordEnd < inputCharRects.length) {
            // combine several spaces into one space
            final a = inputCharRects[wordStart - 1];
            final b = inputCharRects[wordEnd];
            switch (dir) {
              case PdfTextDirection.ltr:
              case PdfTextDirection.unknown:
                outputCharRects.add(PdfRect(a.right, bounds.top, a.right < b.left ? b.left : a.right, bounds.bottom));
              case PdfTextDirection.rtl:
                outputCharRects.add(PdfRect(b.right, bounds.top, b.right < a.left ? a.left : b.right, bounds.bottom));
              case PdfTextDirection.vrtl:
                outputCharRects.add(PdfRect(bounds.left, a.bottom, bounds.right, a.bottom > b.top ? b.top : a.bottom));
            }
            outputText.write(' ');
          }
        } else if (isNewLine) {
          if (wordStart > 0) {
            // new line (\n)
            switch (dir) {
              case PdfTextDirection.ltr:
              case PdfTextDirection.unknown:
                outputCharRects.add(PdfRect(bounds.right, bounds.top, bounds.right, bounds.bottom));
              case PdfTextDirection.rtl:
                outputCharRects.add(PdfRect(bounds.left, bounds.top, bounds.left, bounds.bottom));
              case PdfTextDirection.vrtl:
                outputCharRects.add(PdfRect(bounds.left, bounds.bottom, bounds.right, bounds.bottom));
            }
            outputText.write('\n');
          }
        } else {
          // Adjust character bounding box based on text direction.
          switch (dir) {
            case PdfTextDirection.ltr:
            case PdfTextDirection.rtl:
            case PdfTextDirection.unknown:
              for (var i = wordStart; i < wordEnd; i++) {
                final r = inputCharRects[i];
                outputCharRects.add(PdfRect(r.left, bounds.top, r.right, bounds.bottom));
              }
            case PdfTextDirection.vrtl:
              for (var i = wordStart; i < wordEnd; i++) {
                final r = inputCharRects[i];
                outputCharRects.add(PdfRect(bounds.left, r.top, bounds.right, r.bottom));
              }
          }
          outputText.write(inputFullText.substring(wordStart, wordEnd));
        }
        if (outputText.length > pos) {
          fragmentsTmp.add((length: outputText.length - pos, direction: dir, fontInfo: fontInfo));
        }
      }
    }

    int addWords(int start, int end, PdfTextDirection dir, PdfFontInfo fontInfo, PdfRect bounds) {
      final firstIndex = fragmentsTmp.length;
      final matches = PdfTextFormatter._reSpaces.allMatches(inputFullText.substring(start, end));
      var wordStart = start;
      for (final match in matches) {
        final spaceStart = start + match.start;
        addWord(wordStart, spaceStart, dir, fontInfo, bounds);
        wordStart = start + match.end;
        addWord(spaceStart, wordStart, dir, fontInfo, bounds, isSpace: true);
      }
      addWord(wordStart, end, dir, fontInfo, bounds);
      return fragmentsTmp.length - firstIndex;
    }

    Vector2 charVec(int index, Vector2 prev) {
      if (index + 1 >= inputCharRects.length) {
        return prev;
      }
      final next = inputCharRects[index + 1];
      if (next.isEmpty) {
        return prev;
      }
      final cur = inputCharRects[index];
      return cur.center.differenceTo(next.center);
    }

    List<({int start, int end, PdfTextDirection dir, PdfFontInfo fontInfo})> splitLineByFontSize(
      int start,
      int end,
      PdfTextDirection dir,
    ) {
      final list = <({int start, int end, PdfTextDirection dir, PdfFontInfo fontInfo})>[];

      var curStart = start;
      var curFontInfo = inputFontInfos[start];
      for (var next = start + 1; next < end; next++) {
        if (PdfTextFormatter._reSpaces.hasMatch(inputFullText[next])) {
          continue;
        }
        final nextFontInfo = inputFontInfos[next];
        if (curFontInfo != nextFontInfo) {
          list.add((start: curStart, end: next, dir: dir, fontInfo: curFontInfo));
          curStart = next;
          curFontInfo = nextFontInfo;
        }
      }

      if (curStart < end) {
        list.add((start: curStart, end: end, dir: dir, fontInfo: curFontInfo));
      }

      return list;
    }

    List<({int start, int end, PdfTextDirection dir, PdfFontInfo fontInfo})> splitLine(int start, int end) {
      final list = <({int start, int end, PdfTextDirection dir, PdfFontInfo fontInfo})>[];
      final lineThreshold = 1.5; // radians
      final last = end - 1;
      var curStart = start;
      var curVec = charVec(start, Vector2(1, 0));
      for (var next = start + 1; next < last;) {
        final nextVec = charVec(next, curVec);
        if (curVec.angleTo(nextVec) > lineThreshold) {
          list.addAll(splitLineByFontSize(curStart, next + 1, vector2direction(curVec)));
          curStart = next + 1;
          if (next + 2 == end) break;
          curVec = charVec(next + 1, nextVec);
          next += 2;
          continue;
        }
        curVec += nextVec;
        next++;
      }
      if (curStart < end) {
        list.addAll(splitLineByFontSize(curStart, end, vector2direction(curVec)));
      }
      return list;
    }

    void handleLine(int start, int end, {int? newLineEnd}) {
      final segments = splitLine(start, end).toList();
      if (segments.length >= 2) {
        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i];
          final bounds = inputCharRects.boundingRect(start: seg.start, end: seg.end);
          addWords(seg.start, seg.end, seg.dir, seg.fontInfo, bounds);
          if (i + 1 == segments.length && newLineEnd != null) {
            addWord(seg.end, newLineEnd, seg.dir, seg.fontInfo, bounds, isNewLine: true);
          }
        }
      } else {
        final dir = getLineDirection(start, end);
        final fontInfo = getFontInfo(start, end);
        final bounds = inputCharRects.boundingRect(start: start, end: end);
        addWords(start, end, dir, fontInfo, bounds);
        if (newLineEnd != null) {
          addWord(end, newLineEnd, dir, fontInfo, bounds, isNewLine: true);
        }
      }
    }

    var lineStart = 0;
    for (final match in PdfTextFormatter._reNewLine.allMatches(inputFullText)) {
      if (lineStart < match.start) {
        handleLine(lineStart, match.start, newLineEnd: match.end);
      } else {
        final lastRect = outputCharRects.last;
        outputCharRects.add(PdfRect(lastRect.left, lastRect.top, lastRect.left, lastRect.bottom));
        outputText.write('\n');
      }
      lineStart = match.end;
    }
    if (lineStart < inputFullText.length) {
      handleLine(lineStart, inputFullText.length);
    }

    final fragments = <PdfPageRichTextFragment>[];
    final text = PdfPageRichText(
      pageNumber: pageNumberOverride,
      fullText: outputText.toString(),
      charRects: outputCharRects,
      fragments: UnmodifiableListView(fragments),
    );

    var start = 0;
    for (var i = 0; i < fragmentsTmp.length; i++) {
      final length = fragmentsTmp[i].length;
      final direction = fragmentsTmp[i].direction;
      final fontInfo = fragmentsTmp[i].fontInfo;
      final end = start + length;
      final fragmentRects = UnmodifiableSublist(outputCharRects, start: start, end: end);
      fragments.add(
        PdfPageRichTextFragment(
          pageText: text,
          index: start,
          length: length,
          charRects: fragmentRects,
          bounds: fragmentRects.boundingRect(),
          direction: direction,
          fontInfo: fontInfo,
        ),
      );
      start = end;
    }

    return text;
  }

  static Future<PdfPageRichRawText?> _loadRichText(PdfPage page) async {
    final input = await page.loadRichRawText();
    if (input == null) {
      return null;
    }

    final fullText = StringBuffer();
    final charRects = <PdfRect>[];
    final fontInfos = <PdfFontInfo>[];

    // Process the whole text
    final lnMatches = PdfTextFormatter._reNewLine.allMatches(input.fullText).toList();
    var lineStart = 0;
    var prevEnd = 0;
    for (var i = 0; i < lnMatches.length; i++) {
      lineStart = prevEnd;
      final match = lnMatches[i];
      fullText.write(input.fullText.substring(lineStart, match.start));
      charRects.addAll(input.charRects.sublist(lineStart, match.start));
      fontInfos.addAll(input.fontInfos.sublist(lineStart, match.start));
      prevEnd = match.end;

      // Microsoft Word sometimes outputs vertical text like this: "縦\n書\nき\nの\nテ\nキ\nス\nト\nで\nす\n。\n"
      // And, we want to remove these line-feeds.
      if (i + 1 < lnMatches.length) {
        final next = lnMatches[i + 1];
        final len = match.start - lineStart;
        final nextLen = next.start - match.end;
        if (len == 1 && nextLen == 1) {
          final rect = input.charRects[lineStart];
          //final fontSize = input.fontSizes[lineStart];
          final nextRect = input.charRects[match.end];
          final nextCenterX = nextRect.center.x;
          if (rect.left < nextCenterX && nextCenterX < rect.right && rect.top > nextRect.top) {
            // The line is vertical, and the line-feed is virtual
            continue;
          }
        }
      }
      fullText.write(input.fullText.substring(match.start, match.end));
      charRects.addAll(input.charRects.sublist(match.start, match.end));
      fontInfos.addAll(input.fontInfos.sublist(match.start, match.end));
    }
    if (prevEnd < input.fullText.length) {
      fullText.write(input.fullText.substring(prevEnd));
      charRects.addAll(input.charRects.sublist(prevEnd));
      fontInfos.addAll(input.fontInfos.sublist(prevEnd));
    }

    return PdfPageRichRawText(fullText.toString(), charRects, fontInfos);
  }
}
