import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates and persists a unique anonymous device ID.
/// Used as user_id in S3 metadata — no PII involved.
class UserIdService {
  static const String _key = 'device_user_id';
  static const Uuid _uuid = Uuid();

  static String? _cachedId;

  /// Returns the persistent device ID, generating one if it doesn't exist yet.
  static Future<String> getUserId() async {
    if (_cachedId != null) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);

    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_key, id);
    }

    _cachedId = id;
    return id;
  }
}
