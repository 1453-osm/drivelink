import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Constrains wide sub-pages to a readable width while preserving full height.
class ResponsivePageBody extends StatelessWidget {
  const ResponsivePageBody({
    super.key,
    required this.child,
    this.maxWidth = 1100,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(maxWidth, constraints.maxWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
