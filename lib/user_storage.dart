import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  // ✅ Save user background info and pinned note
  static Future<void> saveUser({
    required String name,
    required String sex,
    required int age,
    required String levelOfStudy,
    required String institution,
    required int pinnedNoteId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('sex', sex);
    await prefs.setInt('age', age);
    await prefs.setString('levelOfStudy', levelOfStudy);
    await prefs.setString('institution', institution);
    await prefs.setInt('pinnedNoteId', pinnedNoteId);
  }

  // ✅ Retrieve all user info
  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('name') ?? '',
      'sex': prefs.getString('sex') ?? '',
      'age': prefs.getInt('age') ?? 0,
      'levelOfStudy': prefs.getString('levelOfStudy') ?? '',
      'institution': prefs.getString('institution') ?? '',
      'pinnedNoteId': prefs.getInt('pinnedNoteId') ?? -1, // -1 = no pinned note
    };
  }

  // ✅ Update pinned note only (for logic use)
  static Future<void> updatePinnedNoteId(int pinnedNoteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pinnedNoteId', pinnedNoteId);
  }

  // ✅ Clear all saved data
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
