import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'homophones.dart';

enum PhoneticTypeSentence {
  alphabet,
  koreanAlphabet,
  number,
  englishWordsOrSentence,
  japaneseAlphabet,
  koreanNumber,
  allLanguageSupport,
  paragraphsMapping
}

class SentenceRecognizerAndroid {
  final Map<String, List<String>> homophones = Homophones.homophones;
  static Timer? _sentenceTimeoutTimer;
  static String? _lastPartial;
  // Function words that should always be highlighted as correct
  static const Set<String> functionWords = {
    'a',
  };

  List<int> errorWordsIndexes = [];
  List<int> errorPronouncationList = [];
  List<int> correctPronouncationList = [];

  static const MethodChannel _channel =
      MethodChannel('sentence_recognizer_android');

  static const EventChannel _downloadProgressChannel =
      EventChannel('download_model_progress');

  ScrollController controller = ScrollController();

  static Future<String?> getPlatformVersion() async {
    try {
      final String? version = await _channel.invokeMethod('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        log("Error: ${e.message}");
      }
      return null;
    }
  }

  static Future<bool> stopRecognition({void Function()? callback}) async {
    await Future.delayed(Duration(milliseconds: 500));
    _sentenceTimeoutTimer?.cancel();
    try {
      final bool result = await _channel.invokeMethod('stopRecognition');
      if (callback != null) {
        callback.call();
      }
      return result;
    } catch (e) {
      throw PlatformException(code: 'STOP_ERROR', message: e.toString());
    }
  }

  static Future<bool> isListening() async {
    try {
      final bool result = await _channel.invokeMethod('isListening');
      return result;
    } catch (e) {
      throw PlatformException(code: 'STOP_ERROR', message: e.toString());
    }
  }

  Stream<String> listenToStream() {
    return getDataStream().map((dynamic data) {
      if (data != null && data is Map) {
        return data.keys.first.toString();
      }
      return "";
    });
  }

// The supporting function that gets the raw data stream
  Stream<dynamic> getDataStream() {
    final EventChannel _eventChannel =
        EventChannel('sentence_recognizer_android/partial_results');
    return _eventChannel.receiveBroadcastStream();
  }

  static Future<dynamic> recognize({
    required PhoneticTypeSentence type,
    String? languageCode,
    required int timeout,
    String? sentence,
    bool sendKeyOnly = true,
  }) async {
    var homoPhones = Homophones();
    if (timeout < 0) {
      throw ArgumentError('Timeout must be a positive value');
    }

    try {
      final dynamic raw = await _channel.invokeMethod('recognize', {
        'type': type.toString().split('.').last,
        'languageCode': languageCode,
        'timeout': timeout,
        'sentence': sentence,
        'sendKeyOnly': sendKeyOnly,
      });

      if (raw == null) {
        debugPrint("RESULT LIBS: null response from native side");
        return "";
      }

      debugPrint("RESULT LIBS: Raw native response: $raw");
      return raw;
    } on PlatformException catch (e) {
      debugPrint("RESULT LIBS: Platform Exception - ${e.code}: ${e.message}");
      if (kDebugMode) {
        log("Speech Recognition Error: ${e.code} - ${e.message}");
      }
      return "";
    } catch (e) {
      debugPrint("RESULT LIBS: Unexpected error: $e");
      return "";
    }
  }

  /// Checks if the recognized sentence contains mandatory words.
  ///
  /// If [andCase] is true, all words in [mandatoryWordsList] must be present
  /// in the [recognizedSentence] in order. If [andCase] is false, at least one
  /// word from [mandatoryWordsList] must be present in the [recognizedSentence].
  ///
  /// If [andCase] is false, atleast one word in [mandatoryWordsList] must be present
  bool mandatoryWords(
      {required List<String> mandatoryWordsList,
      required String recognizedSentence,
      bool andCase = true}) {
    final lowerCaseSentence = recognizedSentence.toLowerCase();
    final lowerCaseMandatoryWords =
        mandatoryWordsList.map((word) => word.toLowerCase()).toList();

    if (andCase) {
      // AND case: All words must be present in order
      int lastIndex = -1;

      for (String word in lowerCaseMandatoryWords) {
        int currentIndex = lowerCaseSentence.indexOf(word);

        if (currentIndex == -1 || currentIndex < lastIndex) {
          return false; // word not found or order is incorrect
        }

        lastIndex = currentIndex;
      }

      return true;
    } else {
      // OR case: At least one word from mandatory list must be present
      for (String word in lowerCaseMandatoryWords) {
        if (lowerCaseSentence.contains(word)) {
          return true; // Found at least one mandatory word
        }
      }

      return false; // No mandatory words found
    }
  }

  static bool _arePhoneticallySimilar(String a, String b) {
    final Map<String, String> similarMap = {
      'j': 'g',
      'g': 'j',
      't': 'd',
      'd': 't',
      'm': 'n',
      'n': 'm',
      'b': 'p',
      'p': 'b',
    };

    // Normalize to lowercase
    a = a.trim().toLowerCase();
    b = b.trim().toLowerCase();

    if (a == b) return true;
    if (a.length == 1 && b.length == 1 && similarMap[a] == b) return true;

    return false;
  }
}

class AccuracyStore {
  static final AccuracyStore _instance = AccuracyStore._internal();
  factory AccuracyStore() => _instance;
  AccuracyStore._internal();

  int accuracyPercentage = 0;
}
