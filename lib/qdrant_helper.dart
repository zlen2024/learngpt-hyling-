import 'dart:convert';
import 'dart:ffi';
import 'package:hello_flutter/study_space_screen.dart';
import 'package:http/http.dart' as http;

class QdrantAPI {
  static const baseUrl = "https://6e381c35-1b92-41ef-92aa-0167bb8f77ec.eu-west-1-0.aws.cloud.qdrant.io";
  static const apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.zm93Bv73OtfqBXvueaxRnbp0uBhdTFytN-24L2aOKAw";

  static const headers = {
    'Content-Type': 'application/json',
    'api-key': apiKey,
  };

  // Create collection
  static Future<void> createCollection(String sessionName) async {
    final url = Uri.parse("$baseUrl/collections/$sessionName");
    final body = jsonEncode({
      "vectors": {"size": 100, "distance": "Cosine"} // example for OpenAI embeddings
    });
    final res = await http.put(url, headers: headers, body: body);
    print("Create collection: ${res.body}");
  }

  // Insert document chunk
  static Future<void> insertChunk(int id, List<double> vector, String text, String sessionName ) async {
    final url = Uri.parse("$baseUrl/collections/$sessionName/points?wait=true");
    final body = jsonEncode({
      "points": [
        {
          "id": id,
          "vector": vector,
          "payload": {"text": text}
        }
      ]
    });
    final res = await http.put(url, headers: headers, body: body);
    print("Insert result: ${res.body}");
  }

  // Search similar chunks
  static Future<List<String>> search(
  List<double> queryVector,
  String sessionName,
) async {
  final url = Uri.parse("$baseUrl/collections/$sessionName/points/search");

  final body = jsonEncode({
    "vector": queryVector,
    "limit": 5,
    "with_payload": true,
  });

  final res = await http.post(url, headers: headers, body: body);
  final data = jsonDecode(res.body);
  logger.d("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥Search response: $data");

  return (data['result'] as List?)
          ?.map((r) => r['payload']?['text'])
          .whereType<String>()
          .toList() ??
      [];
}

  // Delete collection by session name
  static Future<void> deleteCollection(String sessionName) async {
    final url = Uri.parse("$baseUrl/collections/$sessionName");
    final res = await http.delete(url, headers: headers);
    print("Delete collection ($sessionName): ${res.body}");
  }
}
