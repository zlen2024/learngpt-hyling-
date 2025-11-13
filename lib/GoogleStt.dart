import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// A singleton service class for Speech-to-Text functionality
/// Usage: GoogleSpeechToText.instance.startListening(...)
class GoogleSpeechToText {
  // Singleton pattern
  static final GoogleSpeechToText _instance = GoogleSpeechToText._internal();
  factory GoogleSpeechToText() => _instance;
  static GoogleSpeechToText get instance => _instance;
  GoogleSpeechToText._internal();

  // Speech to Text instance
  late stt.SpeechToText _speech;
  bool _isInitialized = false;
  bool _isListening = false;
  List<stt.LocaleName> _availableLocales = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  List<stt.LocaleName> get availableLocales => _availableLocales;

  /// Initialize the speech recognition service
  /// Must be called before using any other methods
  /// Returns true if initialization was successful
  Future<bool> initialize({
    Function(String status)? onStatusChanged,
    Function(dynamic error)? onError,
    bool debugLogging = false,
  }) async {
    try {
      // Check and request microphone permission
      final permissionStatus = await _checkMicrophonePermission();
      if (!permissionStatus) {
        if (onError != null) {
          onError('Microphone permission denied');
        }
        return false;
      }

      // Initialize speech to text
      _speech = stt.SpeechToText();
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          _isListening = status == 'listening';
          if (onStatusChanged != null) onStatusChanged(status);
          if (debugLogging) print('STT Status: $status');
        },
        onError: (error) {
          _isListening = false;
          if (onError != null) onError(error);
          if (debugLogging) print('STT Error: $error');
        },
        debugLogging: debugLogging,
      );

      // Get available locales
      if (_isInitialized) {
        _availableLocales = await _speech.locales();
      }

      return _isInitialized;
    } catch (e) {
      if (onError != null) onError(e);
      return false;
    }
  }

  /// Check and request microphone permission
  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    return status.isGranted;
  }

  /// Request microphone permission manually
  Future<bool> requestPermission() async {
    return await _checkMicrophonePermission();
  }

  /// Open app settings for manual permission grant
  Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  /// Start listening for speech input
  /// [onResult] - Callback for speech recognition results
  /// [localeId] - Language locale (default: 'en_US')
  /// [partialResults] - Get interim results while speaking
  /// [listenFor] - Maximum listening duration
  /// [pauseFor] - Stop after this duration of silence
  /// [cancelOnError] - Cancel listening on error
  Future<bool> startListening({
    required Function(String recognizedWords, bool isFinal, double confidence) onResult,
    String localeId = 'en_US',
    bool partialResults = true,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
    bool cancelOnError = true,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
  }) async {
    if (!_isInitialized) {
      throw Exception('Speech to Text not initialized. Call initialize() first.');
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(
            result.recognizedWords,
            result.finalResult,
            result.confidence,
          );
        },
        localeId: localeId,
        partialResults: partialResults,
        listenFor: listenFor,
        pauseFor: pauseFor,
        cancelOnError: cancelOnError,
        listenMode: listenMode,
      );
      _isListening = true;
      return true;
    } catch (e) {
      _isListening = false;
      print('Error starting listening: $e');
      return false;
    }
  }

  /// Stop listening for speech input
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel the current speech recognition session
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  /// Check if speech recognition is available on this device
  Future<bool> checkAvailability() async {
    try {
      _speech = stt.SpeechToText();
      return await _speech.initialize();
    } catch (e) {
      return false;
    }
  }

  /// Get list of supported locales/languages
  /// Format: [LocaleName(localeId: 'en_US', name: 'English (United States)'), ...]
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _availableLocales;
  }

  /// Get locale by language code
  /// Example: getLocaleById('en_US') or getLocaleById('es_ES')
  stt.LocaleName? getLocaleById(String localeId) {
    try {
      return _availableLocales.firstWhere((locale) => locale.localeId == localeId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a specific locale is supported
  bool isLocaleSupported(String localeId) {
    return _availableLocales.any((locale) => locale.localeId == localeId);
  }

  /// Get the last error message (if any)
  String? getLastError() {
    return _speech.lastError?.errorMsg;
  }

  /// Check if device has speech recognition capability
  bool get hasRecognitionCapability => _speech.isAvailable;

  /// Dispose resources (call when app is closing or service is no longer needed)
  Future<void> dispose() async {
    if (_isListening) {
      await stopListening();
    }
    _isInitialized = false;
  }

  // Quick helper methods for common use cases

  /// Quick listen - Simple one-time speech recognition
  /// Returns the recognized text or null if failed
  Future<String?> quickListen({
    String localeId = 'en_US',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    String? result;
    bool completed = false;

    await startListening(
      localeId: localeId,
      listenFor: timeout,
      onResult: (words, isFinal, confidence) {
        if (isFinal) {
          result = words;
          completed = true;
        }
      },
    );

    // Wait for completion or timeout
    final startTime = DateTime.now();
    while (!completed && DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await stopListening();
    return result;
  }

  /// Continuous listening - Keep listening and return results continuously
  /// Use [stopListening()] to stop
  Future<void> continuousListening({
    required Function(String recognizedWords) onResult,
    String localeId = 'en_US',
  }) async {
    await startListening(
      localeId: localeId,
      partialResults: true,
      listenFor: const Duration(minutes: 10), // Long duration for continuous
      pauseFor: const Duration(seconds: 5), // Longer pause tolerance
      onResult: (words, isFinal, confidence) {
        if (words.isNotEmpty) {
          onResult(words);
        }
      },
    );
  }
}