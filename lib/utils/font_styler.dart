import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lizaplayer/main.dart';

mixin FontStyler<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  TextStyle s(TextStyle style) {
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontWeightIndex = ref.watch(fontWeightProvider);
    final letterSpacing = ref.watch(letterSpacingProvider);
    final weights = [
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900
    ];
    final targetFontFamily =
        fontFamily ?? Theme.of(context).textTheme.bodyLarge?.fontFamily;
    return style.merge(TextStyle(
      fontFamily: targetFontFamily,
      fontWeight: weights[fontWeightIndex.clamp(0, 8)],
      letterSpacing: letterSpacing,
    ));
  }
}
