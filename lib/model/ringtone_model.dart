import 'dart:convert';

class Ringtone {
  final String id;
  final String? title;
  final String? artist;
  final String? genre;
  final String? imageUrl;
  final String? previewUrl;
  final String? downloadUrl;
  final int? durationSeconds;
  final List<int> waveformPeaks;

  Ringtone({
    required this.id,
    this.title,
    this.artist,
    this.genre,
    this.imageUrl,
    this.previewUrl,
    this.downloadUrl,
    this.durationSeconds,
    this.waveformPeaks = const [],
  });

  factory Ringtone.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    String? genre;
    final musicinfo = json['musicinfo'] as Map<String, dynamic>?;
    final tags = musicinfo?['tags'] as Map<String, dynamic>?;
    final genres = tags?['genres'] as List<dynamic>?;
    if (genres != null && genres.isNotEmpty) {
      genre = genres.first.toString();
    }

    List<int> peaks = [];
    final waveformRaw = json['waveform'];
    if (waveformRaw != null) {
      try {
        Map<String, dynamic> waveMap;
        if (waveformRaw is String) {
          waveMap = jsonDecode(waveformRaw) as Map<String, dynamic>;
        } else {
          waveMap = waveformRaw as Map<String, dynamic>;
        }
        final rawPeaks = waveMap['peaks'] as List<dynamic>?;
        if (rawPeaks != null) {
          peaks = rawPeaks.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    final audioUrl = (json['audio'] as String?)?.trim();
    final dlUrl = (json['audiodownload'] as String?)?.trim();

    return Ringtone(
      id: id,
      title: (json['name'] as String?)?.trim(),
      artist: (json['artist_name'] as String?)?.trim(),
      genre: genre,
      imageUrl: (json['album_image'] as String?)?.trim(),
      previewUrl: (audioUrl != null && audioUrl.isNotEmpty) ? audioUrl : null,
      downloadUrl: (dlUrl != null && dlUrl.isNotEmpty) ? dlUrl : null,
      durationSeconds: int.tryParse(json['duration']?.toString() ?? ''),
      waveformPeaks: peaks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': title,
    'artist_name': artist,
    'genre': genre,
    'album_image': imageUrl,
    'audio': previewUrl,
    'audiodownload': downloadUrl,
    'duration': durationSeconds,
  };

  String get formattedDuration {
    final secs = durationSeconds;
    if (secs == null) return '--:--';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get hasPreview => previewUrl != null && previewUrl!.isNotEmpty;

  String? get bestDownloadUrl =>
      (downloadUrl != null && downloadUrl!.isNotEmpty)
          ? downloadUrl
          : previewUrl;
}