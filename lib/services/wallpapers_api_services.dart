import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/wallpaper_model.dart';

class WallpaperSearchResult {
  final List<Wallpaper> wallpapers;
  final int total;
  WallpaperSearchResult({required this.wallpapers, required this.total});
}

class WallpaperApiService {
  static const String _accessKey =
      'y67fT5Do-dpd-M3W6pxDRkWc3MQTv6CUSosSw-DXwV0';
  static const String _baseUrl = 'https://api.unsplash.com';

  /// Exactly 20 per category, for both individual tabs and the "All" merge
  static const int _perCategory = 20;

  /// All the categories that exist in the app.
  /// "All" tab fetches 20 from EACH of these and merges them (no duplicates).
  static const List<String> allCategoryTags = [
    'nature',
    'architecture',
    'abstract',
    'space',
    'city',
    'mountains',
    'ocean',
    'dark aesthetic',
    'minimalist',
    'cars',
    'animals',
  ];

  Map<String, String> get _headers => {
    'Authorization': 'Client-ID $_accessKey',
    'Accept-Version': 'v1',
  };

  // ── "All" tab: fetch 20 from every category in parallel, then merge ──────

  Future<WallpaperSearchResult> fetchAllCategories() async {
    // Fire all category requests concurrently
    final futures = allCategoryTags.map((tag) => _fetch20(tag));
    final results = await Future.wait(futures, eagerError: false);

    // Merge, de-duplicate by id, preserve order (category by category)
    final seen = <String>{};
    final merged = <Wallpaper>[];
    for (final list in results) {
      for (final w in list) {
        if (seen.add(w.id)) merged.add(w);
      }
    }

    return WallpaperSearchResult(
      wallpapers: merged,
      total: merged.length, // fixed total — no load-more on "All"
    );
  }

  // ── Individual category: exactly 20 photos, no pagination ────────────────

  Future<WallpaperSearchResult> searchPhotos({required String query}) async {
    final list = await _fetch20(query);
    return WallpaperSearchResult(wallpapers: list, total: list.length);
  }

  // ── Internal: fetch exactly 20 photos for one keyword ────────────────────

  Future<List<Wallpaper>> _fetch20(String query) async {
    final uri =
    Uri.parse('$_baseUrl/search/photos').replace(queryParameters: {
      'query': query,
      'page': '1',
      'per_page': '$_perCategory',
      'orientation': 'portrait',
    });

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      _checkStatus(response);

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ((decoded['results'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Wallpaper.fromJson)
          .toList();
    } catch (_) {
      // If one category fails, return empty so others still show
      return [];
    }
  }

  // ── Download bytes (for save / set wallpaper) ─────────────────────────────

  Future<List<int>> downloadImageBytes(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw WallpaperApiException('Download failed (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Trigger Unsplash download event (required by API guidelines)
  Future<void> triggerDownload(String downloadLocation) async {
    try {
      await http
          .get(Uri.parse(downloadLocation), headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw WallpaperApiException('Invalid Unsplash API key.');
    }
    if (response.statusCode == 403) {
      throw WallpaperApiException('Unsplash rate limit exceeded.');
    }
    if (response.statusCode != 200) {
      throw WallpaperApiException(
          'Unsplash error ${response.statusCode}: ${response.reasonPhrase}');
    }
  }
}

class WallpaperApiException implements Exception {
  final String message;
  WallpaperApiException(this.message);

  @override
  String toString() => 'WallpaperApiException: $message';
}