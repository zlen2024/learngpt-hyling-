import 'package:flutter/material.dart';
import 'package:huawei_ml_text/huawei_ml_text.dart';
import 'package:flutter/services.dart';


/// Huawei Text Embedding Service
/// Provides text embedding functionality similar to Google's text-embedding-004
class HuaweiEmbedding {
  static MLTextEmbeddingAnalyzer? _analyzer;
  static bool _isInitialized = false;
  static const platform = MethodChannel('huawei_text_embedding');

  /// Initialize the text embedding analyzer
  /// Must be called before using getEmbedding
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _analyzer = MLTextEmbeddingAnalyzer();
      
      // Create configuration with English language
      final setting = MLTextEmbeddingAnalyzerSetting(
        language: MLTextEmbeddingAnalyzerSetting.languageEn,
      );
      
      // Create the analyzer
      await _analyzer!.createTextEmbeddingAnalyzer(setting: setting);
      _isInitialized = true;
      
      print('✅ Huawei Text Embedding initialized successfully');
    } catch (e) {
      print('❌ Error initializing Huawei Text Embedding: $e');
      throw Exception('Failed to initialize text embedding: $e');
    }
  }

  /// Get text embedding vector for the given text
  /// Returns a list of doubles representing the embedding vector
  static Future<List<double>> getEmbedding(String text) async {
    if (!_isInitialized || _analyzer == null) {
      await initialize();
    }

    try {
      // Use word vector for text (works for words and short phrases)
      final List<double> vector = await _analyzer!.analyseWordVector(
        word: text,
      );
      
      print('✅ Generated embedding with ${vector.length} dimensions');
      return vector;
    } catch (e) {
      print('❌ Error getting embedding: $e');
      return [];
    }
  }

  /// Get similarity between two texts (0.0 to 1.0)
  static Future<double> getTextSimilarity(String text1, String text2) async {
    if (!_isInitialized || _analyzer == null) {
      await initialize();
    }

    try {
      final double similarity = await _analyzer!.analyseSentencesSimilarity(
        sentence1: text1,
        sentence2: text2,
      );
      return similarity;
    } catch (e) {
      print('❌ Error calculating similarity: $e');
      return 0.0;
    }
  }

  /// Get similarity between two words (0.0 to 1.0)
  static Future<double> getWordSimilarity(String word1, String word2) async {
    if (!_isInitialized || _analyzer == null) {
      await initialize();
    }

    try {
      final double similarity = await _analyzer!.analyseWordsSimilarity(
        word1: word1,
        word2: word2,
      );
      return similarity;
    } catch (e) {
      print('❌ Error calculating word similarity: $e');
      return 0.0;
    }
  }

  /// Get similar words to the given word
  static Future<List<String>> getSimilarWords(String word, {int count = 10}) async {
    if (!_isInitialized || _analyzer == null) {
      await initialize();
    }

    try {
      final List<String> similarWords = await _analyzer!.analyseSimilarWords(
        word: word,
        number: count,
      );
      return similarWords;
    } catch (e) {
      print('❌ Error getting similar words: $e');
      return [];
    }
  }

  /// Get word vector embedding
  static Future<List<double>> getWordVector(String word) async {
    if (!_isInitialized || _analyzer == null) {
      await initialize();
    }

    try {
      final List<double> vector = await _analyzer!.analyseWordVector(
        word: word,
      );
      return vector;
    } catch (e) {
      print('❌ Error getting word vector: $e');
      return [];
    }
  }

  /// Clean up resources
  static Future<void> dispose() async {
    if (_analyzer != null) {
      // The analyzer doesn't have a stop method, just set to null
      _analyzer = null;
      _isInitialized = false;
      print('✅ Text Embedding analyzer disposed');
    }
  }
}

class HuaweiEmbedding2 {
  static const platform = MethodChannel('huawei_text_embedding');

  // Simple method to get sentence embedding
  static Future<List<double>> getVector(String sentence) async {
    try {
      final result = await platform.invokeMethod('analyseSentenceVector', {
        'sentence': sentence,
      });
      
      if (result is Map && result['vector'] != null) {
        return List<double>.from(result['vector']);
      }
      return [];
    } on PlatformException catch (e) {
      print('Error getting embedding: ${e.message}');
      return [];
    }
  }
}

/// Text Embedding Demo Page
class TextEmbeddingPage extends StatefulWidget {
  const TextEmbeddingPage({Key? key}) : super(key: key);

  @override
  State<TextEmbeddingPage> createState() => _TextEmbeddingPageState();
}

class _TextEmbeddingPageState extends State<TextEmbeddingPage> {
  final TextEditingController _textController = TextEditingController(
    text: 'AI makes learning more personalized and efficient.',
  );
  final TextEditingController _text1Controller = TextEditingController(
    text: 'The cat sits on the mat',
  );
  final TextEditingController _text2Controller = TextEditingController(
    text: 'A feline rests on a rug',
  );
  final TextEditingController _wordController = TextEditingController(
    text: 'space',
  );

  List<double> _embedding = [];
  double? _similarity;
  List<String> _similarWords = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeEmbedding();
  }

  Future<void> _initializeEmbedding() async {
    setState(() => _isLoading = true);
    try {
      await HuaweiEmbedding.initialize();
    } catch (e) {
      _showError('Initialization failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getEmbedding() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showError('Please enter some text');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final vector = await HuaweiEmbedding.getEmbedding(text);
      setState(() => _embedding = vector);
      
      if (vector.isNotEmpty) {
        _showSuccess('Generated ${vector.length}D embedding');
      }
    } catch (e) {
      _showError('Failed to get embedding: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getSimilarity() async {
    final text1 = _text1Controller.text.trim();
    final text2 = _text2Controller.text.trim();
    
    if (text1.isEmpty || text2.isEmpty) {
      _showError('Please enter both texts');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final similarity = await HuaweiEmbedding.getTextSimilarity(text1, text2);
      setState(() => _similarity = similarity);
    } catch (e) {
      _showError('Failed to calculate similarity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getSimilarWords() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      _showError('Please enter a word');
      return;
    }

    setState(() {
      _isLoading = true;
      _similarWords = [];
    });
    
    try {
      final words = await HuaweiEmbedding.getSimilarWords(word, count: 10);
      setState(() => _similarWords = words);
    } catch (e) {
      _showError('Failed to get similar words: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _text1Controller.dispose();
    _text2Controller.dispose();
    _wordController.dispose();
    HuaweiEmbedding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Embedding'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Get Embedding Section
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 Get Text Embedding',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              labelText: 'Enter text',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _getEmbedding,
                            icon: const Icon(Icons.calculate),
                            label: const Text('Get Embedding Vector'),
                          ),
                          if (_embedding.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '✅ Vector Dimensions: ${_embedding.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '🔹 First 10 values:\n${_embedding.take(10).map((e) => e.toStringAsFixed(4)).join(', ')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Text Similarity Section
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔗 Text Similarity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _text1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Text 1',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _text2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Text 2',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _getSimilarity,
                            icon: const Icon(Icons.compare_arrows),
                            label: const Text('Calculate Similarity'),
                          ),
                          if (_similarity != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✅ Similarity: ${(_similarity! * 100).toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Similar Words Section
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔤 Similar Words',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _wordController,
                            decoration: const InputDecoration(
                              labelText: 'Enter a word',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _getSimilarWords,
                            icon: const Icon(Icons.search),
                            label: const Text('Find Similar Words'),
                          ),
                          if (_similarWords.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '✅ Similar words:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _similarWords
                                        .map((word) => Chip(
                                              label: Text(word),
                                              backgroundColor: Colors.blue[100],
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}