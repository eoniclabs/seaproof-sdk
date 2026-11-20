import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seaproof/src/device.dart';

void main() {
  testWidgets(
    'iOS reports a model name and falls back to the hardware identifier',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
      final messenger = tester.binding.defaultBinaryMessenger;
      var modelName = 'iPhone 16 Pro';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getDeviceInfo');
        return {
          'name': 'Personal phone name',
          'systemName': 'iOS',
          'systemVersion': '27.2.1',
          'model': 'iPhone',
          'modelName': modelName,
          'localizedModel': 'iPhone',
          'freeDiskSize': 0,
          'totalDiskSize': 0,
          'isPhysicalDevice': true,
          'physicalRamSize': 0,
          'availableRamSize': 0,
          'isiOSAppOnMac': false,
          'isiOSAppOnVision': false,
          'utsname': {
            'sysname': 'Darwin',
            'nodename': 'iPhone',
            'release': '27.2.1',
            'version': 'Darwin Kernel Version',
            'machine': 'iPhone17,1',
          },
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      expect(await platformDeviceModel(), 'iPhone 16 Pro');
      modelName = 'Unknown device';
      expect(await platformDeviceModel(), 'iPhone17,1');
    },
  );
}
