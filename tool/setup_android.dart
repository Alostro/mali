// Configures the generated Android project for Mali.
// Run once after `flutter create --platforms=android .`:
//   dart tool/setup_android.dart
// Safe to run more than once.
import 'dart:io';

void main() {
  _patchManifest();
  _patchGradle();
  stdout.writeln('Android project configured for Mali.');
}

void _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln('Missing ${file.path}. Run: flutter create --platforms=android .');
    exit(1);
  }
  var xml = file.readAsStringSync();

  xml = xml.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Mali"');

  const permissions = <String>[
    'android.permission.POST_NOTIFICATIONS" />',
    'android.permission.RECEIVE_BOOT_COMPLETED" />',
  ];
  for (final perm in permissions) {
    final name = perm.substring(0, perm.indexOf('"'));
    if (!xml.contains('"$name"')) {
      xml = xml.replaceFirst(
          '<application', '<uses-permission android:name="$perm\n    <application');
    }
  }

  const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
  if (!xml.contains('ScheduledNotificationReceiver')) {
    xml = xml.replaceFirst('</application>', '$receivers    </application>');
  }

  file.writeAsStringSync(xml);
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final isKts = kts.existsSync();
  final file = isKts ? kts : groovy;
  if (!file.existsSync()) {
    stderr.writeln('Could not find android/app/build.gradle(.kts)');
    exit(1);
  }
  var gradle = file.readAsStringSync();
  if (gradle.contains('desugar_jdk_libs')) return;

  // Required by flutter_local_notifications.
  final enable = isKts
      ? 'isCoreLibraryDesugaringEnabled = true'
      : 'coreLibraryDesugaringEnabled true';
  if (gradle.contains('compileOptions {')) {
    gradle = gradle.replaceFirst('compileOptions {', 'compileOptions {\n        $enable');
  } else {
    gradle = gradle.replaceFirst(
        'android {', 'android {\n    compileOptions {\n        $enable\n    }');
  }

  final dep = isKts
      ? 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
      : "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'";
  gradle = '$gradle\ndependencies {\n    $dep\n}\n';

  file.writeAsStringSync(gradle);
}
