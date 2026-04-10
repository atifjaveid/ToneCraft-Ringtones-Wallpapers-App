class Wallpaper {
  final String id;
  final String? thumbUrl;
  final String? regularUrl;
  final String? fullUrl;
  final String? rawUrl;
  final String? photographerName;
  final String? photographerProfileUrl;
  final String? color;
  final int? width;
  final int? height;
  final int likes;
  final String? downloadLocation; // must be hit to comply with Unsplash guidelines

  Wallpaper({
    required this.id,
    this.thumbUrl,
    this.regularUrl,
    this.fullUrl,
    this.rawUrl,
    this.photographerName,
    this.photographerProfileUrl,
    this.color,
    this.width,
    this.height,
    this.likes = 0,
    this.downloadLocation,
  });

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    final urls = json['urls'] as Map<String, dynamic>? ?? {};
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final links = json['links'] as Map<String, dynamic>? ?? {};

    return Wallpaper(
      id: json['id']?.toString() ?? '',
      thumbUrl: urls['thumb'] as String?,
      regularUrl: urls['regular'] as String?,
      fullUrl: urls['full'] as String?,
      rawUrl: urls['raw'] as String?,
      photographerName: user['name'] as String?,
      photographerProfileUrl:
      (user['links'] as Map<String, dynamic>?)?['html'] as String?,
      color: json['color'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      likes: (json['likes'] as int?) ?? 0,
      downloadLocation: links['download_location'] as String?,
    );
  }

  /// Dominant color as Flutter Color (fallback: grey)
  int get colorValue {
    final hex = color?.replaceFirst('#', '');
    if (hex == null || hex.length != 6) return 0xFF9E9E9E;
    return int.tryParse('FF$hex', radix: 16) ?? 0xFF9E9E9E;
  }
}