import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass.dart';
import 'haptics.dart';

/// Verification is deliberate movement to the end, with no timed arming.
/// Short drags, taps, cancellation and dismissing the dialog never verify.
class SlideToVerify extends StatefulWidget {
  const SlideToVerify({super.key, required this.onVerified});
  final VoidCallback onVerified;
  @override
  State<SlideToVerify> createState() => _SlideToVerifyState();
}

class _SlideToVerifyState extends State<SlideToVerify> {
  double progress = 0;
  bool dragging = false, verified = false;
  void update(double value, {bool commit = false}) {
    if (verified) return;
    setState(() => progress = value.clamp(0, 1));
    if (commit && progress >= .95) {
      verified = true;
      AppHaptics.success();
      widget.onVerified();
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        update(progress + .2, commit: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        update(progress - .2);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Semantics(
      label: 'Slide to verify',
      hint: 'Move the handle fully to the right to confirm.',
      slider: true,
      value: '${(progress * 100).round()} percent',
      increasedValue: '${((progress + .2).clamp(0, 1) * 100).round()} percent',
      decreasedValue: '${((progress - .2).clamp(0, 1) * 100).round()} percent',
      onIncrease: () => update(progress + .2, commit: true),
      onDecrease: () => update(progress - .2),
      child: LayoutBuilder(
        builder: (context, box) {
          final range = (box.maxWidth - 64).clamp(1, double.infinity);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (event) =>
                dragging = event.localPosition.dx <= 70,
            onHorizontalDragUpdate: (event) {
              if (dragging) update(progress + event.delta.dx / range);
            },
            onHorizontalDragEnd: (_) {
              if (dragging && progress >= .95) {
                update(1, commit: true);
              } else {
                update(0);
              }
              dragging = false;
            },
            onHorizontalDragCancel: () {
              dragging = false;
              update(0);
            },
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: fill(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: separator(context).withValues(alpha: .25),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 62 + range * progress,
                      child: Container(color: accent.withValues(alpha: .12)),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 58, right: 12),
                        child: Center(
                          child: Opacity(
                            opacity: (1 - progress * 1.5).clamp(0, 1),
                            child: Text(
                              'Slide to verify',
                              style: TextStyle(
                                color: ink(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: dragging ? Duration.zero : motion(context),
                      curve: Curves.easeOutCubic,
                      left: 5 + range * progress,
                      top: 5,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff2d97ff), accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: .22),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_right_2,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
