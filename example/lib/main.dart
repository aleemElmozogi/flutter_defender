import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_defender/flutter_defender.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final FlutterDefender _flutterDefenderPlugin = FlutterDefender();
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    unawaited(initPlatformState());
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _flutterDefenderPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...FlutterDefenderLocalizations.localizationsDelegates,
      ],
      // In a real app, merge your own supported locales with the defender list:
      // mergeFlutterDefenderSupportedLocales(AppLocalizations.supportedLocales)
      supportedLocales: mergeFlutterDefenderSupportedLocales(const <Locale>[
        Locale('en', 'US'),
      ]),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_defender example'),
          actions: <Widget>[
            PopupMenuButton<Locale>(
              tooltip: 'Locale',
              onSelected: (Locale locale) => setState(() => _locale = locale),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
                const PopupMenuItem<Locale>(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                const PopupMenuItem<Locale>(
                  value: Locale('es'),
                  child: Text('Español'),
                ),
                const PopupMenuItem<Locale>(
                  value: Locale('fr'),
                  child: Text('Français'),
                ),
                const PopupMenuItem<Locale>(
                  value: Locale('ar'),
                  child: Text('العربية'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: Text(_locale.languageCode.toUpperCase())),
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Running on: $_platformVersion'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: BlockingScreen(
                              message: FlutterDefenderMessages.resolved(
                                context,
                                FlutterDefenderMessageId.screenshotsBlocked,
                              ),
                              theme: FlutterDefenderUiTheme.defaults.copyWith(
                                backgroundColor: const Color(0xFF1A0A0A),
                                cardColor: const Color(0xFF2D1515),
                                cardBorderColor: const Color(0xFF5C2020),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Preview blocking UI (custom colors)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
