part of '../../flutter_defender.dart';

abstract class _FlutterDefenderGuardState<T extends StatefulWidget>
    extends State<T> {
  final Object _token = Object();
  bool _registrationReady = false;
  bool _guardRegistered = false;
  bool? _lastShouldGuard;

  FlutterDefender get defender => FlutterDefender.instance;

  FlutterDefenderGuardType get guardType;

  Widget get guardedChild;

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
    final ValueListenable<bool> tickerModeNotifier = TickerMode.getNotifier(
      context,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[defender, tickerModeNotifier]),
      builder: (BuildContext context, Widget? child) {
        final bool isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
        final bool isRouteActiveInTree = tickerModeNotifier.value;
        final bool shouldGuard = isRouteCurrent && isRouteActiveInTree;
        _syncGuardRegistration(shouldGuard);
        final bool showChild =
            !shouldGuard ||
            (_registrationReady && !defender.shouldConcealGuardedContent);
        final Widget protectedChild = Opacity(
          opacity: showChild ? 1 : 0,
          child: guardedChild,
        );
        return Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            protectedChild,
            if (defender.hasBlockingOverlay)
              Positioned.fill(child: defender.buildBlockingOverlay(context)),
          ],
        );
      },
    );
  }
}

class FlutterDefenderSensitiveGuard extends StatefulWidget {
  const FlutterDefenderSensitiveGuard({required this.child, super.key});

  final Widget child;

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
