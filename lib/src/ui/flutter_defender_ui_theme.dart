import 'package:flutter/material.dart';

/// Visual styling for the default [BlockingScreen]. Host apps can pass a
/// customized instance through [FlutterDefenderConfig.uiTheme].
@immutable
class FlutterDefenderUiTheme {
  const FlutterDefenderUiTheme({
    this.backgroundColor = const Color(0xFF07111F),
    this.cardColor = const Color(0xFF10233C),
    this.cardBorderColor = const Color(0xFF1E3A5F),
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
    this.bodyStyle = const TextStyle(
      color: Color(0xFFD0D8E3),
      fontSize: 16,
      height: 1.5,
    ),
    this.horizontalPadding = 24,
    this.cardPadding = 20,
    this.logoCardBorderRadius = 8,
    this.spacingBelowLogoCard = 24,
    this.spacingBelowTitle = 12,
    this.headerLogo = const FlutterLogo(size: 72),
  });

  static const FlutterDefenderUiTheme defaults = FlutterDefenderUiTheme();

  final Color backgroundColor;
  final Color cardColor;
  final Color cardBorderColor;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final double horizontalPadding;
  final double cardPadding;
  final double logoCardBorderRadius;
  final double spacingBelowLogoCard;
  final double spacingBelowTitle;
  final Widget headerLogo;

  FlutterDefenderUiTheme copyWith({
    Color? backgroundColor,
    Color? cardColor,
    Color? cardBorderColor,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
    double? horizontalPadding,
    double? cardPadding,
    double? logoCardBorderRadius,
    double? spacingBelowLogoCard,
    double? spacingBelowTitle,
    Widget? headerLogo,
  }) {
    return FlutterDefenderUiTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardColor: cardColor ?? this.cardColor,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      titleStyle: titleStyle ?? this.titleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      logoCardBorderRadius: logoCardBorderRadius ?? this.logoCardBorderRadius,
      spacingBelowLogoCard: spacingBelowLogoCard ?? this.spacingBelowLogoCard,
      spacingBelowTitle: spacingBelowTitle ?? this.spacingBelowTitle,
      headerLogo: headerLogo ?? this.headerLogo,
    );
  }
}
