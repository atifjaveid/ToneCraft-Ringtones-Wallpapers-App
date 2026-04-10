package com.example.tonecraft

import android.app.WallpaperManager
import android.content.ContentValues
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {

    private val RINGTONE_CHANNEL = "com.ringle.app/set_ringtone"
    private val WALLPAPER_CHANNEL = "com.tonecraft/wallpaper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Ringtone channel ──────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RINGTONE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                "setRingtone" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "Ringtone"
                    if (filePath == null) {
                        result.error("INVALID_ARG", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        // Check WRITE_SETTINGS permission on Android 6+
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.System.canWrite(this)
                        ) {
                            val intent = android.content.Intent(
                                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.error(
                                "PERMISSION_DENIED",
                                "WRITE_SETTINGS permission needed. Please grant it and try again.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val uri = insertRingtoneToMediaStore(filePath, title)
                        if (uri == null) {
                            result.error("INSERT_FAILED", "Could not insert into MediaStore", null)
                            return@setMethodCallHandler
                        }
                        RingtoneManager.setActualDefaultRingtoneUri(
                            this,
                            RingtoneManager.TYPE_RINGTONE,
                            uri
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SET_RINGTONE_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── Wallpaper channel ─────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WALLPAPER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    val path = call.argument<String>("path")
                    val fileName = call.argument<String>("fileName") ?: "wallpaper.jpg"
                    if (path == null) {
                        result.error("INVALID_ARG", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        saveImageToGallery(path, fileName)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }

                "setWallpaper" -> {
                    val path = call.argument<String>("path")
                    val type = call.argument<Int>("type") ?: 3
                    if (path == null) {
                        result.error("INVALID_ARG", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val wm = WallpaperManager.getInstance(this)
                        val bitmap = BitmapFactory.decodeFile(path)
                            ?: throw Exception("Could not decode image at $path")

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            val flag = when (type) {
                                1 -> WallpaperManager.FLAG_SYSTEM
                                2 -> WallpaperManager.FLAG_LOCK
                                else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                            }
                            wm.setBitmap(bitmap, null, true, flag)
                        } else {
                            wm.setBitmap(bitmap)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SET_WALLPAPER_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun insertRingtoneToMediaStore(filePath: String, title: String): Uri? {
        val file = File(filePath)
        if (!file.exists()) return null

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_RINGTONE, true)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
            put(MediaStore.Audio.Media.IS_ALARM, false)
            put(MediaStore.Audio.Media.IS_MUSIC, false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_RINGTONES)
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            } else {
                @Suppress("DEPRECATION")
                put(MediaStore.Audio.Media.DATA, filePath)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            @Suppress("DEPRECATION")
            MediaStore.Audio.Media.getContentUriForPath(filePath)!!
        }

        val uri = contentResolver.insert(collection, values) ?: return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.openOutputStream(uri)?.use { os ->
                FileInputStream(file).use { it.copyTo(os) }
            }
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        }

        return uri
    }

    private fun saveImageToGallery(path: String, fileName: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("File not found: $path")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/ToneCraft"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
            ) ?: throw Exception("Could not create gallery entry")

            contentResolver.openOutputStream(uri)?.use { os ->
                FileInputStream(file).use { it.copyTo(os) }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } else {
            val dest = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                "ToneCraft/$fileName"
            )
            dest.parentFile?.mkdirs()
            file.copyTo(dest, overwrite = true)
            val mediaScanIntent = android.content.Intent(
                android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE
            )
            mediaScanIntent.data = Uri.fromFile(dest)
            sendBroadcast(mediaScanIntent)
        }
    }
}
