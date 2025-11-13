import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleEmbedding {
  static const String apiKey = "AIzaSyCYrvA5olGdyOvKn0XznAIq2ZXUzdTdTfE";
  static const String baseUrl ="https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent";

  static Future<List<double>> getEmbedding(String text) async {
    final uri = Uri.parse("$baseUrl?key=$apiKey");

    final body = jsonEncode({
      "model": "models/text-embedding-004",
      "content": {"parts": [{"text": text}]}
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // ✅ Safely access vector values
      final List<dynamic>? values = data["embedding"]?["values"];

      if (values == null) {
        print("No embedding values found in response: ${response.body}");
        return [];
      }

      // ✅ Convert all values to double safely
      return values.map((v) => (v as num).toDouble()).toList();
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
      return [];
    }
  }
}

void main() async {
  const text = "AI makes learning more personalized and efficient.";
  print("Fetching embedding for: $text");

  final vector = await GoogleEmbedding.getEmbedding(text);
  print("✅ Vector length: ${vector.length}");
  if (vector.isNotEmpty) {
    print("🔹 First 5 values: ${vector.take(5).toList()}");
  }
}
