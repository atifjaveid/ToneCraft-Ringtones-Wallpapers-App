import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/ringtone_model.dart';

class RingtoneSearchResult {
  final List<Ringtone> ringtones;
  final int total;
  RingtoneSearchResult({required this.ringtones, required this.total});
}

class ApiService {
  static const String _clientId = '3d929a0d';
  static const String _baseUrl = 'https://api.jamendo.com/v3.0/tracks/';
  static const int _pageSize = 24;

  Future<RingtoneSearchResult> searchRingtones({
    required String keyword,
    int page = 1,
    String? genre, // null = all genres
  }) async {
    final offset = (page - 1) * _pageSize;
    final query = keyword.trim();

    final Map<String, String> params = {
      'client_id': _clientId,
      'format': 'json',
      'limit': '$_pageSize',
      'offset': '$offset',
      'audioformat': 'mp32',
      'include': 'musicinfo+stats+licenses',
      'order': query.isNotEmpty ? 'relevance' : 'popularity_total',
    };

    if (query.isNotEmpty) params['namesearch'] = query;
    if (genre != null && genre.isNotEmpty) params['fuzzytags'] = genre;

    final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', params);

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw ApiException(
            'Server returned ${response.statusCode}: ${response.reasonPhrase}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final headers = decoded['headers'] as Map<String, dynamic>?;
      final status = headers?['status'] as String?;
      final errorMsg = headers?['error_message'] as String? ?? '';

      if (status != 'success' && errorMsg.isNotEmpty) {
        throw ApiException(errorMsg);
      }

      final rawList = decoded['results'] as List<dynamic>? ?? [];
      final tracks = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => Ringtone.fromJson(e))
          .toList();

      final total =
          int.tryParse(headers?['results_fullcount']?.toString() ?? '') ??
              tracks.length;

      return RingtoneSearchResult(ringtones: tracks, total: total);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}