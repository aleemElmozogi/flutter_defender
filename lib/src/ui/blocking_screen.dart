import 'package:flutter/material.dart';

import 'flutter_defender_messages.dart';
import 'flutter_defender_ui_theme.dart';

class BlockingScreen extends StatelessWidget {
  const BlockingScreen({
    super.key,
    required this.message,
    this.title,
    this.theme = FlutterDefenderUiTheme.defaults,
  });

  final String message;

  /// When null, the title is resolved from [FlutterDefenderLocalizations] or
  /// English fallback.
  final String? title;
  final FlutterDefenderUiTheme theme;

  @override
  Widget build(BuildContext context) {
    final FlutterDefenderUiTheme t = theme;
    return ColoredBox(
      color: t.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.cardColor,
                    borderRadius: BorderRadius.circular(t.logoCardBorderRadius),
                    border: Border.all(color: t.cardBorderColor),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(t.cardPadding),
                    child: t.headerLogo,
                  ),
                ),
                SizedBox(height: t.spacingBelowLogoCard),
                Text(
                  title ?? FlutterDefenderMessages.blockingTitleFor(context),
                  textAlign: TextAlign.center,
                  style: t.titleStyle,
                ),
                SizedBox(height: t.spacingBelowTitle),
                Text(message, textAlign: TextAlign.center, style: t.bodyStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
