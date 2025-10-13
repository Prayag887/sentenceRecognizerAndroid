import 'dart:async';
import 'dart:developer';

import 'package:sentence_recognizer_android/sentence_recognizer_android.dart';
import 'package:sentence_recognizer_android_example/randomsetencegenerator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum RecognitionType {
  alphabets,
  numbers,
  koreanAlphabets,
  sentences,
  koreanNumber,
  japaneseAlphabet,
  allLanguageSupport,
  koreanNumbers,
  paragraphMapping
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ValueNotifiers for state management
  final ValueNotifier<String> _recognizedTextNotifier =
      ValueNotifier<String>("Press the button to start");
  final ValueNotifier<bool> _isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _confidenceNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<RecognitionType> _selectedTypeNotifier =
      ValueNotifier<RecognitionType>(RecognitionType.sentences);
  final ValueNotifier<String> _randomTextNotifier =
      ValueNotifier<String>("Apple");
  final ValueNotifier<String> _randomNumberNotifier = ValueNotifier<String>(
      RandomSentenceGenerator.generateSerialKoreanNumber());
  final ValueNotifier<String> _partialTextNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> _newTextNotifier = ValueNotifier<String>("");
  final ValueNotifier<bool> _isTextReceivedNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isRealTimeNotifier = ValueNotifier<bool>(false);

  final int _timeoutDuration = 12000000;
  Timer? _timer;
  Ticker? _ticker;
  String _latestPartialText = '';

  SentenceRecognizerAndroid recognizer = SentenceRecognizerAndroid();
  StreamSubscription? subscription;

  @override
  void dispose() {
    _timer?.cancel();
    subscription?.cancel();
    _ticker?.dispose();

    // Dispose all ValueNotifiers
    _recognizedTextNotifier.dispose();
    _isListeningNotifier.dispose();
    _progressNotifier.dispose();
    _confidenceNotifier.dispose();
    _selectedTypeNotifier.dispose();
    _randomTextNotifier.dispose();
    _randomNumberNotifier.dispose();
    _partialTextNotifier.dispose();
    _newTextNotifier.dispose();
    _isTextReceivedNotifier.dispose();
    _isRealTimeNotifier.dispose();

    super.dispose();
  }

  Future<void> _requestAudioPermission() async {
    _startRecognition();
  }

  void stopRecognition() {
    SentenceRecognizerAndroid.stopRecognition();
    _timer?.cancel();
    subscription?.cancel();
    _ticker?.dispose();

    _isListeningNotifier.value = false;
    _progressNotifier.value = 1.0;
    _partialTextNotifier.value = "";
  }

  void _listenForPartialResults() {
    subscription?.cancel();
    _ticker?.dispose();

    // Step 1: Capture stream data into a buffer
    subscription = recognizer.listenToStream().listen((data) {
      _latestPartialText = data;
    }, onError: (error) {
      if (kDebugMode) {
        log("Stream error: $error");
      }
    });

    // Step 2: Poll buffer at 30 FPS
    _ticker = Ticker((_) {
      if (_partialTextNotifier.value != _latestPartialText) {
        _partialTextNotifier.value = _latestPartialText;
      }
    });

    _ticker!.start();
  }

  Future<void> _startRecognition() async {
    if (_isListeningNotifier.value) return;

    _isTextReceivedNotifier.value = false;
    _isListeningNotifier.value = true;
    _progressNotifier.value = 1.0;
    _partialTextNotifier.value = "";
    // reset confidence at the start of new recognition
    _confidenceNotifier.value = 0.0;
    _recognizedTextNotifier.value = "";

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _progressNotifier.value -= (100 / _timeoutDuration);
      if (_progressNotifier.value <= 0) {
        timer.cancel();
        if (_isListeningNotifier.value) stopRecognition();
      }
    });

    PhoneticTypeSentence phoneticType;
    String languageCode;
    String textToRecognize =
        _selectedTypeNotifier.value == RecognitionType.koreanNumbers
            ? _randomNumberNotifier.value
            : _randomTextNotifier.value;

    switch (_selectedTypeNotifier.value) {
      case RecognitionType.alphabets:
        phoneticType = PhoneticTypeSentence.alphabet;
        languageCode = "en-US";
        break;
      case RecognitionType.paragraphMapping:
        phoneticType = PhoneticTypeSentence.paragraphsMapping;
        languageCode = "en-GB";
        _listenForPartialResults();
        break;
      case RecognitionType.numbers:
        phoneticType = PhoneticTypeSentence.number;
        languageCode = "ne-NP";
        break;
      case RecognitionType.koreanNumber:
        phoneticType = PhoneticTypeSentence.koreanNumber;
        languageCode = "ko-KR";
        break;
      case RecognitionType.japaneseAlphabet:
        phoneticType = PhoneticTypeSentence.japaneseAlphabet;
        languageCode = "ja-JP";
        break;
      case RecognitionType.koreanNumbers:
        String numericPart = _randomNumberNotifier.value.substring(
            _randomNumberNotifier.value.indexOf('(') + 1,
            _randomNumberNotifier.value.indexOf(')'));
        int number = int.tryParse(numericPart) ?? 0;
        final koreanNumbers = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 21, 100};
        phoneticType = koreanNumbers.contains(number)
            ? PhoneticTypeSentence.koreanNumber
            : PhoneticTypeSentence.allLanguageSupport;
        languageCode = "ko-KR";
        break;
      case RecognitionType.koreanAlphabets:
        phoneticType = PhoneticTypeSentence.koreanAlphabet;
        languageCode = "en-US";
        break;
      case RecognitionType.allLanguageSupport:
        phoneticType = PhoneticTypeSentence.allLanguageSupport;
        languageCode = "ja-JP";
        break;
      case RecognitionType.sentences:
      default:
        phoneticType = PhoneticTypeSentence.englishWordsOrSentence;
        languageCode = "en-US";
        break;
    }

    bool sendKeyOnly =
        _selectedTypeNotifier.value == RecognitionType.alphabets ||
            _selectedTypeNotifier.value == RecognitionType.numbers ||
            _selectedTypeNotifier.value == RecognitionType.paragraphMapping;

    try {
      final result = await SentenceRecognizerAndroid.recognize(
        languageCode: languageCode,
        type: phoneticType,
        timeout: _timeoutDuration,
        sentence: textToRecognize,
        sendKeyOnly: sendKeyOnly,
      );

      print("result:::::: $result");

      if (result.isNotEmpty) {
        final confidenceStr = result['overallSimilarity'] ?? 0.0;
        final recognizedValue = result['correctedPhrase']?.toString() ?? '';

        _recognizedTextNotifier.value = recognizedValue;
        _confidenceNotifier.value = confidenceStr;

        print("recognizedValue:::::: ${_recognizedTextNotifier.value}");
        print("_randomTextNotifier:::::: ${_randomTextNotifier.value.length}");
        // Compare recognized text with expected text (text from question like sentence or paragraph)(_randomText)
        if (_recognizedTextNotifier.value == _randomTextNotifier.value) {
          _generateRandomText();
        } else {
          _recognizedTextNotifier.value = "Recognition failed";
          _confidenceNotifier.value = 0.0;
        }
      } else {
        // When sendKeyOnly is true, result is just string
        _recognizedTextNotifier.value =
            result?.toString() ?? "Recognition failed";
        if (result != null && result.toString().isNotEmpty) {
          _confidenceNotifier.value = 1.0;
        } else {
          _confidenceNotifier.value = 0.0;
        }

        if (_selectedTypeNotifier.value == RecognitionType.koreanNumbers) {
          String insideBrackets = _randomNumberNotifier.value.substring(
              _randomNumberNotifier.value.indexOf('(') + 1,
              _randomNumberNotifier.value.indexOf(')'));
          if (insideBrackets.contains(_recognizedTextNotifier.value)) {
            _generateRandomText();
          }
        } else {
          if (_recognizedTextNotifier.value == _randomTextNotifier.value) {
            _generateRandomText();
          }
        }
      }
      _isTextReceivedNotifier.value = _recognizedTextNotifier.value.isNotEmpty;

      if (!_isRealTimeNotifier.value) stopRecognition();
    } catch (error) {
      _recognizedTextNotifier.value = "Error: $error";
      _isTextReceivedNotifier.value = false;
      _confidenceNotifier.value = 0.0;
      stopRecognition();
    }
  }

  void _generateRandomText() {
    switch (_selectedTypeNotifier.value) {
      case RecognitionType.alphabets:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = String.fromCharCode(
            65 + (DateTime.now().millisecondsSinceEpoch % 26));
        break;
      case RecognitionType.numbers:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value =
            (DateTime.now().millisecondsSinceEpoch % 10).toString();
        break;
      case RecognitionType.koreanAlphabets:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = String.fromCharCode(
            0xAC00 + (DateTime.now().millisecondsSinceEpoch % 11172));
        break;
      case RecognitionType.japaneseAlphabet:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = String.fromCharCode(
            0x3040 + (DateTime.now().millisecondsSinceEpoch % 96));
        break;
      case RecognitionType.koreanNumber:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = String.fromCharCode(
            0x30A0 + (DateTime.now().millisecondsSinceEpoch % 96));
        break;
      case RecognitionType.allLanguageSupport:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = String.fromCharCode(
            0x3040 + (DateTime.now().millisecondsSinceEpoch % 96));
        break;
      case RecognitionType.koreanNumbers:
        _isRealTimeNotifier.value = false;
        _randomNumberNotifier.value =
            RandomSentenceGenerator.generateSerialKoreanNumber();
        break;
      case RecognitionType.paragraphMapping:
        _recognizedTextNotifier.value = "";
        _isRealTimeNotifier.value = true;
        // _randomTextNotifier.value = "I visited Bandipur, a small hill town. The streets were clean with old houses and stone paths. I walked around and saw beautiful views of the mountains. People were friendly and smiling. I ate local food and watched the sunset from the hill. Bandipur was peaceful and quiet.";
        _randomTextNotifier.value =
            "I went to Rara Lake in Mugu. It took a long time to reach, but it was worth it. The blue water of the lake was very clear and beautiful. The mountains around the lake made it look like a painting. I sat near the lake and felt very calm and happy.";
        break;
      default:
        _isRealTimeNotifier.value = false;
        _randomTextNotifier.value = RandomSentenceGenerator.generateSentence();
        break;
    }
  }

  int getWordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Speech Recognizer'),
          actions: [
            PopupMenuButton<RecognitionType>(
              onSelected: (RecognitionType type) {
                _selectedTypeNotifier.value = type;
                _generateRandomText();
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<RecognitionType>>[
                const PopupMenuItem(
                    value: RecognitionType.alphabets, child: Text('Alphabets')),
                const PopupMenuItem(
                    value: RecognitionType.numbers, child: Text('Numbers')),
                const PopupMenuItem(
                    value: RecognitionType.koreanAlphabets,
                    child: Text('Korean Alphabets')),
                const PopupMenuItem(
                    value: RecognitionType.sentences, child: Text('Sentences')),
                const PopupMenuItem(
                    value: RecognitionType.japaneseAlphabet,
                    child: Text('Japanese (Alphabets)')),
                const PopupMenuItem(
                    value: RecognitionType.koreanNumbers,
                    child: Text('Korean (Numbers)')),
                const PopupMenuItem(
                    value: RecognitionType.allLanguageSupport,
                    child: Text('Japanese (Numbers)')),
                const PopupMenuItem(
                    value: RecognitionType.paragraphMapping,
                    child: Text('Paragraphs')),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 🔹 Text to be recognized
                ValueListenableBuilder<String>(
                  valueListenable: _selectedTypeNotifier.value ==
                          RecognitionType.koreanNumbers
                      ? _randomNumberNotifier
                      : _randomTextNotifier,
                  builder: (context, text, _) {
                    return Text(
                      "Target: $text",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // 🔹 Partial / real-time transcription
                ValueListenableBuilder<String>(
                  valueListenable: _partialTextNotifier,
                  builder: (context, partial, _) {
                    if (partial.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        const Text(
                          "Partial:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          partial,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 🔹 Final recognized text
                ValueListenableBuilder<String>(
                  valueListenable: _recognizedTextNotifier,
                  builder: (context, recognized, _) {
                    return Column(
                      children: [
                        const Text(
                          "Recognized:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          recognized,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: recognized == "Recognition failed"
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),

                // 🔹 Confidence display
                ValueListenableBuilder<double>(
                  valueListenable: _confidenceNotifier,
                  builder: (context, confidence, _) {
                    return Text(
                      "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // 🔹 Listening / status label
                ValueListenableBuilder<bool>(
                  valueListenable: _isTextReceivedNotifier,
                  builder: (context, isTextReceived, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isListeningNotifier,
                      builder: (context, isListening, child) {
                        return isTextReceived
                            ? const SizedBox.shrink()
                            : Text(
                                isListening ? "Listening..." : "",
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 🔹 Mic Button
                ValueListenableBuilder<bool>(
                  valueListenable: _isListeningNotifier,
                  builder: (context, isListening, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isTextReceivedNotifier,
                      builder: (context, isTextReceived, child) {
                        return GestureDetector(
                          onTapDown: (_) => _requestAudioPermission(),
                          onLongPressEnd: (_) {
                            if (_isRealTimeNotifier.value) {
                              log("error words list: ${recognizer.errorWordsIndexes}");
                              stopRecognition();
                            } else {
                              isTextReceived
                                  ? stopRecognition()
                                  : log("Still analyzing");
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isListening ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic,
                                color: Colors.white, size: 36),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 🔹 Progress bar
                ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  builder: (context, progress, child) {
                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.blue,
                      minHeight: 6,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
