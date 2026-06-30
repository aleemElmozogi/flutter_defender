part of '../../flutter_defender.dart';

/// Builds the replacement content shown while a guarded subtree is concealed.
typedef FlutterDefenderConcealmentBuilder =
    Widget Function(BuildContext context);

class FlutterDefenderConcealmentPlaceholder extends StatelessWidget {
  const FlutterDefenderConcealmentPlaceholder({
    required this.message,
    super.key,
    this.title,
    this.theme = FlutterDefenderUiTheme.defaults,
    this.compact = false,
  });

  final String message;
  final String? title;
  final FlutterDefenderUiTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return BlockingScreen(message: message, title: title, theme: theme);
    }

    final Color foregroundColor =
        theme.bodyStyle.color ?? const Color(0xFFD0D8E3);
    final TextStyle titleStyle = theme.titleStyle.copyWith(
      fontSize: (theme.titleStyle.fontSize ?? 22).clamp(14, 17).toDouble(),
    );
    final TextStyle bodyStyle = theme.bodyStyle.copyWith(
      fontSize: (theme.bodyStyle.fontSize ?? 16).clamp(12, 14).toDouble(),
      height: 1.35,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(theme.logoCardBorderRadius),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.cardPadding),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.visibility_off_outlined,
                    color: foregroundColor,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title ?? FlutterDefenderMessages.blockingTitleFor(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: bodyStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract class _FlutterDefenderGuardState<T extends StatefulWidget>
    extends State<T> {
  final Object _token = Object();
  bool _registrationReady = false;
  bool _guardRegistered = false;
  bool? _lastShouldGuard;

  FlutterDefender get defender => FlutterDefender.instance;

  FlutterDefenderGuardType get guardType;

  Widget get guardedChild;

  FlutterDefenderConcealmentBuilder? get concealmentBuilder => null;

  bool get showsBlockingOverlay => true;

  Future<void> _register() async {
    if (_guardRegistered) {
      return;
    }
    await defender.registerGuard(
      token: _token,
      type: guardType,
      popRoute: _popCurrentRoute,
    );
    _guardRegistered = true;
    if (mounted) {
      setState(() {
        _registrationReady = true;
      });
    }
  }

  Future<void> _unregister() async {
    if (!_guardRegistered) {
      return;
    }
    _guardRegistered = false;
    await defender.unregisterGuard(_token);
    if (mounted) {
      setState(() {
        _registrationReady = false;
      });
    }
  }

  void _popCurrentRoute() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).maybePop();
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    unawaited(_unregister());
    super.dispose();
  }

  void _syncGuardRegistration(bool shouldGuard) {
    if (_lastShouldGuard == shouldGuard) {
      return;
    }
    _lastShouldGuard = shouldGuard;
    if (shouldGuard) {
      unawaited(_register());
    } else {
      unawaited(_unregister());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ValueListenable<TickerModeData> tickerModeNotifier =
        TickerMode.getValuesNotifier(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[defender, tickerModeNotifier]),
      builder: (BuildContext context, Widget? child) {
        final bool isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
        final bool isRouteActiveInTree = tickerModeNotifier.value.enabled;
        final bool shouldGuard = isRouteCurrent && isRouteActiveInTree;
        _syncGuardRegistration(shouldGuard);
        final bool concealContent =
            shouldGuard &&
            (!_registrationReady ||
                defender.shouldConcealGuardedContent ||
                defender.hasBlockingOverlay);
        final Widget protectedChild = ExcludeSemantics(
          excluding: concealContent,
          child: Opacity(opacity: concealContent ? 0 : 1, child: guardedChild),
        );
        final bool showPlaceholder =
            concealContent &&
            (!showsBlockingOverlay || !defender.hasBlockingOverlay);
        return AbsorbPointer(
          absorbing: concealContent,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              protectedChild,
              if (showPlaceholder)
                Positioned.fill(
                  child: defender.buildConcealmentPlaceholder(
                    context,
                    compact: !showsBlockingOverlay,
                    builder: concealmentBuilder,
                  ),
                ),
              if (showsBlockingOverlay && defender.hasBlockingOverlay)
                Positioned.fill(child: defender.buildBlockingOverlay(context)),
            ],
          ),
        );
      },
    );
  }
}

class FlutterDefenderSensitiveGuard extends StatefulWidget {
  const FlutterDefenderSensitiveGuard({
    required this.child,
    super.key,
    this.placeholderBuilder,
  });

  final Widget child;
  final FlutterDefenderConcealmentBuilder? placeholderBuilder;

  @override
  State<FlutterDefenderSensitiveGuard> createState() =>
      _FlutterDefenderSensitiveGuardState();
}

class _FlutterDefenderSensitiveGuardState
    extends _FlutterDefenderGuardState<FlutterDefenderSensitiveGuard> {
  @override
  FlutterDefenderGuardType get guardType => FlutterDefenderGuardType.sensitive;

  @override
  Widget get guardedChild => widget.child;

  @override
  FlutterDefenderConcealmentBuilder? get concealmentBuilder =>
      widget.placeholderBuilder;
}

class FlutterDefenderSecureContentGuard extends StatefulWidget {
  const FlutterDefenderSecureContentGuard({
    required this.child,
    super.key,
    this.placeholderBuilder,
  });

  final Widget child;
  final FlutterDefenderConcealmentBuilder? placeholderBuilder;

  @override
  State<FlutterDefenderSecureContentGuard> createState() =>
      _FlutterDefenderSecureContentGuardState();
}

class _FlutterDefenderSecureContentGuardState
    extends _FlutterDefenderGuardState<FlutterDefenderSecureContentGuard> {
  @override
  FlutterDefenderGuardType get guardType => FlutterDefenderGuardType.sensitive;

  @override
  Widget get guardedChild => widget.child;

  @override
  FlutterDefenderConcealmentBuilder? get concealmentBuilder =>
      widget.placeholderBuilder;

  @override
  bool get showsBlockingOverlay => false;
}

class FlutterDefenderOtpGuard extends StatefulWidget {
  const FlutterDefenderOtpGuard({required this.child, super.key});

  final Widget child;

  @override
  State<FlutterDefenderOtpGuard> createState() =>
      _FlutterDefenderOtpGuardState();
}

class _FlutterDefenderOtpGuardState
    extends _FlutterDefenderGuardState<FlutterDefenderOtpGuard> {
  @override
  FlutterDefenderGuardType get guardType => FlutterDefenderGuardType.otp;

  @override
  Widget get guardedChild => widget.child;
}
