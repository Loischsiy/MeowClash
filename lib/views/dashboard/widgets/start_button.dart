import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

enum CatConnectionPhase {
  idle,
  connecting,
  connected,
  disconnecting,
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with TickerProviderStateMixin {
  static const Duration _phaseTransitionDuration = Duration(milliseconds: 650);
  static const Duration _minTransientPhaseVisible = Duration(milliseconds: 650);

  late final AnimationController _ambientController;
  late final AnimationController _phaseController;
  late final AnimationController _pressController;
  late final Animation<double> _phaseAnimation;
  late final Animation<double> _pressScale;

  CatConnectionPhase _phase = CatConnectionPhase.idle;
  CatConnectionPhase _previousPhase = CatConnectionPhase.idle;
  DateTime? _transientStartedAt;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _phaseController = AnimationController(
      vsync: this,
      duration: _phaseTransitionDuration,
      value: 1,
    );
    _phaseAnimation = CurvedAnimation(
      parent: _phaseController,
      curve: Curves.easeOutCubic,
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    final initiallyStarted = globalState.appState.runTime != null;
    _phase = initiallyStarted
        ? CatConnectionPhase.connected
        : CatConnectionPhase.idle;
    _previousPhase = _phase;

    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (prev, next) {
        _handleRuntimeChanged(next);
      },
      fireImmediately: true,
    );
  }

