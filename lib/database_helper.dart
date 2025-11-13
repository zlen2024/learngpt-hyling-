import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('student_dashboard.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        due TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time TIME NOT NULL,
        title TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // --- NEW Study Sessions Table ---
    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        file_name TEXT NOT NULL,
        chunk_count INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // --- NEW Document Chunks Table ---
    /*await db.execute('''
      CREATE TABLE document_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        content TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES study_sessions (id) ON DELETE CASCADE
      )
    ''');*/
  }

  // --- Handle Database Upgrade ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_memory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
    
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS study_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          file_name TEXT NOT NULL,
          chunk_count INTEGER NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      /*await db.execute('''
        CREATE TABLE IF NOT EXISTS document_chunks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          chunk_index INTEGER NOT NULL,
          content TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES study_sessions (id) ON DELETE CASCADE
        )
      ''');*/
    }
  }

  // ============================================================
  // 📚 STUDY SESSIONS
  // ============================================================

  Future<int> addStudySession(String name, String fileName, int chunkCount) async {
    final db = await instance.database;
    return await db.insert('study_sessions', {
      'name': name,
      'file_name': fileName,
      'chunk_count': chunkCount,
    });
  }

  Future<List<Map<String, dynamic>>> getAllStudySessions() async {
    final db = await instance.database;
    return await db.query('study_sessions', orderBy: 'created_at DESC');
  }

  Future<int> deleteStudySession(int sessionId) async {
    final db = await instance.database;
    // This will also delete associated chunks due to CASCADE
    return await db.delete('study_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ============================================================
  // 📄 DOCUMENT CHUNKS
  // ============================================================

 /* Future<int> addDocumentChunk(int sessionId, int chunkIndex, String content) async {
    final db = await instance.database;
    return await db.insert('document_chunks', {
      'session_id': sessionId,
      'chunk_index': chunkIndex,
      'content': content,
    });
  }

  Future<List<Map<String, dynamic>>> getDocumentChunks(int sessionId) async {
    final db = await instance.database;
    return await db.query(
      'document_chunks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'chunk_index ASC',
    );
  }*/

  // ============================================================
  // 🧠 CHAT MEMORY FUNCTIONS
  // ============================================================

  Future<int> insertChatMessage(String role, String content) async {
    final db = await instance.database;
    return await db.insert('chat_memory', {
      'role': role,
      'content': content,
    });
  }

  Future<List<Map<String, dynamic>>> getChatMessages({int limit = 30}) async {
    final db = await instance.database;
    return await db.query(
      'chat_memory',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<int> clearChatMemory() async {
    final db = await instance.database;
    return await db.delete('chat_memory');
  }

  Future<int> deleteChatMessageById(int id) async {
    final db = await instance.database;
    return await db.delete('chat_memory', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  // 📋 TASKS
  // ============================================================
  Future<int> addTask(String title, DateTime? due) async {
    final db = await instance.database;
    return await db.insert('tasks', {'title': title, 'due': due?.toIso8601String()});
  }

  Future<int> deleteTaskByID(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTask(String title) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'title = ?', whereArgs: [title]);
  }

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await instance.database;
    final rows = await db.query('tasks', orderBy: 'id ASC');
    return rows;
  }
  Future<List<Map<String, dynamic>>> getTasks(String name) async {
    final db = await instance.database;
    final rows = await db.query('tasks', where: 'title = ?', whereArgs: [name]);
    return rows;
  }

  // ============================================================
  // 📝 NOTES
  // ============================================================
  Future<int> addNote(String content,String title) async {
    final db = await instance.database;
    return await db.insert('notes', {'content': content, 'title': title});
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await instance.database;
    final rows = await db.query('notes', orderBy: 'id ASC');
    return rows;
  }

  // ============================================================
  // ⏰ SCHEDULE
  // ============================================================
  Future<int> addSchedule(String time, String title) async {
    final db = await instance.database;
    return await db.insert('schedule', {'time': time, 'title': title});
  }

  Future<List<Map<String, dynamic>>> getSchedule() async {
    final db = await instance.database;
    final rows = await db.query('schedule', orderBy: 'time ASC');
    return rows;
  }
}