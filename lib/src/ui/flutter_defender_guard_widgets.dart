part of '../../flutter_defender.dart';

abstract class _FlutterDefenderGuardState<T extends StatefulWidget>
    extends State<T> {
  final Object _token = Object();
  bool _registrationReady = false;

  FlutterDefender get defender => FlutterDefender.instance;

  FlutterDefenderGuardType get guardType;

  Widget get guardedChild;

  Future<void> _register() async {
    await defender.registerGuard(
      token: _token,
      type: guardType,
      popRoute: _popCurrentRoute,
    );
    if (mounted) {
      setState(() {
        _registrationReady = true;
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
  void initState() {
    super.initState();
    unawaited(_register());
  }

  @override
  void dispose() {
    unawaited(defender.unregisterGuard(_token));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: defender,
      builder: (BuildContext context, Widget? child) {
        final bool showChild =
            _registrationReady && !defender.shouldConcealGuardedContent;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: showChild
                  ? guardedChild
                  : defender.buildGuardPlaceholder(),
            ),
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
