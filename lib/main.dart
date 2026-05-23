import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CalibrationStore.create();
  runApp(
    ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith(
          (ref) => MeterController(store: store)..bootstrap(),
        ),
      ],
      child: const FilmGoApp(),
    ),
  );
}
