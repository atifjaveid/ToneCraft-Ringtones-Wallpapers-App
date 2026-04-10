import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/ringtone_model.dart';

/// Manages favourite ringtones using SharedPreferences for local persistence.
class FavouritesService {
  static final FavouritesService _instance = FavouritesService._internal();
  factory FavouritesService() => _instance;
  FavouritesService._internal();

  static const String _favKey = 'favourite_ringtones';

  /// Load all favourites from local storage.
  Future<List<Ringtone>> getFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favKey) ?? [];
    return jsonList
        .map((jsonStr) {
      try {
        return Ringtone.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<Ringtone>()
        .toList();
  }

  /// Add a ringtone to favourites. No-op if already present.
  Future<void> addFavourite(Ringtone ringtone) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favKey) ?? [];

    // Avoid duplicates
    final alreadyExists = jsonList.any((jsonStr) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map['id'] == ringtone.id;
      } catch (_) {
        return false;
      }
    });

    if (!alreadyExists) {
      jsonList.add(jsonEncode(ringtone.toJson()));
      await prefs.setStringList(_favKey, jsonList);
    }
  }

  /// Remove a ringtone from favourites by its ID.
  Future<void> removeFavourite(String ringtoneId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favKey) ?? [];
    jsonList.removeWhere((jsonStr) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map['id'] == ringtoneId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_favKey, jsonList);
  }

  /// Toggle favourite status. Returns true if now a favourite.
  Future<bool> toggleFavourite(Ringtone ringtone) async {
    if (await isFavourite(ringtone.id)) {
      await removeFavourite(ringtone.id);
      return false;
    } else {
      await addFavourite(ringtone);
      return true;
    }
  }

  /// Check if a ringtone is in favourites.
  Future<bool> isFavourite(String ringtoneId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favKey) ?? [];
    return jsonList.any((jsonStr) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map['id'] == ringtoneId;
      } catch (_) {
        return false;
      }
    });
  }

  /// Clear all favourites.
  Future<void> clearFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favKey);
  }
}