import 'dart:io' show Platform;

/// The operating system's version string, for example `Version 15.1 (Build 24B83)`.
String? operatingSystemVersion() => Platform.operatingSystemVersion;

/// For example `android`, `ios` or `macos`.
String operatingSystem() => Platform.operatingSystem;
