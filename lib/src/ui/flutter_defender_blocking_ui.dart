part of '../../flutter_defender.dart';

extension _FlutterDefenderBlockingUi on FlutterDefender {
  Widget buildBlockingOverlay(BuildContext context) {
    final FlutterDefenderMessageId? messageId =
        _runtime.blockingMessageId.value;
    if (messageId == null) {
      return const SizedBox.shrink();
    }

    return _wrapBlockingLocalizationScope(
      context,
      Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          AbsorbPointer(
            absorbing: true,
            child: Builder(
              builder: (BuildContext innerContext) {
                final String message = _resolveBlockingMessage(
                  innerContext,
                  messageId,
                );
                final String? explicitTitle =
                    _config.blockingTitleResolver != null
                    ? _resolveBlockingTitle(innerContext)
                    : null;
                return _config.blockingScreenBuilder?.call(message) ??
                    BlockingScreen(
                      title: explicitTitle,
                      message: message,
                      theme: _config.uiTheme,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapBlockingLocalizationScope(
    BuildContext overlayContext,
    Widget child,
  ) {
    final Locale? forced = _config.blockingLocale;
    if (forced == null) {
      return child;
    }
    return Localizations.override(
      context: overlayContext,
      locale: forced,
      delegates: FlutterDefenderLocalizations.localizationsDelegates,
      child: Directionality(
        textDirection: flutterDefenderTextDirectionForLocale(forced),
        child: child,
      ),
    );
  }

  String _resolveBlockingMessage(
    BuildContext context,
    FlutterDefenderMessageId messageId,
  ) {
    final String Function(BuildContext, FlutterDefenderMessageId)? resolver =
        _config.messageResolver;
    if (resolver != null) {
      return resolver(context, messageId);
    }
    return FlutterDefenderMessages.resolved(context, messageId);
  }

  String _resolveBlockingTitle(BuildContext context) {
    final String Function(BuildContext)? resolver =
        _config.blockingTitleResolver;
    if (resolver != null) {
      return resolver(context);
    }
    return FlutterDefenderMessages.blockingTitleFor(context);
  }
}
