import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles downloading ringtone files and setting them as the system ringtone.
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  // MethodChannel must match the one registered in MainActivity.kt
  static const MethodChannel _channel =
  MethodChannel('com.ringle.app/set_ringtone');

  /// Request necessary storage permissions.
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await _isAndroid13OrAbove()) {
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        final statuses = await [Permission.storage].request();
        return statuses[Permission.storage]?.isGranted ?? false;
      }
    }
    // iOS / other platforms: no storage permission needed for this flow.
    return true;
  }

  Future<bool> _isAndroid13OrAbove() async {
    try {
      final sdkInt = await _channel.invokeMethod<int>('getSdkInt') ?? 0;
      return sdkInt >= 33;
    } catch (_) {
      return false;
    }
  }

  /// Download a ringtone from [url] and save it to external storage.
  /// Calls [onProgress] with values 0.0–1.0 as data arrives.
  Future<File> downloadRingtone({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw DownloadException('Storage permission denied.');
    }

    // Sanitise filename to be safe on all filesystems.
    final safeFileName = fileName
        .replaceAll(RegExp(r'[^\w\s\-.]'), '_')
        .replaceAll(' ', '_');
    final fileNameWithExt =
    safeFileName.endsWith('.mp3') ? safeFileName : '$safeFileName.mp3';

    // Save to app's external files directory (no extra permissions on Android 10+).
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw DownloadException('External storage unavailable.');

    final ringtonesDir = Directory('${dir.path}/Ringtones');
    if (!await ringtonesDir.exists()) {
      await ringtonesDir.create(recursive: true);
    }

    final filePath = '${ringtonesDir.path}/$fileNameWithExt';
    final file = File(filePath);

    // Streaming download with progress tracking.
    final request = http.Request('GET', Uri.parse(url));
    final response =
    await request.send().timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw DownloadException('Download failed: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    return file;
  }

  /// Set a downloaded file as the system ringtone on Android.
  /// Requires WRITE_SETTINGS permission — the native side should prompt if needed.
  Future<void> setAsRingtone(File file, String title) async {
    if (!Platform.isAndroid) {
      throw DownloadException(
          'Setting ringtone is only supported on Android.');
    }

    try {
      await _channel.invokeMethod<void>('setRingtone', {
        'filePath': file.path,
        'title': title,
      });
    } on PlatformException catch (e) {
      throw DownloadException(
        'Could not set ringtone: ${e.message ?? e.code}',
      );
    }
  }

  /// Check if a ringtone has already been downloaded.
  Future<bool> isDownloaded(String fileName) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return false;
    final file = File(_filePath(dir, fileName));
    return file.exists();
  }

  /// Get the local [File] for a downloaded ringtone, or null if not present.
  Future<File?> getDownloadedFile(String fileName) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;
    final file = File(_filePath(dir, fileName));
    return (await file.exists()) ? file : null;
  }

  String _filePath(Directory dir, String fileName) {
    final safe =
    fileName.replaceAll(RegExp(r'[^\w\s\-.]'), '_').replaceAll(' ', '_');
    final withExt = safe.endsWith('.mp3') ? safe : '$safe.mp3';
    return '${dir.path}/Ringtones/$withExt';
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);

  @override
  String toString() => 'DownloadException: $message';
}