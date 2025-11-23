import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class SuspensionUtils {
  static const prefSuspendedKey = 'isSuspended';
  static const prefSuspensionNoteKey = 'suspension_note';
  static const prefSuspensionUntilKey = 'suspended_until';

  static bool isUserSuspended(UserModel user) {
    final until = user.suspendedUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  static Future<void> saveSuspensionState(UserModel user) async {
    await storeSuspensionDetails(note: user.suspensionNote, until: user.suspendedUntil);
  }

  static Future<void> storeSuspensionDetails({String? note, DateTime? until}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefSuspendedKey, true);
    if (note != null && note.isNotEmpty) {
      await prefs.setString(prefSuspensionNoteKey, note);
    } else {
      await prefs.remove(prefSuspensionNoteKey);
    }
    if (until != null) {
      await prefs.setString(prefSuspensionUntilKey, until.toIso8601String());
    } else {
      await prefs.remove(prefSuspensionUntilKey);
    }
  }

  static Future<void> clearSuspensionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefSuspendedKey, false);
    await prefs.remove(prefSuspensionNoteKey);
    await prefs.remove(prefSuspensionUntilKey);
  }

  static DateTime? parseStoredUntil(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
