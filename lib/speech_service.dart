import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;

  /// Initialize the STT engine
  Future<bool> initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    return available;
  }

  /// Start listening and convert voice to text
  Future<void> startListening(Function(String) onResult) async {
    if (!_isListening) {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          _text = result.recognizedWords;
          _confidence = result.confidence;
          onResult(_text);
        },
        listenMode: stt.ListenMode.dictation,
        localeId: 'en_US',
      );
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Check if listening
  bool get isListening => _isListening;

  /// Get last recognized text
  String get recognizedText => _text;

  /// Get speech confidence
  double get confidence => _confidence;
}
