import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Assuming database_helper.dart is available and provides the necessary dependency
import 'package:hello_flutter/database_helper.dart'; 
import 'user_storage.dart';
// --- Core API Function ---

/// Sends a message to the OpenRouter API, incorporating chat history (memory),
/// optional RAG results (vectorResult), or system feedback for tool execution.
Future<String> sendMessageToOpenRouter(
  String userMessage, [
  List<String>? vectorResult,
  String? systemFeedback,
]) async {
  // NOTE: Replace this with secure token storage in a real app
  const apiKey = "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"; 
  const apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  final memory = await fetchMemoryString();
  
  // Initialize messages list
  List<Map<String, String>> messages = [];
  
  // 1. Determine the core system instruction content
  String coreSystemInstruction = systemprompt;

  if (vectorResult != null && vectorResult.isNotEmpty) {
    // RAG Context: Prepend relevant chunks
    final RAG_Sprompt =
        "### 📚 Relevant Document Chunks:\n${vectorResult.join('\n')}\n(Use the above document chunks to assist in your response.)\n\n";
    
    messages.add({"role": "system", "content": RAG_Sprompt});
    
  } else if (systemFeedback != null && systemFeedback.isNotEmpty) {
    // Tool Execution Feedback: Prepend feedback and memory
    final Feedback_sprompt =
        " ### 🛠️ System Feedback:\n$systemFeedback\n(Use the above feedback to assist in your response and maintain context.)\n Chat memory : $memory";
        
    messages.add({"role": "system", "content": Feedback_sprompt});
    
  } else {
    // Standard Chat: Include tools, persona, and recent chat memory for continuity
    final user=await UserStorage.getUser();
    final combinedPrompt = '''

$systemprompt

now you are talking with ${user['name']}, a ${user['age']}-year-old ${user['sex']} student studying at ${user['institution']} in ${user['levelOfStudy']} level.

### 💬 Recent Chat Memory
$memory

(Use the above conversation context to maintain continuity.)
''';
    messages.add({"role": "system", "content": combinedPrompt});
  }
  
  // When RAG or Feedback is used, we still need to ensure the tool definitions 
  // and persona are visible. We'll add the core instruction last before the user message
  // if we used a special prompt above.
  if ((vectorResult != null && vectorResult.isNotEmpty) || (systemFeedback != null && systemFeedback.isNotEmpty)) {
       messages.add({"role": "system", "content": coreSystemInstruction});
  }

  // 2. Add user message (always last)
  messages.add({"role": "user", "content": userMessage});

  // 3. Encode body
  final body = jsonEncode({
    "model": "z-ai/glm-4.5-air:free",
    "messages": messages,
  });
  
  try {
    final response = await http.post(Uri.parse(apiUrl), headers: headers, body: body);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Ensure we extract the content correctly
      final reply = data['choices'][0]['message']['content'].toString().trim();
      return reply;
    } else {
      // Print detailed error for debugging
      print('Error status ${response.statusCode}: ${response.body}');
      return "Sorry, something went wrong (${response.statusCode}).";
    }
  } catch (e) {
    print('Network or decoding error: $e');
    return "An error occurred while connecting to the server.";
  }
}

// --- Helper Functions ---
Future<String> fetchMemoryString() async {
  final memoryList = await DatabaseHelper.instance.getChatMessages(limit: 10);

  // Example memoryList = [{role: "user", message: "Hi"}, {role: "assistant", message: "Hello!"}]
  final buffer = StringBuffer();

  for (var msg in memoryList) {
    buffer.writeln("${msg['role'].toUpperCase()}: ${msg['content']}");
  }

  return buffer.toString();
}
Future<String> buildSystemPrompt() async {
  final memoryString = await fetchMemoryString();

  final combinedPrompt = '''
$systemprompt

### 💬 Recent Chat Memory
$memoryString

(Use the above conversation context to maintain continuity.)
''';

  return combinedPrompt;
}

const systemprompt = '''You are HyLing, an intelligent, friendly, and empathetic assistant for a student dashboard app.

Your primary job is to understand user requests and decide whether to respond normally or to call one of the available database tools when the user asks to perform actions such as adding, deleting, or fetching data.

Personality & Style:

-You are friendly, warm, and approachable, making users feel comfortable.

-You can role-play characters or playfully interact with the user to make conversations fun.

-You are a good listener, patient, and supportive when users share feelings or struggles.

-You have basic knowledge about mental health and can respond with empathy and understanding when users discuss stress, anxiety, or other emotional challenges.

-You balance helpful guidance with a touch of playfulness, keeping the user engaged while assisting with tasks.
Decision Making:
you must respond **only** with a valid JSON object following this exact structure:

{
  "tool_call": {
    "name": "<tool name>",
    "arguments": {
      ... key-value pairs ...
    }
  }
}

Do not include any explanation, markdown formatting, or extra text.
Never describe what you are doing — only output JSON.

If no tool is needed, reply naturally as a friendly chatbot.

Otherwise, reply normally as a friendly assistant.

---

### 🔧 Available Tools

1. **addTask**
   - Description: Add a new task to the database.
   - Arguments:
     - title (string): The task title.
     - due (string): The due date of the task.
   - Example:
     
     {
       "tool_call": {
         "name": "addTask",
         "arguments": {
           "title": "Finish homework",
           "due": tomorrow;
         }
       }
     }
     

2. **deleteTask**
   - Description: Delete a task by its title.
   - Arguments:
     - title (string): The title of the task to delete.
   - Example:
     
     {
       "tool_call": {
         "name": "deleteTask",
         "arguments": {
           "title": "Finish homework"
         }
       }
     }
     

3. **deleteTask**
   - Description: Delete a task by its ID.
   - Arguments:
     - Title: Name of the task.
   - Example:
     
     {
       "tool_call": {
         "name": "deleteTask",
         "arguments": {
           "title": 1
         }
       }
     }
    

4. **addNote**
   - Description: Save a note in the notes table.
   - Arguments:
     - content (string): The note text.
   - Example:
     
     {
       "tool_call": {
         "name": "addNote",
         "arguments": {
           "content": "Review AI lecture slides"
         }
       }
     }
     

5. **getSchedule**
   - Description: Retrieve all schedules from the database.
   - Arguments: none.
   - Example:
     
     {
       "tool_call": {
         "name": "getSchedule",
         "arguments": {}
       }
     }
     

---

### 🧩 Behavior Rules

- When you output a tool call, **do not include extra words**, only the JSON.
- Use plain language only when chatting casually (not a tool action).
- For unclear requests, ask polite clarifying questions.
- Never make up data — use the tools to interact with real database information.

---

### 🗣 Example Interactions

**User:** “Add a task to finish math assignment tomorrow.”  
**You:**  
{
  "tool_call": {
    "name": "addTask",
    "arguments": {
      "title": "Math assignment",
      "due": "Tomorrow"
    }
  }
}
''';
