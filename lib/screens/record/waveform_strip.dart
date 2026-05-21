import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Decorative live-looking waveform. Bars animate via a single repeating
/// AnimationController; heights are pseudo-random per bar and per tick.
class WaveformStrip extends StatefulWidget {
  const WaveformStrip({
    this.barCount = 28,
    this.height = 32,
    this.color = ColorTokens.accent,
    super.key,
  });

  final int barCount;
  final double height;
  final Color color;

  @override
  State<WaveformStrip> createState() => _WaveformStripState();
}

class _WaveformStripState extends State<WaveformStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  final math.Random _rng = math.Random(7);
  late final List<double> _phase = List<double>.generate(
    widget.barCount,
    (_) => _rng.nextDouble(),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(widget.barCount, (i) {
              final wobble = math.sin((_ctl.value * 2 * math.pi) + _phase[i] * 6.28);
              final amp = 0.3 + 0.7 * ((wobble + 1) / 2) * (0.5 + _phase[i] * 0.5);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 2,
                  height: widget.height * amp,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.55 + 0.45 * amp),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