  /// Darwin with Reduce Motion: the cat sits still and swaps poses without the
  /// morph. Material always animates, as before.
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AdaptivePlatform.useGlass &&
        GlassAccessibility.of(context).reduceMotion;
    if (_reduceMotion) {
      _ambientController
        ..stop()
        ..value = 0;
      _phaseController.value = 1;
    } else if (!_ambientController.isAnimating) {
      _ambientController.repeat();
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _phaseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleRuntimeChanged(bool isStart) {
    final target =
        isStart ? CatConnectionPhase.connected : CatConnectionPhase.idle;
    if (_phase == target) return;

    final startedAt = _transientStartedAt;
    final isTransient = _phase == CatConnectionPhase.connecting ||
        _phase == CatConnectionPhase.disconnecting;

    if (startedAt != null && isTransient) {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minTransientPhaseVisible - elapsed;
      if (remaining.inMilliseconds > 0) {
        Future.delayed(remaining, () {
          if (!mounted) return;
          _setPhase(target);
        });
        return;
      }
    }
    _setPhase(target);
  }

  void _setPhase(CatConnectionPhase next) {
    if (_phase == next) return;
    setState(() {
      _previousPhase = _phase;
      _phase = next;
      _transientStartedAt = (next == CatConnectionPhase.connecting ||
              next == CatConnectionPhase.disconnecting)
          ? DateTime.now()
          : null;
    });
    if (_reduceMotion) {
      _phaseController.value = 1;
      return;
    }
    _phaseController
      ..stop()
      ..forward(from: 0);
  }

  void _handleTap() {
    if (_phase == CatConnectionPhase.connecting ||
        _phase == CatConnectionPhase.disconnecting) {
      return;
    }

    final isCurrentlyStart = globalState.appState.runTime != null;
    final wantStart = !isCurrentlyStart;

    _setPhase(
      wantStart
          ? CatConnectionPhase.connecting
          : CatConnectionPhase.disconnecting,
    );

    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(wantStart);
      },
      duration: commonDuration,
    );
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();
  void _onTapUp(TapUpDetails _) => _pressController.reverse();
  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.isInit || !state.hasProfile) {
      return Container();
    }
    if (AdaptivePlatform.useGlass) {
      return _buildGlass(context);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Colors.green.shade600.withValues(alpha: 0.92);
    final inactiveColor = colorScheme.secondaryContainer.withValues(alpha: 0.9);
    final connectingColor =
        colorScheme.tertiaryContainer.withValues(alpha: 0.95);

    Color backgroundColor;
    Color foregroundColor;
    switch (_phase) {
      case CatConnectionPhase.idle:
        backgroundColor = inactiveColor;
        foregroundColor = colorScheme.onSecondaryContainer;
        break;
      case CatConnectionPhase.connecting:
      case CatConnectionPhase.disconnecting:
        backgroundColor = connectingColor;
        foregroundColor = colorScheme.onTertiaryContainer;
        break;
      case CatConnectionPhase.connected:
        backgroundColor = activeColor;
        foregroundColor = Colors.white;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _ambientController,
          _phaseController,
          _pressController,
        ]),
        builder: (_, __) {
          final phaseProgress = _phaseAnimation.value;
          return Transform.scale(
            scale: _pressScale.value,
            child: SizedBox(
              width: double.infinity,
              height: 96,
              child: GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                onTap: _handleTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _phase == CatConnectionPhase.connected
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: _CatPainter(
                              phase: _phase,
                              previousPhase: _previousPhase,
                              phaseProgress: phaseProgress,
                              ambient: _ambientController.value,
                              foregroundColor: foregroundColor,
                              accentColor:
                                  _phase == CatConnectionPhase.connected
                                      ? Colors.amber.shade200
                                      : colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _phaseTitle(),
                                style: context.textTheme.titleMedium?.toSoftBold
                                    .copyWith(color: foregroundColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _StatusLine(
                                phase: _phase,
                                foregroundColor: foregroundColor,
                                ambient: _ambientController.value,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Darwin: the same shape and cat on a system fill — green when connected,
  /// a neutral gray when idle, an accent tint while connecting. A press dims
  /// the button instead of scaling it.
  Widget _buildGlass(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = theme.colorScheme.primary;
    final mac = AdaptivePlatform.isMacOSGlass;
    final (fill, foreground, catAccent) = switch (_phase) {
      CatConnectionPhase.idle => (
          GlassTokens.startButtonIdleFill(brightness),
          theme.colorScheme.onSurface,
          accent,
        ),
      CatConnectionPhase.connecting || CatConnectionPhase.disconnecting => (
          GlassTokens.startButtonConnectingFill(accent, brightness),
          theme.colorScheme.onSurface,
          accent,
        ),
      CatConnectionPhase.connected => (
          GlassTokens.systemGreen(brightness),
          GlassTokens.startButtonForegroundConnected,
          GlassTokens.startButtonCatAccentConnected,
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(GlassTokens.startButtonMargin),
      child: Semantics(
        button: true,
        container: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _ambientController,
              _phaseController,
              _pressController,
            ]),
            builder: (context, _) => Opacity(
              opacity: 1 -
                  (1 - GlassTokens.startButtonPressedOpacity) *
                      _pressController.value,
              child: AnimatedContainer(
                duration: GlassTokens.motion(
                  GlassTokens.startButtonFillDuration,
                  reduceMotion: _reduceMotion,
                ),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: GlassTokens.startButtonHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: GlassTokens.startButtonPaddingH,
                  vertical: GlassTokens.startButtonPaddingV,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(
                    GlassTokens.startButtonRadius(mac: mac),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: GlassTokens.startButtonCatSize,
                      child: CustomPaint(
                        painter: _CatPainter(
                          phase: _phase,
                          previousPhase: _previousPhase,
                          phaseProgress: _phaseAnimation.value,
                          ambient: _ambientController.value,
                          foregroundColor: foreground,
                          accentColor: catAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: GlassTokens.startButtonCatGap),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _phaseTitle(),
                            style: GlassTextStyles.startButtonTitle(
                              theme.textTheme,
                            ).copyWith(color: foreground),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(
                            height: GlassTokens.startButtonTitleGap,
                          ),
                          _StatusLine(
                            phase: _phase,
                            foregroundColor: foreground,
                            ambient: _ambientController.value,
                            glass: true,
                            reduceMotion: _reduceMotion,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _phaseTitle() {
    switch (_phase) {
      case CatConnectionPhase.idle:
      case CatConnectionPhase.connecting:
        return appLocalizations.start;
      case CatConnectionPhase.connected:
      case CatConnectionPhase.disconnecting:
        return appLocalizations.stop;
    }
  }
}

class _StatusLine extends ConsumerWidget {
  const _StatusLine({
    required this.phase,
    required this.foregroundColor,
    required this.ambient,
    this.glass = false,
    this.reduceMotion = false,
  });

  final CatConnectionPhase phase;
  final Color foregroundColor;
  final double ambient;

  /// Darwin: SF text scale, Glass buttons for the TUN error, no cross-fade.
  final bool glass;

  /// Darwin with Reduce Motion: the progress dots stand still.
  final bool reduceMotion;

  Widget _buildGlass(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mac = AdaptivePlatform.isMacOSGlass;
    final style = GlassTextStyles.startButtonStatus(theme.textTheme).copyWith(
      color: foregroundColor.withValues(
        alpha: GlassTokens.startButtonStatusOpacity,
      ),
    );
    final tunFailure = ref.watch(tunStartFailureProvider);
    if (tunFailure != null) {
      // A Wrap, not a Row: with large text or a narrow window the buttons
      // move under the message instead of overflowing.
      return Wrap(
        spacing: GlassTokens.startButtonActionGap,
        runSpacing: GlassTokens.startButtonActionGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            appLocalizations.tunStartFailed,
            style: style.copyWith(
              color: GlassTokens.systemRed(theme.brightness),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          GlassIconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: appLocalizations.logs,
            size: mac
                ? GlassTokens.widgetHeaderButtonSizeMac
                : GlassTokens.widgetHeaderButtonSizeIos,
            iconSize: mac
                ? GlassTokens.widgetHeaderButtonIconSizeMac
                : GlassTokens.widgetHeaderButtonIconSizeIos,
            onPressed: () => _showTunFailure(context, tunFailure),
          ),
          GlassButton(
            label: appLocalizations.repair,
            onPressed: globalState.appController.repairTun,
            kind: GlassButtonKind.plain,
            destructive: true,
          ),
        ],
      );
    }
    switch (phase) {
      case CatConnectionPhase.connecting:
      case CatConnectionPhase.disconnecting:
        final dotCount = reduceMotion ? 3 : ((ambient * 6) % 3).floor() + 1;
        return ExcludeSemantics(
          child: Text(
            '·' * dotCount,
            style: style.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: GlassTokens.startButtonDotsSpacing,
            ),
          ),
        );
      case CatConnectionPhase.connected:
        final runTime = ref.watch(runTimeProvider);
        if (runTime == null) return const SizedBox.shrink();
        return Text(
          utils.getTimeText(runTime),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case CatConnectionPhase.idle:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (glass) return _buildGlass(context, ref);
    final textStyle = context.textTheme.bodyMedium?.copyWith(
      color: foregroundColor.withValues(alpha: 0.85),
    );

    Widget child;
    final tunFailure = ref.watch(tunStartFailureProvider);
    if (tunFailure != null) {
      child = Row(
        children: [
          Expanded(
            child: Text(
              appLocalizations.tunStartFailed,
              style: textStyle?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showTunFailure(context, tunFailure),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            tooltip: appLocalizations.logs,
            visualDensity: VisualDensity.compact,
          ),
          TextButton(
            onPressed: globalState.appController.repairTun,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(appLocalizations.repair),
          ),
        ],
      );
    } else {
      switch (phase) {
        case CatConnectionPhase.connecting:
        case CatConnectionPhase.disconnecting:
          final dotCount = ((ambient * 6) % 3).floor() + 1;
          child = Text(
            '·' * dotCount,
            key: ValueKey('cat-status-${phase.name}-$dotCount'),
            style: textStyle?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          );
          break;
        case CatConnectionPhase.connected:
          final runTime = ref.watch(runTimeProvider);
          if (runTime != null) {
            final text = utils.getTimeText(runTime);
            child = Text(
              text,
              key: ValueKey('cat-status-connected-$text'),
              style: textStyle,
            );
          } else {
            child = const SizedBox.shrink(
              key: ValueKey('cat-status-connected-empty'),
            );
          }
          break;
        case CatConnectionPhase.idle:
          child = const SizedBox.shrink(key: ValueKey('cat-status-idle'));
          break;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}

/// The TUN start error in full. D.7 moves Darwin to `CommonDialog`.
void _showTunFailure(BuildContext context, String tunFailure) {
  globalState.showCommonDialog<void>(
    child: AlertDialog(
      title: Text(appLocalizations.tunStartFailed),
      content: SingleChildScrollView(
        child: SelectableText(
          tunFailure.isEmpty ? appLocalizations.tunStartFailed : tunFailure,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
    ),
  );
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.phase,
    required this.previousPhase,
    required this.phaseProgress,
    required this.ambient,
    required this.foregroundColor,
    required this.accentColor,
  });

  final CatConnectionPhase phase;
  final CatConnectionPhase previousPhase;
  final double phaseProgress;
  final double ambient;
  final Color foregroundColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final prevTraits = _traitsFor(previousPhase);
    final nextTraits = _traitsFor(phase);
    final t = phaseProgress.clamp(0.0, 1.0);
    final traits = _CatTraits.lerp(prevTraits, nextTraits, t);

    final ambientRad = ambient * 2 * math.pi;

    final breathPhase = math.sin(ambientRad);
    final breathScale = 1 + 0.02 * breathPhase * traits.breathStrength;
    final bobOffset = 1.2 * breathPhase * traits.breathStrength;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2 + bobOffset)
      ..scale(breathScale, breathScale);

    final s = math.min(size.width, size.height) / 100;

    _drawTail(canvas, s, traits, ambientRad);
    _drawBody(canvas, s, traits);
    _drawHead(canvas, s, traits, ambientRad);
    _drawZ(canvas, s, traits);
    _drawSparkles(canvas, s, traits);

    canvas.restore();
  }

  _CatTraits _traitsFor(CatConnectionPhase p) {
    switch (p) {
      case CatConnectionPhase.idle:
        return const _CatTraits(
          eyeOpen: 0.0,
          earUp: 0.15,
          mouthCurve: 0.0,
          mouthOpen: 0.0,
          tailWagSpeed: 0.6,
          tailWagAmplitude: 0.15,
          headTilt: -0.08,
          headTurn: 0.0,
          headTurnSpeed: 0.0,
          pupilFocus: 0.4,
          zStrength: 1.0,
          sparkleStrength: 0.0,
          cheekBlush: 0.0,
          breathStrength: 1.0,
        );
      case CatConnectionPhase.connecting:
        return const _CatTraits(
          eyeOpen: 0.85,
          earUp: 1.0,
          mouthCurve: -0.05,
          mouthOpen: 0.25,
          tailWagSpeed: 4.5,
          tailWagAmplitude: 0.7,
          headTilt: 0.0,
          headTurn: 1.0,
          headTurnSpeed: 2.4,
          pupilFocus: 0.0,
          zStrength: 0.0,
          sparkleStrength: 0.0,
          cheekBlush: 0.2,
          breathStrength: 0.6,
        );
      case CatConnectionPhase.connected:
        return const _CatTraits(
          eyeOpen: 1.0,
          earUp: 1.0,
          mouthCurve: 0.55,
          mouthOpen: 0.0,
          tailWagSpeed: 1.6,
          tailWagAmplitude: 0.45,
          headTilt: 0.05,
          headTurn: 0.0,
          headTurnSpeed: 0.0,
          pupilFocus: 0.8,
          zStrength: 0.0,
          sparkleStrength: 1.0,
          cheekBlush: 0.6,
          breathStrength: 0.8,
        );
      case CatConnectionPhase.disconnecting:
        return const _CatTraits(
          eyeOpen: 0.35,
          earUp: 0.4,
          mouthCurve: -0.1,
          mouthOpen: 0.6,
          tailWagSpeed: 1.0,
          tailWagAmplitude: 0.2,
          headTilt: -0.05,
          headTurn: 0.0,
          headTurnSpeed: 0.0,
          pupilFocus: 0.3,
          zStrength: 0.3,
          sparkleStrength: 0.0,
          cheekBlush: 0.0,
          breathStrength: 1.4,
        );
    }
  }

  void _drawTail(
    Canvas canvas,
    double s,
    _CatTraits traits,
    double ambientRad,
  ) {
    final wag =
        math.sin(ambientRad * traits.tailWagSpeed) * traits.tailWagAmplitude;
    final tailPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7 * s;

    final start = Offset(22 * s, 18 * s);
    final control = Offset(38 * s + 14 * s * wag, -10 * s - 10 * s * wag);
    final end = Offset(28 * s + 22 * s * wag, -28 * s - 6 * s * wag.abs());

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(path, tailPaint);
  }

  void _drawBody(Canvas canvas, double s, _CatTraits traits) {
    final bodyPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    final bodyRect = Rect.fromCenter(
      center: Offset(0, 14 * s),
      width: 56 * s,
      height: 44 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        bodyRect,
        topLeft: Radius.circular(20 * s),
        topRight: Radius.circular(20 * s),
        bottomLeft: Radius.circular(24 * s),
        bottomRight: Radius.circular(24 * s),
      ),
      bodyPaint,
    );

    final pawPaint = Paint()..color = foregroundColor;
    canvas
      ..drawCircle(Offset(-14 * s, 32 * s), 7 * s, pawPaint)
      ..drawCircle(Offset(14 * s, 32 * s), 7 * s, pawPaint);

    if (traits.sparkleStrength > 0.3) {
      final nailPaint = Paint()..color = foregroundColor.withValues(alpha: 0.4);
      for (final cx in [-16.0, -14.0, -12.0]) {
        canvas.drawCircle(Offset(cx * s, 34.5 * s), 0.8 * s, nailPaint);
      }
      for (final cx in [12.0, 14.0, 16.0]) {
        canvas.drawCircle(Offset(cx * s, 34.5 * s), 0.8 * s, nailPaint);
      }
    }
  }

  void _drawHead(
    Canvas canvas,
    double s,
    _CatTraits traits,
    double ambientRad,
  ) {
    canvas.save();

    final headTurn = traits.headTurn *
        math.sin(ambientRad * (traits.headTurnSpeed.clamp(0.0, 8.0))) *
        0.18;
    final headTilt = traits.headTilt;
    final headCenter = Offset(0, -12 * s);

    canvas
      ..translate(headCenter.dx, headCenter.dy)
      ..rotate(headTilt + headTurn);

    final headPaint = Paint()..color = foregroundColor;

    _drawEars(canvas, s, traits, headPaint);

    canvas.drawCircle(Offset.zero, 22 * s, headPaint);

    if (traits.cheekBlush > 0) {
      final blushPaint = Paint()
        ..color = Colors.pink.withValues(alpha: 0.25 * traits.cheekBlush);
      canvas
        ..drawCircle(Offset(-12 * s, 6 * s), 4.5 * s, blushPaint)
        ..drawCircle(Offset(12 * s, 6 * s), 4.5 * s, blushPaint);
    }

    _drawEyes(canvas, s, traits, ambientRad);
    _drawNoseAndMouth(canvas, s, traits);
    _drawWhiskers(canvas, s);

    canvas.restore();
  }

  void _drawEars(
    Canvas canvas,
    double s,
    _CatTraits traits,
    Paint headPaint,
  ) {
    final earUp = traits.earUp.clamp(0.0, 1.0);

    void drawEar({required bool right}) {
      final sign = right ? 1.0 : -1.0;
      final droopAngle = sign * math.pi / 2.6;
      final upAngle = sign * math.pi / 6;
      final angle = _lerpDouble(droopAngle, upAngle, earUp);

      final baseX = sign * 12 * s;
      final baseY = -16 * s;

      final tipDistance = _lerpDouble(14.0, 18.0, earUp) * s;
      final tipX = baseX + math.sin(angle) * tipDistance;
      final tipY = baseY - math.cos(angle) * tipDistance;

      final p1 = Offset(baseX - sign * 8 * s, baseY + 1 * s);
      final p2 = Offset(baseX + sign * 8 * s, baseY - 3 * s);
      final p3 = Offset(tipX, tipY);

      final earPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(earPath, headPaint);

      final innerPaint = Paint()
        ..color = Colors.pink.shade200.withValues(alpha: 0.7);
      final ip1 = Offset.lerp(p1, p3, 0.35)!;
      final ip2 = Offset.lerp(p2, p3, 0.35)!;
      final midBase = Offset.lerp(p1, p2, 0.5)!;
      final ip3 = Offset.lerp(p3, midBase, 0.25)!;
      final innerPath = Path()
        ..moveTo(ip1.dx, ip1.dy)
        ..lineTo(ip2.dx, ip2.dy)
        ..lineTo(ip3.dx, ip3.dy)
        ..close();
      canvas.drawPath(innerPath, innerPaint);
    }

    drawEar(right: false);
    drawEar(right: true);
  }

  void _drawEyes(
    Canvas canvas,
    double s,
    _CatTraits traits,
    double ambientRad,
  ) {
    var eyeOpen = traits.eyeOpen;
    if (phase == CatConnectionPhase.connected) {
      final blinkPhase = (ambient * 4) % 1;
      if (blinkPhase < 0.06) {
        final p = blinkPhase / 0.06;
        eyeOpen *= 1 - math.sin(p * math.pi);
      }
    }

    final eyeOffsets = [Offset(-9 * s, 0), Offset(9 * s, 0)];

    final pupilTarget = traits.pupilFocus;
    final pupilShiftX =
        math.sin(ambientRad * 0.6) * 1.2 * s * (1 - pupilTarget);
    final pupilShiftY =
        math.cos(ambientRad * 0.5) * 0.8 * s * (1 - pupilTarget);

    for (final center in eyeOffsets) {
      if (eyeOpen < 0.04) {
        final closedPaint = Paint()
          ..color = foregroundColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6 * s;
        final rect = Rect.fromCenter(
          center: center,
          width: 8 * s,
          height: 6 * s,
        );
        canvas.drawArc(rect, math.pi, math.pi, false, closedPaint);
      } else {
        final eyePaint = Paint()..color = Colors.white;
        final eyeRect = Rect.fromCenter(
          center: center,
          width: 7 * s,
          height: 9 * s * eyeOpen,
        );
        canvas.drawOval(eyeRect, eyePaint);

        if (eyeOpen > 0.25) {
          final pupilPaint = Paint()..color = Colors.black87;
          final pupilRect = Rect.fromCenter(
            center: Offset(
              center.dx + pupilShiftX,
              center.dy + pupilShiftY,
            ),
            width: 3.4 * s,
            height: 6 * s * eyeOpen,
          );
          canvas.drawOval(pupilRect, pupilPaint);

          final glintPaint = Paint()..color = Colors.white;
          canvas.drawCircle(
            Offset(
              center.dx + pupilShiftX + 0.8 * s,
              center.dy + pupilShiftY - 1.5 * s * eyeOpen,
            ),
            0.9 * s,
            glintPaint,
          );
        }
      }
    }
  }

  void _drawNoseAndMouth(Canvas canvas, double s, _CatTraits traits) {
    final nosePaint = Paint()..color = Colors.pink.shade300;
    final nosePath = Path()
      ..moveTo(-2.2 * s, 7 * s)
      ..lineTo(2.2 * s, 7 * s)
      ..lineTo(0, 9.5 * s)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    final mouthPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6 * s;

    final mouthOpen = traits.mouthOpen.clamp(0.0, 1.0);

    if (mouthOpen > 0.05) {
      final openPaint = Paint()..color = Colors.pink.shade100;
      final openRect = Rect.fromCenter(
        center: Offset(0, 12 * s),
        width: 6 * s,
        height: 6 * s * mouthOpen,
      );
      canvas
        ..drawOval(openRect, openPaint)
        ..drawLine(
          Offset(0, 9.5 * s),
          Offset(0, 11 * s),
          mouthPaint,
        );
    } else {
      final curve = traits.mouthCurve.clamp(-1.0, 1.0);
      final dipY = _lerpDouble(13.5, 11.5, (curve + 1) / 2) * s;
      final endY = _lerpDouble(11.5, 13.5, (curve + 1) / 2) * s;

      final leftPath = Path()
        ..moveTo(0, 9.5 * s)
        ..quadraticBezierTo(-3 * s, dipY, -5 * s, endY);
      final rightPath = Path()
        ..moveTo(0, 9.5 * s)
        ..quadraticBezierTo(3 * s, dipY, 5 * s, endY);
      canvas
        ..drawPath(leftPath, mouthPaint)
        ..drawPath(rightPath, mouthPaint);
    }
  }

  void _drawWhiskers(Canvas canvas, double s) {
    final whiskerPaint = Paint()
      ..color = foregroundColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0 * s;

    for (final sign in [-1.0, 1.0]) {
      final base = Offset(sign * 4 * s, 9 * s);
      for (final yOff in [-1.5, 0.0, 1.5]) {
        final end = Offset(sign * 18 * s, 9 * s + yOff * s);
        canvas.drawLine(base, end, whiskerPaint);
      }
    }
  }

  void _drawZ(Canvas canvas, double s, _CatTraits traits) {
    if (traits.zStrength <= 0.05) return;

    final zPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    for (var i = 0; i < 3; i++) {
      final t = ((ambient * 2) + i * 0.33) % 1;
      final opacity = (1 - t) * traits.zStrength;
      if (opacity <= 0) continue;

      zPaint
        ..text = TextSpan(
          text: 'z',
          style: TextStyle(
            color: foregroundColor.withValues(alpha: opacity.clamp(0.0, 1.0)),
            fontSize: (10 + 4 * t) * s,
            fontWeight: FontWeight.w700,
          ),
        )
        ..layout()
        ..paint(
          canvas,
          Offset(
            14 * s + 6 * s * t,
            -32 * s - 20 * s * t,
          ),
        );
    }
  }

  void _drawSparkles(Canvas canvas, double s, _CatTraits traits) {
    if (traits.sparkleStrength <= 0.05) return;

    final positions = [
      Offset(-30 * s, -22 * s),
      Offset(28 * s, -28 * s),
      Offset(-32 * s, 4 * s),
      Offset(34 * s, 6 * s),
    ];

    for (var i = 0; i < positions.length; i++) {
      final t = ((ambient * 1.5) + i * 0.27) % 1;
      final alpha = math.sin(t * math.pi) * traits.sparkleStrength;
      if (alpha <= 0.02) continue;

      final paint = Paint()
        ..color = accentColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      _drawSparkle(canvas, positions[i], (2.5 + 1.5 * t) * s, paint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      final inner = radius * 0.35;
      final midAngle = angle + math.pi / 4;
      final mx = math.cos(midAngle) * inner;
      final my = math.sin(midAngle) * inner;
      if (i == 0) {
        path.moveTo(center.dx + dx, center.dy + dy);
      } else {
        path.lineTo(center.dx + dx, center.dy + dy);
      }
      path.lineTo(center.dx + mx, center.dy + my);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CatPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.previousPhase != previousPhase ||
      oldDelegate.phaseProgress != phaseProgress ||
      oldDelegate.ambient != ambient ||
      oldDelegate.foregroundColor != foregroundColor ||
      oldDelegate.accentColor != accentColor;
}

class _CatTraits {
  const _CatTraits({
    required this.eyeOpen,
    required this.earUp,
    required this.mouthCurve,
    required this.mouthOpen,
    required this.tailWagSpeed,
    required this.tailWagAmplitude,
    required this.headTilt,
    required this.headTurn,
    required this.headTurnSpeed,
    required this.pupilFocus,
    required this.zStrength,
    required this.sparkleStrength,
    required this.cheekBlush,
    required this.breathStrength,
  });

  factory _CatTraits.lerp(_CatTraits a, _CatTraits b, double t) => _CatTraits(
        eyeOpen: _lerpDouble(a.eyeOpen, b.eyeOpen, t),
        earUp: _lerpDouble(a.earUp, b.earUp, t),
        mouthCurve: _lerpDouble(a.mouthCurve, b.mouthCurve, t),
        mouthOpen: _lerpDouble(a.mouthOpen, b.mouthOpen, t),
        tailWagSpeed: _lerpDouble(a.tailWagSpeed, b.tailWagSpeed, t),
        tailWagAmplitude:
            _lerpDouble(a.tailWagAmplitude, b.tailWagAmplitude, t),
        headTilt: _lerpDouble(a.headTilt, b.headTilt, t),
        headTurn: _lerpDouble(a.headTurn, b.headTurn, t),
        headTurnSpeed: _lerpDouble(a.headTurnSpeed, b.headTurnSpeed, t),
        pupilFocus: _lerpDouble(a.pupilFocus, b.pupilFocus, t),
        zStrength: _lerpDouble(a.zStrength, b.zStrength, t),
        sparkleStrength: _lerpDouble(a.sparkleStrength, b.sparkleStrength, t),
        cheekBlush: _lerpDouble(a.cheekBlush, b.cheekBlush, t),
        breathStrength: _lerpDouble(a.breathStrength, b.breathStrength, t),
      );

  final double eyeOpen;
  final double earUp;
  final double mouthCurve;
  final double mouthOpen;
  final double tailWagSpeed;
  final double tailWagAmplitude;
  final double headTilt;
  final double headTurn;
  final double headTurnSpeed;
  final double pupilFocus;
  final double zStrength;
  final double sparkleStrength;
  final double cheekBlush;
  final double breathStrength;
}
