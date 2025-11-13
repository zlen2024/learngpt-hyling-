import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:huawei_ml_language/huawei_ml_language.dart';
import 'huawei_tts.dart'; // your custom Huawei TTS service
import 'api_service.dart'; // your AI logic file with sendMessageToOpenRouter() & handleAIResponse()
import 'database_helper.dart';
import 'dart:convert';

class EchoBot extends StatefulWidget {
  const EchoBot({super.key});

  @override
  State<EchoBot> createState() => _EchoBotState();
}

class _EchoBotState extends State<EchoBot> {
  late MLAsrRecognizer _asr;
  bool _isListening = false;
  bool _isProcessing = false; // Covers AI processing and TTS speaking
  String _recognizedText = 'Tap the mic and start speaking...';
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initASR();
  }

  // Helper to safely initialize ASR
  void _initASR() {
    // Destroy previous instance if it exists before creating a new one
    try {
      _asr.destroy();
    } catch (_) {
      // Ignore error if _asr wasn't initialized yet or already destroyed
    }
    
    _asr = MLAsrRecognizer();
    _asr.setAsrListener(
      MLAsrListener(
        onRecognizingResults: (partial) {
          if (_isListening) {
            setState(() {
              _recognizedText = partial;
            });
          }
        },
        onResults: (finalText) async {
          // ASR is stopped automatically upon final result or on error.
          setState(() {
            _recognizedText = finalText;
            _isListening = false; // Transition from listening state
          });
          await _processAI(finalText);
        },
        onError: (error, msg) {
          debugPrint("ASR Error: $error: $msg");
          setState(() {
            _recognizedText = 'Error: $msg';
            _isListening = false;
            _isProcessing = false;
          });
          _initASR();
        },
        onState: (state) {
          debugPrint("ASR State: $state");
        },
      ),
    );
  }

  Future<void> _initPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _recognizedText = 'Microphone permission required.';
      });
    }
  }

  // Refactored to handle all click-related states
  Future<void> _startListening() async {
    // 1. If currently processing (AI/TTS), STOP TTS and reset to idle.
    if (_isProcessing) {
      await HuaweiTTS.stop();
      setState(() {
        _isProcessing = false;
        _recognizedText = 'Tap the mic and start speaking...';
        _aiResponse = '';
      });
      _initASR(); 
      return;
    }

    // 2. If currently listening, STOP ASR and reset to idle.
    if (_isListening) {
      try {
         _asr.destroy();
      } catch (e) {
        debugPrint("Error destroying ASR on manual stop: $e");
      }
      setState(() {
        _isListening = false;
        _recognizedText = 'Tap the mic and start speaking...';
      });
      _initASR(); 
      return;
    }

    // 3. Start Listening (Idle -> Listening)
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await _initPermissions();
      return;
    }

    final MLAsrSetting setting = MLAsrSetting(
      language: MLAsrConstants.LAN_EN_US,
      feature: MLAsrConstants.FEATURE_WORDFLUX,
    );

    try {
      _initASR(); 
      setState(() {
        _isListening = true;
        _recognizedText = "Listening...";
        _aiResponse = ''; 
      });
      
      // 🟢 THE FIX: Removed 'await' since startRecognizing returns void.
      _asr.startRecognizing(setting);
      
    } catch (e) {
      debugPrint("ASR Start Error: $e");
      setState(() {
        _isListening = false;
        _recognizedText = 'Failed to start listening.';
      });
      _initASR();
    }
  }

  // Handles AI call, DB updates, and TTS
  Future<void> _processAI(String text) async {
    setState(() {
      _isProcessing = true; // Start of AI processing
      _aiResponse = "Thinking...";
    });

    await DatabaseHelper.instance.insertChatMessage('user', text);

    try {
      final reply = await sendMessageToOpenRouter(text);
      final handledReply = await _handleAIResponse(reply,text); 
      
      await DatabaseHelper.instance.insertChatMessage('assistant', handledReply);

      setState(() {
        _aiResponse = handledReply;
      });

      await HuaweiTTS.speak(handledReply);
    } catch (e) {
      debugPrint("AI/TTS Error: $e");
      setState(() {
        _aiResponse = "AI processing failed. Check logs.";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _initASR();
    }
  }

  // Local helper function for tool call parsing (from previous response)
  Future<String> _handleAIResponse(String reply,String userMassage) async {
  try {
    final parsed = jsonDecode(reply);
    //final parsed = parsed1['choices'][0]['message'];
    //print('parsed: $parsed');
    final dbHelper = DatabaseHelper.instance;

    if (parsed["tool_call"] != null) {
      final tool = parsed["tool_call"]["name"];
      final args = parsed["tool_call"]["arguments"];

      switch (tool) {
        case "addTask":
          await dbHelper.addTask(args["title"],await parseDueString(args["due"]));
           final systemFeedback ="🤖 Added task: ${args["title"]}";
           final response = await sendMessageToOpenRouter(userMassage,null,systemFeedback);
           return response;

        case "deleteTask":
          await dbHelper.deleteTask(args["title"]);
          final systemFeedback ="🤖 Deleted task: ${args["title"]}";
           final response = await sendMessageToOpenRouter(userMassage,null,systemFeedback);
           return response;
          

        case "addNote":
          await dbHelper.addNote(args["content"],"Quick Note");
          final systemFeedback ="🗒️ Note added: ${args["content"]}";
           final response = await sendMessageToOpenRouter(userMassage,null,systemFeedback);
           return response;
         

        case "getSchedule":
          final schedule = await dbHelper.getSchedule();
          final systemFeedback ="📅 Upcoming schedule:\n$schedule";
           final response = await sendMessageToOpenRouter(userMassage,null,systemFeedback);
           return response;
         

        default:
        final systemFeedback ="🤖 Unknown tool: $tool";
           final response = await sendMessageToOpenRouter(userMassage,null,systemFeedback);
           return response;
         
      }
    } else {
      // Normal response (no tool call)
      //final message = parsed1['choices'][0]['message']['content'];
      return " $reply";
    }

    

  } catch (_) {
    // If reply isn’t valid JSON, return as text
    return " $reply";
  }
  
  }

Future<DateTime?> parseDueString(String due) async {

  due = due.toLowerCase().trim();

  final now = DateTime.now();



  DateTime? result;





  try {

    // Handle relative dates

    if (due.contains("tomorrow")) {

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (timeMatch != null) {

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day + 1, hour, minute);

      }

    } else if (due.contains("today")) {

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (timeMatch != null) {

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day, hour, minute);

      }

    }

    // Handle "in X days"

    else if (due.contains("in") && due.contains("days")) {

      final daysMatch = RegExp(r'in\s+(\d+)\s+days').firstMatch(due);

      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);



      if (daysMatch != null && timeMatch != null) {

        final addDays = int.parse(daysMatch.group(1)!);

        int hour = int.parse(timeMatch.group(1)!);

        int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

        final meridian = timeMatch.group(3);



        if (meridian == 'pm' && hour < 12) hour += 12;

        if (meridian == 'am' && hour == 12) hour = 0;



        result = DateTime(now.year, now.month, now.day + addDays, hour, minute);

      }

    }

    // Handle specific dates (e.g. "12 December 2 pm")

    else {

      final dateMatch = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{1,2})(?::(\d{2}))?\s?(am|pm)').firstMatch(due);

      if (dateMatch != null) {

        int day = int.parse(dateMatch.group(1)!);

        String monthName = dateMatch.group(2)!;

        int hour = int.parse(dateMatch.group(3)!);

        int minute = int.tryParse(dateMatch.group(4) ?? '0') ?? 0;

        String meridian = dateMatch.group(5)!;



        final months = {

          'january': 1, 'february': 2, 'march': 3, 'april': 4,

          'may': 5, 'june': 6, 'july': 7, 'august': 8,

          'september': 9, 'october': 10, 'november': 11, 'december': 12

        };



        int? month = months[monthName];

        if (month != null) {

          if (meridian == 'pm' && hour < 12) hour += 12;

          if (meridian == 'am' && hour == 12) hour = 0;



          result = DateTime(now.year, month, day, hour, minute);

          if (result.isBefore(now)) {

            // If the date already passed this year, assume next year

            result = DateTime(now.year + 1, month, day, hour, minute);

          }

        }

      }

    }



    if (result != null && result.isBefore(now)) {

      // Always ensure it's a future date

      result = result.add(const Duration(days: 1));

    }



    return result;

  } catch (e) {

    print("Error parsing due string: $e");

    return now.add(const Duration(days: 1)); // default fallback

  }

} 

  @override
  void dispose() {
    _asr.destroy();
    HuaweiTTS.stop(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI remains identical to the smooth version in the previous response, 
    // relying on _isListening and _isProcessing for state.
    // ... (rest of the build method)
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        title: const Text(
          'Voice Assistant',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E21),
              const Color(0xFF1A1F3A),
              const Color(0xFF0D47A1).withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated microphone icon background
                GestureDetector(
                  onTap: () {
                    _startListening();
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isListening || _isProcessing
                            ? [
                                const Color(0xFF1E88E5).withOpacity(0.3),
                                const Color(0xFF42A5F5).withOpacity(0.1),
                              ]
                            : [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                      ),
                      boxShadow: _isListening || _isProcessing
                          ? [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withOpacity(0.5),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ]
                          : [],
                    ),
                    child: Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: _isProcessing 
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF42A5F5),
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                size: 60,
                                color: _isListening
                                    ? const Color(0xFF42A5F5)
                                    : Colors.white70,
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Status text
                Text(
                  _isListening
                      ? 'Listening...'
                      : _isProcessing
                          ? 'Processing & Speaking...'
                          : 'Tap mic to speak',
                  style: TextStyle(
                    color: _isListening || _isProcessing
                        ? const Color(0xFF42A5F5)
                        : Colors.white60,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 50),

                // Recognized text container
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Text(
                        _recognizedText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // AI Response container
                if (_aiResponse.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF42A5F5).withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          _aiResponse,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

                // Indicator dots
                if (_isListening)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF42A5F5).withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}