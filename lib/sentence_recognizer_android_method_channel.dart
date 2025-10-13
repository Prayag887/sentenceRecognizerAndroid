import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sentence_recognizer_android_platform_interface.dart';

/// An implementation of [PhoneticSpeechRecognizerPlatform] that uses method channels.
class MethodChannelPhoneticSpeechRecognizer
    extends PhoneticSpeechRecognizerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sentence_recognizer_android');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
