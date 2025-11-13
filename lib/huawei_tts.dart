import 'package:flutter/services.dart';
import 'dart:async';

class HuaweiTTS {
  // Method Channels
  static const MethodChannel _ttsChannel = MethodChannel('huawei_tts');
  static const MethodChannel _asrChannel = MethodChannel('huawei_asr');
  
  // Event Channels
  static const EventChannel _asrResultsChannel = EventChannel('huawei_asr_results');
  static const EventChannel _ttsEventsChannel = EventChannel('huawei_tts_events');

  // Streams
  static Stream<AsrResult>? _asrResultsStream;
  static Stream<TtsEvent>? _ttsEventsStream;

  /// Get ASR results stream
  static Stream<AsrResult> get asrResultsStream {
    _asrResultsStream ??= _asrResultsChannel
        .receiveBroadcastStream()
        .handleError((error) {
          print('ASR Stream Error: $error');
        })
        .map((event) {
          try {
            final data = Map<String, dynamic>.from(event);
            return AsrResult.fromMap(data);
          } catch (e) {
            print('Error parsing ASR result: $e');
            rethrow;
          }
        });
    return _asrResultsStream!;
  }

  /// Get TTS events stream
  static Stream<TtsEvent> get ttsEventsStream {
    _ttsEventsStream ??= _ttsEventsChannel
        .receiveBroadcastStream()
        .handleError((error) {
          print('TTS Stream Error: $error');
        })
        .map((event) {
          try {
            final data = Map<String, dynamic>.from(event);
            return TtsEvent.fromMap(data);
          } catch (e) {
            print('Error parsing TTS event: $e');
            rethrow;
          }
        });
    return _ttsEventsStream!;
  }

  // ========== TTS Methods ==========

  /// TTS: Speak text
  static Future<void> speak(String text) async {
    try {
      await _ttsChannel.invokeMethod('speak', {'text': text});
    } on PlatformException catch (e) {
      print('Error speaking text: ${e.message}');
    }
  }

  /// TTS: Stop speaking
  static Future<void> stop() async {
    try {
      await _ttsChannel.invokeMethod('stop');
    } on PlatformException catch (e) {
      print('Error stopping TTS: ${e.message}');
    }
  }

  /// TTS: Pause speaking
  static Future<void> pause() async {
    try {
      await _ttsChannel.invokeMethod('pause');
    } on PlatformException catch (e) {
      print('Error pausing TTS: ${e.message}');
    }
  }

  /// TTS: Resume speaking
  static Future<void> resume() async {
    try {
      await _ttsChannel.invokeMethod('resume');
    } on PlatformException catch (e) {
      print('Error resuming TTS: ${e.message}');
    }
  }

  // ========== ASR Methods ==========
  
  /// ASR: Start listening
  static Future<void> startListening({String? language}) async {
    try {
      await _asrChannel.invokeMethod('startListening', {
        if (language != null) 'language': language,
      });
    } on PlatformException catch (e) {
      print('Error starting ASR: ${e.message}');
    }
  }

  /// ASR: Stop listening
  static Future<void> stopListening() async {
    try {
      await _asrChannel.invokeMethod('stopListening');
    } on PlatformException catch (e) {
      print('Error stopping ASR: ${e.message}');
    }
  }
}

// ========== ASR Result Model ==========

class AsrResult {
  final AsrResultType type;
  final String? text;
  final bool? isFinal;
  final int? state;

  AsrResult({
    required this.type,
    this.text,
    this.isFinal,
    this.state,
  });

  factory AsrResult.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = AsrResultType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => AsrResultType.unknown,
    );

    return AsrResult(
      type: type,
      text: map['text'] as String?,
      isFinal: map['isFinal'] as bool?,
      state: map['state'] as int?,
    );
  }

  @override
  String toString() {
    return 'AsrResult(type: $type, text: $text, isFinal: $isFinal, state: $state)';
  }
}

enum AsrResultType {
  onStartListening,
  onStartingOfSpeech,
  onRecognizing,
  onResults,
  onState,
  unknown,
}

// ========== TTS Event Model ==========

class TtsEvent {
  final TtsEventType type;
  final String? taskId;
  final String? message;
  final int? start;
  final int? end;
  final int? eventId;
  final String? eventType;

  TtsEvent({
    required this.type,
    this.taskId,
    this.message,
    this.start,
    this.end,
    this.eventId,
    this.eventType,
  });

  factory TtsEvent.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = TtsEventType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => TtsEventType.unknown,
    );

    return TtsEvent(
      type: type,
      taskId: map['taskId'] as String?,
      message: map['message'] as String?,
      start: map['start'] as int?,
      end: map['end'] as int?,
      eventId: map['eventId'] as int?,
      eventType: map['eventType'] as String?,
    );
  }

  @override
  String toString() {
    return 'TtsEvent(type: $type, taskId: $taskId, eventType: $eventType)';
  }
}

enum TtsEventType {
  onWarn,
  onRangeStart,
  onEvent,
  unknown,
}