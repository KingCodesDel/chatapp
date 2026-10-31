import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated launch screen. Runs for [duration] (7 seconds by default):
/// drifting glow bubbles, a pulsing logo, the wordmark and tagline fading in,
/// and a progress bar that fills while rotating status lines change.
class SplashScreen extends StatefulWidget {
  final Duration duration;
  const SplashScreen({super.key, this.duration = const Duration(seconds: 7)});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _timeline = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  static const _lines = ['Connecting you...', 'Warming up your chats...', 'Syncing messages...', 'Almost there...'];

  @override
  void dispose() {
    _timeline.dispose();
    _pulse.dispose();
    _drift.dispose();
    super.dispose();
  }

  double _interval(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_timeline, _pulse, _drift]),
        builder: (context, _) {
          final t = _timeline.value;
          final logoIn = Curves.elasticOut.transform(_interval(t, 0.0, 0.22));
          final nameIn = Curves.easeOut.transform(_interval(t, 0.14, 0.32));
          final tagIn = Curves.easeOut.transform(_interval(t, 0.26, 0.44));
          final pulse = Curves.easeInOut.transform(_pulse.value);
          final line = _lines[math.min((t * _lines.length).floor(), _lines.length - 1)];

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.splashTop, AppColors.primaryDark, AppColors.splashBottom],
              ),
            ),
            child: Stack(
              children: [
                // Soft drifting glow bubbles
                ..._bubbles(context),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      // Pulsing rings + logo
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final k in [0.0, 0.5])
                              Builder(builder: (_) {
                                final p = (_drift.value * 4 + k) % 1.0;
                                return Opacity(
                                  opacity: (1 - p) * 0.35 * logoIn,
                                  child: Container(
                                    width: 100 + 90 * p,
                                    height: 100 + 90 * p,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                  ),
                                );
                              }),
                            Transform.scale(
                              scale: logoIn * (1 + 0.05 * pulse),
                              child: Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.6),
                                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.25 * pulse), blurRadius: 36, spreadRadius: 4)],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Opacity(
                        opacity: nameIn,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - nameIn)),
                          child: const Text(
                            'ChatVibe',
                            style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: tagIn,
                        child: Text('Connect • Share • Be Happy', style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15, letterSpacing: 0.6)),
                      ),
                      const Spacer(flex: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: t,
                                minHeight: 5,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(line, key: ValueKey(line), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _bubbles(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const specs = [
      // x, y (fractions), diameter, phase, opacity
      [0.12, 0.18, 120.0, 0.0, 0.10],
      [0.85, 0.12, 80.0, 0.3, 0.12],
      [0.78, 0.55, 150.0, 0.6, 0.08],
      [0.08, 0.7, 90.0, 0.8, 0.12],
      [0.5, 0.86, 110.0, 0.45, 0.09],
    ];
    return [
      for (final s in specs)
        Positioned(
          left: size.width * s[0] - s[2] / 2 + 14 * math.sin((_drift.value + s[3]) * 2 * math.pi),
          top: size.height * s[1] - s[2] / 2 + 18 * math.cos((_drift.value + s[3]) * 2 * math.pi),
          child: Container(
            width: s[2],
            height: s[2],
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: s[4])),
          ),
        ),
    ];
  }
}
