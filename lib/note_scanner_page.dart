import 'package:flutter/material.dart';
import 'package:huawei_ml_text/huawei_ml_text.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hello_flutter/database_helper.dart';

/// Smart Note Scanner - Single Page Feature
/// Scan text from images and save as study notes
class NoteScannerPage extends StatefulWidget {
  const NoteScannerPage({Key? key}) : super(key: key);

  @override
  State<NoteScannerPage> createState() => _NoteScannerPageState();
}

class _NoteScannerPageState extends State<NoteScannerPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  late MLTextAnalyzer _textAnalyzer;
  late MLDocumentAnalyzer _documentAnalyzer;
  
  File? _selectedImage;
  String? _extractedText;
  bool _isProcessing = false;
  RecognitionMode _mode = RecognitionMode.quick;
  
  final List<ScannedNote> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _initializeAnalyzers();
  }

  void _initializeAnalyzers() {
    _textAnalyzer = MLTextAnalyzer();
    _documentAnalyzer = MLDocumentAnalyzer();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedText = null;
          _contentController.clear();
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  Future<void> _scanImage() async {
    if (_selectedImage == null) {
      _showSnackBar('Please select an image first', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String? result;
      
      if (_mode == RecognitionMode.quick) {
        // Quick Text Recognition (On-Device)
        result = await _quickTextRecognition(_selectedImage!.path);
      } else {
        // Document Recognition (Cloud)
        result = await _documentRecognition(_selectedImage!.path);
      }
      
      setState(() {
        _extractedText = result;
        _contentController.text = result ?? '';
        _isProcessing = false;
      });
      
      if (result == null || result.isEmpty) {
        _showSnackBar('⚠️ No text found. Try better lighting or different mode.', Colors.orange);
      } else {
        _showSnackBar('✅ Text extracted successfully!', Colors.green);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<String?> _quickTextRecognition(String imagePath) async {
    final setting = MLTextAnalyzerSetting.remote(path: imagePath);
    
    try {
      final MLText text = await _textAnalyzer.asyncAnalyseFrame(setting);
      return text.stringValue;
    } catch (e) {
      throw Exception('Text recognition failed: $e');
    }
  }

  Future<String?> _documentRecognition(String imagePath) async {
    final setting = MLDocumentAnalyzerSetting.create(path: imagePath);
    
    try {
      final MLDocument document = await _documentAnalyzer.asyncAnalyzeFrame(setting);
      return document.stringValue;
    } catch (e) {
      throw Exception('Document recognition failed: $e');
    }
  }

  void _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    
    if (title.isEmpty) {
      _showSnackBar('Please enter a title', Colors.orange);
      return;
    }
    
    if (content.isEmpty) {
      _showSnackBar('No content to save', Colors.orange);
      return;
    }
    
    final masa = DateTime.now();
    final konten = 'CreatedOn :$masa Using:$_mode ----- $content';
      
    await DatabaseHelper.instance.addNote(konten, title);
    
    _showSnackBar('✅ Note saved!', Colors.green);
  }

  void _clearAll() {
    setState(() {
      _selectedImage = null;
      _extractedText = null;
      _titleController.clear();
      _contentController.clear();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Smart Note Scanner',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2), // Material Blue 700
        foregroundColor: Colors.white,
        actions: [
          if (_selectedImage != null || _extractedText != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Section
            Container(
              height: 240,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.greenAccent,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Image Loaded',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[50]!,
                              Colors.blue[100]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No image selected',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select an image to get started',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Image Source Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF1976D2),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1976D2),
                        const Color(0xFF1565C0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF42A5F5),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF42A5F5),
                        const Color(0xFF2196F3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recognition Mode Selection
            Container(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.settings_suggest_rounded,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Recognition Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildModeOption(
                      title: 'Quick Scan',
                      subtitle: 'On-device • 2-3 seconds',
                      icon: Icons.flash_on_rounded,
                      value: RecognitionMode.quick,
                      isSelected: _mode == RecognitionMode.quick,
                    ),
                    const SizedBox(height: 8),
                    _buildModeOption(
                      title: 'Document Scan',
                      subtitle: 'Cloud-based • 5-10 seconds',
                      icon: Icons.description_rounded,
                      value: RecognitionMode.document,
                      isSelected: _mode == RecognitionMode.document,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Scan Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isProcessing
                      ? [Colors.grey[400]!, Colors.grey[500]!]
                      : [const Color(0xFF1976D2), const Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_isProcessing ? Colors.grey : Colors.blue)
                        .withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _scanImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.document_scanner_rounded,
                        size: 24,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _isProcessing ? 'Scanning...' : 'Start Scan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Extracted Text Section
            if (_extractedText != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Extracted Text',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Note Title',
                        hintText: 'Enter a title for your note',
                        prefixIcon: Icon(Icons.title_rounded, color: Colors.blue[700]),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: 'Content',
                        hintText: 'Edit the extracted text',
                        prefixIcon: Icon(Icons.edit_rounded, color: Colors.blue[700]),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4CAF50),
                                  Color(0xFF45A049),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _saveNote,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text(
                                'Save Note',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: IconButton(
                            onPressed: _clearAll,
                            icon: Icon(Icons.close_rounded, color: Colors.grey[700]),
                            tooltip: 'Clear',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            // Recent Scans
            if (_recentScans.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Scans',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_recentScans.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentScans.length,
                itemBuilder: (context, index) {
                  final note = _recentScans[index];
                  final timeAgo = _getTimeAgo(note.createdAt);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[400]!,
                              Colors.blue[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        note.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: note.mode == RecognitionMode.quick
                                    ? Colors.orange[50]
                                    : Colors.purple[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                note.mode == RecognitionMode.quick
                                    ? 'Quick'
                                    : 'Document',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: note.mode == RecognitionMode.quick
                                      ? Colors.orange[700]
                                      : Colors.purple[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey[400],
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              note.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            content: SingleChildScrollView(
                              child: Text(
                                note.content,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Close',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required RecognitionMode value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected ? Colors.blue[900] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<RecognitionMode>(
              value: value,
              groupValue: _mode,
              onChanged: (value) => setState(() => _mode = value!),
              activeColor: Colors.blue[700],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _textAnalyzer.destroy();
    super.dispose();
  }
}

// Models
enum RecognitionMode {
  quick,
  document,
}

class ScannedNote {
  final String id;
  final String title;
  final String content;
  final String? imagePath;
  final DateTime createdAt;
  final RecognitionMode mode;

  ScannedNote({
    required this.title,
    required this.content,
    this.imagePath,
    required this.createdAt,
    required this.mode,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();
}