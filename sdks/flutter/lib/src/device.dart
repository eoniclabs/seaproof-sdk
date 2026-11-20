import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// A short device description such as `Google Pixel 8`, `iPhone 16 Pro` or `MacBookPro18,3`.
///
/// Only the model is read: no device names, serial numbers or advertising ids.
Future<String?> platformDeviceModel() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final web = await plugin.webBrowserInfo;
      // appVersion is a legacy field ("5.0 (...)" in every browser), so only the name and OS.
      final os = web.platform;
      return [web.browserName.name, if (os != null && os.isNotEmpty) os].join(' on ');
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => await plugin.androidInfo.then((a) => '${a.manufacturer} ${a.model}'),
      TargetPlatform.iOS => await plugin.iosInfo.then(
        (i) => i.modelName.isEmpty || i.modelName == 'Unknown device' ? i.utsname.machine : i.modelName,
      ),
      TargetPlatform.macOS => await plugin.macOsInfo.then((m) => m.model),
      TargetPlatform.windows => await plugin.windowsInfo.then((w) => w.productName),
      TargetPlatform.linux => await plugin.linuxInfo.then((l) => l.prettyName),
      TargetPlatform.fuchsia => null,
    };
  } on Object {
    return null;
  }
}
