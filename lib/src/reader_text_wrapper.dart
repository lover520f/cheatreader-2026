import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class ReaderTextWrapper {
  final _cache =
      <
        (String, double, TextStyle, TextDirection, TextScaler, bool),
        List<String>
      >{};

  List<String> wrap({
    required String text,
    required double maxWidth,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required bool preferPunctuationLineBreaks,
  }) {
    if (text.isEmpty || maxWidth <= 0) return [text];
    final key = (
      text,
      maxWidth,
      style,
      textDirection,
      textScaler,
      preferPunctuationLineBreaks,
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final boundaries = <int>[0];
    for (final character in text.characters) {
      boundaries.add(boundaries.last + character.length);
    }
    final painter = TextPainter(
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    );
    final segments = <String>[];
    try {
      var start = 0;
      final count = boundaries.length - 1;
      while (start < count) {
        bool fits(int end) {
          painter.text = TextSpan(
            text: text.substring(boundaries[start], boundaries[end]),
            style: style,
          );
          painter.layout();
          return !painter.didExceedMaxLines && painter.width <= maxWidth;
        }

        // Bound each measurement to a visual line, never half of the remaining
        // paragraph. Exponential search also handles unusually narrow glyphs.
        var best = start + 1;
        var high = math.min(count, start + 2);
        while (fits(high)) {
          best = high;
          if (high == count) break;
          high = math.min(count, start + (high - start) * 2);
        }
        var low = best + 1;
        high -= 1;
        while (low <= high) {
          final middle = (low + high) ~/ 2;
          if (fits(middle)) {
            best = middle;
            low = middle + 1;
          } else {
            high = middle - 1;
          }
        }
        // The rest of the paragraph fits, so there is nothing to wrap.
        if (preferPunctuationLineBreaks && best < count) {
          best = _preferredBreak(text, boundaries, start, best);
        }
        segments.add(text.substring(boundaries[start], boundaries[best]));
        start = best;
      }
    } finally {
      painter.dispose();
    }
    final result = List<String>.unmodifiable(segments);
    if (_cache.length >= 16) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  /// Picks a break at or before [best]: after punctuation when possible,
  /// never leaving closing punctuation at the start of the next line or
  /// opening punctuation at the end of this one.
  static int _preferredBreak(
    String text,
    List<int> boundaries,
    int start,
    int best,
  ) {
    bool isLegal(int end) =>
        !_noLineStart.contains(text.codeUnitAt(boundaries[end])) &&
        !_noLineEnd.contains(text.codeUnitAt(boundaries[end] - 1));

    for (var end = best; end > start && best - end <= 16; end--) {
      if (_punctuation.contains(text.codeUnitAt(boundaries[end] - 1)) &&
          isLegal(end)) {
        return end;
      }
    }
    for (var end = best; end > start && best - end <= 16; end--) {
      if (isLegal(end)) return end;
    }
    return best;
  }

  static const _noLineStart = {
    0x300D, // 」
    0x300F, // 』
    0x201D, // ”
    0x2019, // ’
    0xFF09, // ）
    0x300B, // 》
    0x3009, // 〉
    0x3011, // 】
    0x3015, // 〕
    0xFF3D, // ］
    0xFF5D, // ｝
    0x3001, // 、
    0x3002, // 。
    0xFF0C, // ，
    0xFF01, // ！
    0xFF1F, // ？
    0xFF1A, // ：
    0xFF1B, // ；
    0x2026, // …
    0x0029,
    0x005D,
    0x007D,
    0x002C,
    0x002E,
    0x0021,
    0x003F,
    0x003A,
    0x003B,
  };

  static const _noLineEnd = {
    0x300C, // 「
    0x300E, // 『
    0x201C, // “
    0x2018, // ‘
    0xFF08, // （
    0x300A, // 《
    0x3008, // 〈
    0x3010, // 【
    0x3014, // 〔
    0xFF3B, // ［
    0xFF5B, // ｛
    0x0028,
    0x005B,
    0x007B,
  };

  static const _punctuation = {
    0x300D,
    0x300F,
    0x201D,
    0x300B,
    0x3011,
    0x20,
    0x09,
    0x3000,
    0x3001,
    0x3002,
    0xFF0C,
    0xFF01,
    0xFF1F,
    0xFF1A,
    0xFF1B,
    0x2014,
    0x2026,
    0xFF09,
    0x002C,
    0x002E,
    0x003A,
    0x003B,
    0x003F,
    0x0021,
    0x0029,
  };
}
