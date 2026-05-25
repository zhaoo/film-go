import 'dart:io';

import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/widget_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CalibrationStore.create();
  final controller = MeterController(store: store)..bootstrap();

  if (Platform.isAndroid) {
    final prefs = await SharedPreferences.getInstance();
    WidgetBridge(prefs: prefs).attach(controller);
  }

  runApp(
    ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith((ref) => controller),
      ],
      child: const FilmGoApp(),
    ),
  );
}
