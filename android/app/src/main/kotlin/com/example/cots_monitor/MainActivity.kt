package com.example.cots_monitor

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var pendingLimit = 30

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "cots_activity",
                "COTS activity",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Detection reviews, assignments, and monitoring updates"
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHOTO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImages" -> {
                        if (pendingPick != null) {
                            result.error("busy", "Photo selection is already open.", null)
                        } else {
                            pendingPick = result
                            pendingLimit = (call.argument<Int>("limit") ?: 30).coerceIn(1, 100)
                            requestPhotoAccessThenPick()
                        }
                    }
                    "photoLocationAllowed" -> result.success(photoLocationAllowed())
                    else -> result.notImplemented()
                }
            }
    }

    // Stage 7: true when the app may read the GPS saved in photos.
    private fun photoLocationAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return true
        val read = if (Build.VERSION.SDK_INT >= 33) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return checkSelfPermission(read) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    // Photo location is only readable from the original file, which Android
    // returns when the app holds ACCESS_MEDIA_LOCATION and photo read access.
    private fun requestPhotoAccessThenPick() {
        val wanted = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 33) {
            wanted += Manifest.permission.READ_MEDIA_IMAGES
        } else {
            wanted += Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (Build.VERSION.SDK_INT >= 29) {
            wanted += Manifest.permission.ACCESS_MEDIA_LOCATION
        }
        val missing = wanted.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            launchPhotoPicker()
        } else {
            requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Continue even if denied: photos still load, but their location may be hidden.
        if (requestCode == PERMISSION_REQUEST) launchPhotoPicker()
    }

    private fun launchPhotoPicker() {
        // ACTION_OPEN_DOCUMENT returns media documents that can be resolved to
        // their original MediaStore entry. The system photo picker cannot.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, PICK_REQUEST)
        } catch (error: Exception) {
            finishPick { it.error("unavailable", "No photo picker is available.", null) }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_REQUEST) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            finishPick { it.success(emptyList<Map<String, Any?>>()) }
            return
        }
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) uris += clip.getItemAt(i).uri
        } else {
            data.data?.let { uris += it }
        }
        val limit = pendingLimit
        Thread {
            try {
                val picked = uris.take(limit).mapNotNull { copyPhoto(it) }
                runOnUiThread { finishPick { it.success(picked) } }
            } catch (error: Exception) {
                runOnUiThread {
                    finishPick { it.error("copy_failed", "The selected photos could not be read.", null) }
                }
            }
        }.start()
    }

    private fun finishPick(block: (MethodChannel.Result) -> Unit) {
        val result = pendingPick ?: return
        pendingPick = null
        block(result)
    }

    private fun copyPhoto(uri: Uri): Map<String, Any?>? {
        val name = displayName(uri) ?: "photo_${System.currentTimeMillis()}.jpg"
        val folder = File(cacheDir, "original_photos").apply { mkdirs() }
        val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val target = File(folder, "${System.nanoTime()}_$safeName")
        val original = openOriginal(uri)
        val input = original ?: contentResolver.openInputStream(uri) ?: return null
        input.use { source -> target.outputStream().use { source.copyTo(it) } }
        return mapOf(
            "path" to target.absolutePath,
            "name" to name,
            "originalRequested" to (original != null),
        )
    }

    private fun openOriginal(uri: Uri): InputStream? {
        if (Build.VERSION.SDK_INT < 29) return null
        if (checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }
        return try {
            val mediaUri = if (DocumentsContract.isDocumentUri(this, uri)) {
                MediaStore.getMediaUri(this, uri)
            } else {
                uri
            }
            if (mediaUri == null || mediaUri.authority != MediaStore.AUTHORITY) {
                null
            } else {
                contentResolver.openInputStream(MediaStore.setRequireOriginal(mediaUri))
            }
        } catch (error: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
    } catch (error: Exception) {
        null
    }

    companion object {
        private const val PHOTO_CHANNEL = "cots_monitor/original_photos"
        private const val PICK_REQUEST = 7301
        private const val PERMISSION_REQUEST = 7302
    }
}
