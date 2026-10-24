package fr.iglittoral.opensampler

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * Saves or shares a large file (project export) straight from disk, without
 * ever loading it in memory: the Dart side only passes the file path.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "opensampler/files"
    private val saveRequest = 4711
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSource: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveFile" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name") ?: "export.zip"
                    val mime = call.argument<String>("mime") ?: "application/zip"
                    if (path == null || pendingResult != null) {
                        result.error("busy", "Another save is in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    pendingSource = File(path)
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    try {
                        startActivityForResult(intent, saveRequest)
                    } catch (e: Exception) {
                        pendingResult = null
                        pendingSource = null
                        result.error("no_picker", e.message, null)
                    }
                }
                "shareFile" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mime") ?: "application/zip"
                    val title = call.argument<String>("title") ?: ""
                    if (path == null) {
                        result.error("args", "Missing path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.files", File(path))
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(send, title))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val result = pendingResult ?: return
        val source = pendingSource
        pendingResult = null
        pendingSource = null

        val target: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || target == null || source == null) {
            result.success(false) // cancelled
            return
        }
        // Copy on a background thread, 256 KB at a time.
        Thread {
            try {
                contentResolver.openOutputStream(target, "w").use { out ->
                    FileInputStream(source).use { input ->
                        val buffer = ByteArray(256 * 1024)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            out!!.write(buffer, 0, n)
                        }
                        out!!.flush()
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("write_failed", e.message, null) }
            }
        }.start()
    }
}
