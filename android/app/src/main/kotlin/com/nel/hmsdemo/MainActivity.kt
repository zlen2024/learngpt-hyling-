package com.nel.hmsdemo

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.huawei.hms.mlsdk.common.MLApplication
import com.huawei.hms.mlsdk.tts.*
import com.huawei.hms.mlsdk.asr.*
import com.huawei.hms.mlsdk.textembedding.MLTextEmbeddingAnalyzer
import com.huawei.hms.mlsdk.textembedding.MLTextEmbeddingAnalyzerFactory
import com.huawei.hms.mlsdk.textembedding.MLTextEmbeddingSetting

class MainActivity : FlutterActivity() {

    private val CHANNEL_TTS = "huawei_tts"
    private val CHANNEL_ASR = "huawei_asr"
    private val CHANNEL_ASR_RESULTS = "huawei_asr_results"
    private val CHANNEL_TTS_EVENTS = "huawei_tts_events"
    private val CHANNEL_TEXT_EMBEDDING = "huawei_text_embedding"
    
    private var mlTtsEngine: MLTtsEngine? = null
    private var mlAsrRecognizer: MLAsrRecognizer? = null
    private var textEmbeddingAnalyzer: MLTextEmbeddingAnalyzer? = null
    private var asrResultSink: EventChannel.EventSink? = null
    private var ttsEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize HMS API key
        Thread {
            MLApplication.getInstance().apiKey = "HMS_API_KEY"
            Log.d("HMS", "API Key initialized in background")
            MLApplication.getInstance().setUserRegion(MLApplication.REGION_DR_SINGAPORE);
        }.start()

        // Initialize ASR recognizer
        setupAsrRecognizer()
        
