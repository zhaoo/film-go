import 'dart:async';

import 'package:film_go/services/camera_metadata_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('film_go/camera_metadata');
  const eventChannel = EventChannel('film_go/camera_metadata/events');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('CameraMetadataChannel', () {
    test('isSupported delegates to platform method', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        calls.add(call);
        if (call.method == 'isSupported') return false;
        return null;
      });

      final ch = CameraMetadataChannel();
      final supported = await ch.isSupported();
      expect(supported, isFalse);
      expect(calls.single.method, 'isSupported');
    });

    test('isSupported returns false when platform throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'unimplemented');
      });
      final ch = CameraMetadataChannel();
      expect(await ch.isSupported(), isFalse);
    });

    test('lockAE / unlockAE call through', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        calls.add(call.method);
        return null;
      });
      final ch = CameraMetadataChannel();
      await ch.lockAE();
      await ch.unlockAE();
      expect(calls, ['lockAE', 'unlockAE']);
    });

    test('setMeteringPoint passes x/y in arguments', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        captured = call;
        return null;
      });
      final ch = CameraMetadataChannel();
      await ch.setMeteringPoint(0.4, 0.6);
      expect(captured!.method, 'setMeteringPoint');
      expect(captured!.arguments, {'x': 0.4, 'y': 0.6});
    });

    test('setMeteringPoint clamps x/y to 0..1', () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        captured = call;
        return null;
      });
      final ch = CameraMetadataChannel();
      await ch.setMeteringPoint(-0.2, 1.5);
      expect(captured!.arguments, {'x': 0.0, 'y': 1.0});
    });

    test('frames decodes event channel payloads to CameraMetadataFrame',
        () async {
      // Mock event channel as a method channel to simulate stream events.
      final controller = await _wireEventChannel(eventChannel);
      final ch = CameraMetadataChannel();
      final received = <CameraMetadataFrame>[];
      final sub = ch.frames().listen(received.add);
      controller.add(<String, Object?>{
        'sensorIso': 200,
        'exposureSec': 1 / 125,
        'aperture': 1.78,
        'aeConverged': true,
        'timestampUs': 12345,
      });
      controller.add(<String, Object?>{
        'sensorIso': 800,
        'exposureSec': 1 / 60,
        'aperture': 1.78,
        'aeConverged': false,
        'timestampUs': 67890,
      });
      // Pump microtasks
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(2));
      expect(received[0].sensorIso, 200);
      expect(received[0].exposureSec, closeTo(1 / 125, 1e-12));
      expect(received[0].aperture, closeTo(1.78, 1e-9));
      expect(received[0].aeConverged, isTrue);
      expect(received[0].timestampUs, 12345);
      expect(received[1].aeConverged, isFalse);
    });

    test('frames stream survives an error event', () async {
      final controller = await _wireEventChannel(eventChannel);
      final ch = CameraMetadataChannel();
      final received = <CameraMetadataFrame>[];
      final errors = <Object>[];
      final sub = ch.frames().listen(received.add, onError: errors.add);
      controller.addError('platform error');
      controller.add(<String, Object?>{
        'sensorIso': 100,
        'exposureSec': 1 / 60,
        'aperture': 2.0,
        'aeConverged': true,
        'timestampUs': 1,
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(received, hasLength(1));
      expect(errors, hasLength(1));
    });
  });
}

/// Wires the event channel to a Stream we can drive from tests.
/// Returns a StreamController whose events get pushed onto the channel.
Future<StreamController<dynamic>> _wireEventChannel(
  EventChannel channel,
) async {
  final controller = StreamController<dynamic>.broadcast();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    MethodChannel(channel.name),
    (MethodCall call) async {
      if (call.method == 'listen') {
        controller.stream.listen(
          (data) {
            messenger.handlePlatformMessage(
              channel.name,
              channel.codec.encodeSuccessEnvelope(data),
              (_) {},
            );
          },
          onError: (Object e, _) {
            messenger.handlePlatformMessage(
              channel.name,
              channel.codec.encodeErrorEnvelope(
                code: 'error',
                message: e.toString(),
              ),
              (_) {},
            );
          },
        );
        return null;
      }
      if (call.method == 'cancel') {
        return null;
      }
      return null;
    },
  );
  return controller;
}
