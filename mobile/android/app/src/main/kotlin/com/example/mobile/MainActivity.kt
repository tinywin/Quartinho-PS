package com.example.mobile

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.MediaStore
import java.io.File

class MainActivity: FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quartinho/download").setMethodCallHandler { call, result ->
			when (call.method) {
				"saveFileToDownloads" -> {
					val path = call.argument<String>("path")
					val displayName = call.argument<String>("displayName")
					val mimeType = call.argument<String>("mimeType") ?: "*/*"
					if (path == null || displayName == null) {
						result.error("bad_args", "path or displayName missing", null)
						return@setMethodCallHandler
					}
					try {
						val file = File(path)
						val resolver = applicationContext.contentResolver
						val values = ContentValues().apply {
							put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
							put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
							// place under Downloads/Quartinho
							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
								put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Quartinho")
							}
						}
						val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
						val uri = resolver.insert(collection, values)
						if (uri == null) {
							result.error("insert_failed", "Could not create entry in MediaStore", null)
							return@setMethodCallHandler
						}
						resolver.openOutputStream(uri).use { out ->
							file.inputStream().use { input ->
								input.copyTo(out!!)
							}
						}
						result.success(uri.toString())
					} catch (e: Exception) {
						result.error("save_failed", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
