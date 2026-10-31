import 'package:flutter/material.dart';

/// The NOOR mark (crescent with a play symbol), drawn in code on the same
/// 1024-unit grid as the launcher icon so the in-app logo matches it.
class NoorMark extends StatelessWidget {
  const NoorMark({super.key, this.size = 96, this.withBackground = true});
  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Noor',
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(withBackground),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.withBackground);
  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);

    if (withBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(full, const Radius.circular(230)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A1D78), Color(0xFF14092B)],
          ).createShader(full),
      );
    }

    final outer = Path()
      ..addOval(Rect.fromCircle(center: const Offset(512, 512), radius: 330));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: const Offset(652, 470), radius: 285));
    final crescent = Path.combine(PathOperation.difference, outer, cut);
    canvas.drawPath(
      crescent,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEADDFF), Color(0xFF9B6BFF)],
        ).createShader(const Rect.fromLTWH(182, 182, 660, 660)),
    );

    final tri = Path()
      ..moveTo(537, 430)
      ..lineTo(537, 594)
      ..lineTo(682, 512)
      ..close();
    final playPaint = Paint()..color = const Color(0xFFF3ECFF);
    canvas.drawPath(tri, playPaint);
    canvas.drawPath(
      tri,
      playPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 36
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.withBackground != withBackground;
}
