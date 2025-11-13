import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hello_flutter/api_service.dart';
import 'package:hello_flutter/huawei_embedding.dart';
import 'package:hello_flutter/main.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'database_helper.dart';
import 'qdrant_helper.dart';
import 'google_embedding.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

final logger = Logger();

class StudySpaceScreen extends StatefulWidget {
  const StudySpaceScreen({super.key});

  @override
  State<StudySpaceScreen> createState() => _StudySpaceScreenState();
}

class _StudySpaceScreenState extends State<StudySpaceScreen> {
  // State management
  int currentState = 0; // 0: Session List, 1: Upload, 2: Chat
  
  // Session data
  List<StudySession> sessions = [];
  StudySession? activeSession;
  
  // Upload state
  File? selectedFile;
  final TextEditingController sessionNameController = TextEditingController();
  
  // Chat state
  final TextEditingController messageController = TextEditingController();
  final ScrollController chatScrollController = ScrollController();
  List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    sessionNameController.dispose();
    messageController.dispose();
    chatScrollController.dispose();
    super.dispose();
  }

  // Load sessions from database
  Future<void> _loadSessions() async {
    final sessionData = await DatabaseHelper.instance.getAllStudySessions();
    setState(() {
      sessions = sessionData.map((data) => StudySession.fromMap(data)).toList();
    });
  }

  // Pick a file
  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  // Process document and create session
  Future<void> processDocument() async {
    if (selectedFile == null || sessionNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a file and enter session name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      currentState = 2;
      messages = [
        ChatMessage(
          text: 'Processing document, please wait...',
          isUser: false,
        ),
      ];
    });

    final path = selectedFile!.path;
    String text = '';

    if (path.endsWith('.pdf')) {
      try {
        final bytes = await selectedFile!.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final textExtractor = PdfTextExtractor(document);
        text = textExtractor.extractText();
        document.dispose();
      } catch (e) {
        text = 'Error reading PDF: $e';
        setState(() {
          messages.removeLast();
          messages = [
            ChatMessage(
              text: text,
              isUser: false,
            ),
          ];
        });
      }
    } else if (path.endsWith('.txt')) {
      text = await selectedFile!.readAsString();
    }

    // Split text into chunks
    const chunkSize = 400;
    const chunkOverlap = 100;
    final chunks = <String>[];

    for (var i = 0; i < text.length; i += chunkSize - chunkOverlap) {
      chunks.add(text.substring(
        i,
        i + chunkSize > text.length ? text.length : i + chunkSize,
      ));
      setState(() {
        messages.removeLast();
        messages.add(ChatMessage(
          text: "Generated ${chunks.length} chunks...",
          isUser: false,
        ));
      });
    }

    // Save to database
    final sessionId = await DatabaseHelper.instance.addStudySession(
      sessionNameController.text,
      selectedFile!.path.split('/').last,
      chunks.length,
    );
    await QdrantAPI.createCollection(sessionNameController.text);
    setState(() {
      messages.removeLast();
      messages.add(ChatMessage(
        text: "Vector database collection created...",
        isUser: false,
      ));
    });

    // Save chunks to Qdrant
    for (int i = 0; i < chunks.length; i++) {
      try {
        String text = chunks[i].trim();
        
        if (text.isEmpty) continue;
        
        if (text.length > 1500) {
          text = text.substring(0, 1500);
        }
        
        final text2 = text.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
        
        final vector = await HuaweiEmbedding2.getVector(text2);
        logger.d('Chunk $i: $text chars -> ${vector.length}D vector');
        
        if (vector.isNotEmpty) {
          await QdrantAPI.insertChunk(i + 1, vector, text, sessionNameController.text);
          setState(() {
            messages.removeLast();
            messages.add(ChatMessage(
              text: "✅ Inserted chunk ${i + 1}/${chunks.length}",
              isUser: false,
            ));
          });
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        logger.e("Chunk $i failed: $e");
      }
    }

    // Create new session
    final newSession = StudySession(
      id: sessionId,
      name: sessionNameController.text,
      fileName: selectedFile!.path.split('/').last,
      chunkCount: chunks.length,
      createdAt: DateTime.now(),
    );

    final vector = await HuaweiEmbedding2.getVector("What is this document about?");
    setState(() {
      messages.removeLast();
      messages.add(ChatMessage(
        text: "Reading Reference...",
        isUser: false,
      ));
    });

    setState(() {
      sessions.add(newSession);
      activeSession = newSession;
      selectedFile = null;
      sessionNameController.clear();
    });
    
    List<String>? vectorResulttemp;
    if (vector.isNotEmpty && activeSession != null) {
      vectorResulttemp = await QdrantAPI.search(vector, activeSession!.name);
      logger.d("Vector search results: $vectorResulttemp");
    }
    
    final response = await sendMessageToOpenRouter("What is this document about?", vectorResulttemp);
    setState(() {
      messages.removeLast();
      messages.add(ChatMessage(
        text: "What is this document about?\n\n$response",
        isUser: false,
      ));
    });
  }

  // Delete session
  Future<void> _deleteSession(StudySession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Session?'),
        content: Text('Are you sure you want to delete "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteStudySession(session.id!);
      await QdrantAPI.deleteCollection(session.name);
      await _loadSessions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Send message
  void sendMessage() async {
    if (messageController.text.trim().isEmpty) return;

    final userMessage = messageController.text.trim();
    List<String>? vectorResult;

    final vector = await HuaweiEmbedding2.getVector(userMessage);

    setState(() {
      messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
      ));
      messageController.clear();
    });

    setState(() {
      messages.add(ChatMessage(
        text: "Reading references...",
        isUser: false,
      ));
    });

    if (vector.isNotEmpty && activeSession != null) {
      vectorResult = await QdrantAPI.search(vector, activeSession!.name);
      logger.d("Vector search results: $vectorResult");
    }
    
    setState(() {
      messages.removeLast();
      messages.add(ChatMessage(
        text: "Generating response...",
        isUser: false,
      ));
    });

    final response = await sendMessageToOpenRouter(userMessage, vectorResult);

    Future.delayed(const Duration(milliseconds: 100), () {
      chatScrollController.animateTo(
        chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        messages.removeLast();
        messages.add(ChatMessage(
          text: response,
          isUser: false,
        ));
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        chatScrollController.animateTo(
          chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          currentState == 0
              ? "Study Sessions"
              : currentState == 1
                  ? "New Session"
                  : activeSession?.name ?? "Chat",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        leading: currentState != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    if (currentState == 2) {
                      currentState = 0;
                    } else {
                      currentState = 0;
                      selectedFile = null;
                      sessionNameController.clear();
                    }
                  });
                },
              )
            : null,
      ),
      body: currentState == 0
          ? _buildSessionList()
          : currentState == 1
              ? _buildUploadMode()
              : _buildChatMode(),
    );
  }

  // State 1: Session List
  Widget _buildSessionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sessions.length + 1,
      itemBuilder: (context, index) {
        if (index == sessions.length) {
          // Add new session button
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    currentState = 1;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_circle_rounded, size: 32, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Create New Session",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final session = sessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: Colors.blue[700],
                size: 28,
              ),
            ),
            title: Text(
              session.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.description_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.fileName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${session.chunkCount} chunks',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red[700], size: 20),
                onPressed: () => _deleteSession(session),
              ),
            ),
            onTap: () async {
              setState(() {
                activeSession = session;
                messages = [
                  ChatMessage(
                    text: 'Hello! How can I help you with "${session.name}" today?',
                    isUser: false,
                  ),
                ];
                currentState = 2;
              });
            },
          ),
        );
      },
    );
  }

  // State 2: Upload Mode
  Widget _buildUploadMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Icon container
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              size: 100,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 40),
          
          // Session name input
          Text(
            'Session Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: sessionNameController,
            decoration: InputDecoration(
              hintText: 'Enter a name for this study session',
              prefixIcon: Icon(Icons.label_rounded, color: Colors.blue[700]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // File picker button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedFile != null ? Colors.green : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedFile != null ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        selectedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                        color: selectedFile != null ? Colors.green[700] : Colors.grey[600],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedFile == null ? "Choose File" : selectedFile!.path.split('/').last,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: selectedFile != null ? Colors.green[900] : Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedFile == null ? "PDF or TXT file" : "File selected",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          // Start button
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (selectedFile != null && sessionNameController.text.isNotEmpty)
                    ? [const Color(0xFF1976D2), const Color(0xFF1565C0)]
                    : [Colors.grey[300]!, Colors.grey[400]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: (selectedFile != null && sessionNameController.text.isNotEmpty)
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: (selectedFile != null && sessionNameController.text.isNotEmpty)
                  ? processDocument
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.auto_stories_rounded, size: 24),
                  SizedBox(width: 12),
                  Text(
                    "Start Studying",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // State 3: Chat Mode
  Widget _buildChatMode() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFF5F7FA),
            child: ListView.builder(
              controller: chatScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: message.isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                            )
                          : null,
                      color: message.isUser ? null : Colors.white,
                      borderRadius: message.isUser
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(4),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(20),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: message.isUser
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: message.isUser
                        ? Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          )
                        : MarkdownBody(
                            data: message.text,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF2C3E50),
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about the document...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: sendMessage,
                  iconSize: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Data models
class StudySession {
  final int? id;
  final String name;
  final String fileName;
  final int chunkCount;
  final DateTime createdAt;

  StudySession({
    this.id,
    required this.name,
    required this.fileName,
    required this.chunkCount,
    required this.createdAt,
  });

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int,
      name: map['name'] as String,
      fileName: map['file_name'] as String,
      chunkCount: map['chunk_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'file_name': fileName,
      'chunk_count': chunkCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}