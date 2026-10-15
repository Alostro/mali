import 'dart:math' as math;

import 'package:flutter/material.dart';

class DonutSlice {
  const DonutSlice(this.value, this.color);
  final double value;
  final Color color;
}

/// Ring chart with a label in the middle.
class Donut extends StatelessWidget {
  const Donut({super.key, required this.slices, required this.center, this.size = 180});
  final List<DonutSlice> slices;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(slices, track),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.track);
  final List<DonutSlice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    const gap = 0.02;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      final drawSweep = slices.length > 1 ? math.max(0.0, sweep - gap) : sweep;
      canvas.drawArc(rect, start, drawSweep, false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.track != track;
}

/// Simple daily bars with an optional "daily allowance" line.
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.values,
    required this.labels,
    this.allowance,
    this.highlightIndex,
    this.height = 150,
  });

  final List<double> values;
  final List<String> labels; // one per bar; empty strings are skipped
  final double? allowance;
  final int? highlightIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarsPainter(
          values: values,
          labels: labels,
          allowance: allowance,
          highlightIndex: highlightIndex,
          bar: scheme.primary,
          over: scheme.error,
          muted: scheme.primary.withValues(alpha: 0.35),
          line: scheme.onSurfaceVariant,
          text: Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.labels,
    required this.allowance,
    required this.highlightIndex,
    required this.bar,
    required this.over,
    required this.muted,
    required this.line,
    required this.text,
  });

  final List<double> values;
  final List<String> labels;
  final double? allowance;
  final int? highlightIndex;
  final Color bar, over, muted, line;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 16.0;
    final chartH = size.height - labelH;
    final maxV = math.max(values.reduce(math.max), allowance ?? 0);
    if (maxV <= 0) return;
    final slot = size.width / values.length;
    final barW = math.max(2.0, slot * 0.62);

    for (var i = 0; i < values.length; i++) {
      final h = values[i] / maxV * (chartH - 4);
      final x = i * slot + (slot - barW) / 2;
      final future = highlightIndex != null && i > highlightIndex!;
      final color = future
          ? muted
          : (allowance != null && values[i] > allowance!)
              ? over
              : bar;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, chartH - h, barW, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = color,
      );
      if (i < labels.length && labels[i].isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: text),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * slot + slot / 2 - tp.width / 2, chartH + 2));
      }
    }

    if (allowance != null && allowance! > 0) {
      final y = chartH - allowance! / maxV * (chartH - 4);
      final paint = Paint()
        ..color = line
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