        // Initialize Text Embedding Analyzer
        setupTextEmbeddingAnalyzer()
    }

    private fun setupAsrRecognizer() {
        mlAsrRecognizer = MLAsrRecognizer.createAsrRecognizer(this)
        mlAsrRecognizer?.setAsrListener(object : MLAsrListener {
            override fun onStartListening() {
                Log.d("ASR", "Recorder started listening")
                runOnUiThread {
                    asrResultSink?.success(mapOf(
                        "type" to "onStartListening"
                    ))
                }
            }

            override fun onStartingOfSpeech() {
                Log.d("ASR", "User started speaking")
                runOnUiThread {
                    asrResultSink?.success(mapOf(
                        "type" to "onStartingOfSpeech"
                    ))
                }
            }

            override fun onVoiceDataReceived(data: ByteArray, energy: Float, params: Bundle?) {
                // PCM audio data received (optional)
            }

            override fun onRecognizingResults(recognizingResults: Bundle) {
                val text = recognizingResults.getString(MLAsrRecognizer.RESULTS_RECOGNIZING)
                Log.d("ASR", "Partial result: $text")
                runOnUiThread {
                    asrResultSink?.success(mapOf(
                        "type" to "onRecognizing",
                        "text" to text,
                        "isFinal" to false
                    ))
                }
            }

            override fun onResults(results: Bundle) {
                val text = results.getString(MLAsrRecognizer.RESULTS_RECOGNIZED)
                Log.d("ASR", "Final result: $text")
                runOnUiThread {
                    asrResultSink?.success(mapOf(
                        "type" to "onResults",
                        "text" to text,
                        "isFinal" to true
                    ))
                }
            }

            override fun onError(error: Int, errorMessage: String) {
                Log.e("ASR", "Error: $error - $errorMessage")
                runOnUiThread {
                    asrResultSink?.error("ASR_ERROR", errorMessage, mapOf(
                        "errorCode" to error
                    ))
                }
            }

            override fun onState(state: Int, params: Bundle?) {
                Log.d("ASR", "State changed: $state")
                runOnUiThread {
                    asrResultSink?.success(mapOf(
                        "type" to "onState",
                        "state" to state
                    ))
                }
            }
        })
    }

    private fun setupTextEmbeddingAnalyzer() {
        try {
            // Create settings as per official Huawei documentation
            // Supports LANGUAGE_EN (English) and LANGUAGE_ZH (Simplified Chinese)
            val setting = MLTextEmbeddingSetting.Factory()
                .setLanguage(MLTextEmbeddingSetting.LANGUAGE_EN)
                .create()
            
            textEmbeddingAnalyzer = MLTextEmbeddingAnalyzerFactory.getInstance()
                .getMLTextEmbeddingAnalyzer(setting)
            
            Log.d("TextEmbedding", "✅ Text Embedding Analyzer initialized with English language")
        } catch (e: Exception) {
            Log.e("TextEmbedding", "❌ Failed to initialize Text Embedding Analyzer: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ASR Results Event Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ASR_RESULTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    asrResultSink = events
                    Log.d("ASR", "Event channel listener attached")
                }
                override fun onCancel(arguments: Any?) {
                    asrResultSink = null
                    Log.d("ASR", "Event channel listener detached")
                }
            })

        // TTS Events Event Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TTS_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ttsEventSink = events
                    Log.d("TTS", "Event channel listener attached")
                }
                override fun onCancel(arguments: Any?) {
                    ttsEventSink = null
                    Log.d("TTS", "Event channel listener detached")
                }
            })

        // TTS Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TTS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text")
                        if (text != null) {
                            speakText(text)
                            result.success("Speaking: $text")
                        } else {
                            result.error("INVALID_TEXT", "Text is null", null)
                        }
                    }
                    "stop" -> {
                        mlTtsEngine?.stop()
                        result.success("Stopped")
                    }
                    "pause" -> {
                        mlTtsEngine?.pause()
                        result.success("Paused")
                    }
                    "resume" -> {
                        mlTtsEngine?.resume()
                        result.success("Resumed")
                    }
                    else -> result.notImplemented()
                }
            }

        // ASR Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_ASR)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> {
                        try {
                            val language = call.argument<String>("language") ?: MLAsrConstants.LAN_EN_US
                            
                            // Use FEATURE_WORDFLUX (cloud-based, no native library required)
                            val intent = Intent(MLAsrConstants.ACTION_HMS_ASR_SPEECH)
                                .putExtra(MLAsrConstants.LANGUAGE, language)
                                .putExtra(MLAsrConstants.FEATURE, MLAsrConstants.FEATURE_WORDFLUX)

                            mlAsrRecognizer?.startRecognizing(intent)
                            result.success("ASR started")
                        } catch (e: Exception) {
                            Log.e("ASR", "Error starting ASR: ${e.message}")
                            result.error("ASR_START_ERROR", e.message, null)
                        }
                    }
                    "stopListening" -> {
                        mlAsrRecognizer?.destroy()
                        setupAsrRecognizer()
                        result.success("ASR stopped")
                    }
                    else -> result.notImplemented()
                }
            }

        // Text Embedding Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TEXT_EMBEDDING)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "analyseSentenceVector" -> {
                        val sentence = call.argument<String>("sentence")
                        if (sentence != null) {
                            analyseSentenceVector(sentence, result)
                        } else {
                            result.error("INVALID_SENTENCE", "Sentence is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun analyseSentenceVector(sentence: String, result: MethodChannel.Result) {
        if (textEmbeddingAnalyzer == null) {
            result.error("ANALYZER_NOT_INITIALIZED", "Text Embedding Analyzer is not initialized", null)
            return
        }

        try {
            Log.d("TextEmbedding", "⏳ Analyzing sentence: $sentence")
            
            // Use the official API as per Huawei documentation
            val sentenceVectorTask = textEmbeddingAnalyzer?.analyseSentenceVector(sentence)
            
            sentenceVectorTask?.addOnSuccessListener { vector ->
                // Processing for successful recognition
                Log.d("TextEmbedding", "✅ Successfully generated vector for: $sentence")
                Log.d("TextEmbedding", "📊 Vector size: ${vector.size}")
                
                // Convert Float[] to List<Double> for Flutter compatibility
                val vectorList = vector.map { it.toDouble() }
                
                runOnUiThread {
                    result.success(mapOf(
                        "success" to true,
                        "sentence" to sentence,
                        "vector" to vectorList,
                        "vectorSize" to vector.size
                    ))
                }
            }?.addOnFailureListener { e ->
                // If the recognition fails, handle the exception
                Log.e("TextEmbedding", "❌ Failed to generate vector: ${e.message}")
                
                // Check whether text embedding is abnormal
                val errorMessage = if (e is com.huawei.hms.mlsdk.textembedding.MLTextEmbeddingException) {
                    val embeddingException = e
                    "Error code: ${embeddingException.errCode}, Message: ${embeddingException.message}"
                } else {
                    e.message ?: "Unknown error"
                }
                
                runOnUiThread {
                    result.error("EMBEDDING_ERROR", errorMessage, mapOf(
                        "sentence" to sentence
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e("TextEmbedding", "❌ Exception in analyseSentenceVector: ${e.message}")
            result.error("EMBEDDING_EXCEPTION", e.message ?: "Unknown exception", null)
        }
    }

    private fun speakText(text: String) {
        if (mlTtsEngine == null) {
            val config = MLTtsConfig()
                .setLanguage(MLTtsConstants.TTS_EN_US)
                .setPerson(MLTtsConstants.TTS_SPEAKER_FEMALE_EN)
                .setSpeed(1.0f)
                .setVolume(1.0f)
            mlTtsEngine = MLTtsEngine(config)
        }

        mlTtsEngine?.setTtsCallback(object : MLTtsCallback {
            override fun onError(taskId: String?, err: MLTtsError?) {
                Log.e("TTS", "Error: ${err?.errorMsg}")
                runOnUiThread {
                    ttsEventSink?.error("TTS_ERROR", err?.errorMsg ?: "Unknown error", mapOf(
                        "taskId" to taskId,
                        "errorId" to err?.errorId
                    ))
                }
            }

            override fun onWarn(taskId: String?, warn: MLTtsWarn?) {
                Log.w("TTS", "Warn: ${warn.toString()}")
                runOnUiThread {
                    ttsEventSink?.success(mapOf(
                        "type" to "onWarn",
                        "taskId" to taskId,
                        "message" to warn.toString()
                    ))
                }
            }

            override fun onRangeStart(taskId: String?, start: Int, end: Int) {
                runOnUiThread {
                    ttsEventSink?.success(mapOf(
                        "type" to "onRangeStart",
                        "taskId" to taskId,
                        "start" to start,
                        "end" to end
                    ))
                }
            }

            override fun onAudioAvailable(
                taskId: String?, 
                audioFragment: MLTtsAudioFragment?, 
                offset: Int, 
                range: android.util.Pair<Int, Int>?, 
                bundle: Bundle?
            ) {
                // Audio data available if needed
            }

            override fun onEvent(taskId: String?, eventId: Int, bundle: Bundle?) {
                Log.d("TTS", "Event: $eventId")
                
                val eventType = when (eventId) {
                    MLTtsConstants.EVENT_PLAY_START -> "playStart"
                    MLTtsConstants.EVENT_PLAY_STOP -> "playStop"
                    MLTtsConstants.EVENT_PLAY_RESUME -> "playResume"
                    MLTtsConstants.EVENT_PLAY_PAUSE -> "playPause"
                    MLTtsConstants.EVENT_SYNTHESIS_START -> "synthesisStart"
                    MLTtsConstants.EVENT_SYNTHESIS_END -> "synthesisEnd"
                    MLTtsConstants.EVENT_SYNTHESIS_COMPLETE -> "synthesisComplete"
                    else -> "unknown"
                }
                
                runOnUiThread {
                    ttsEventSink?.success(mapOf(
                        "type" to "onEvent",
                        "taskId" to taskId,
                        "eventId" to eventId,
                        "eventType" to eventType
                    ))
                }
            }
        })

        mlTtsEngine?.speak(text, MLTtsEngine.QUEUE_FLUSH)
    }

    override fun onDestroy() {
        mlTtsEngine?.shutdown()
        mlAsrRecognizer?.destroy()
        // FIXED: Use close() method for Text Embedding Analyzer
        //textEmbeddingAnalyzer?.close()
        super.onDestroy()
    }
}