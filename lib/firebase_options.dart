import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

abstract final class DefaultFirebaseOptions {
  static bool get isConfigured {
    if (_apiKey.isEmpty || _projectId.isEmpty || _messagingSenderId.isEmpty) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId.isNotEmpty,
      TargetPlatform.iOS => _iosAppId.isNotEmpty && _iosBundleId.isNotEmpty,
      _ => false,
    };
  }

  static FirebaseOptions get currentPlatform {
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => throw UnsupportedError('Esta app solo configura Firebase para Android e iOS.'),
    };

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS ? _iosBundleId : null,
    );
  }
}