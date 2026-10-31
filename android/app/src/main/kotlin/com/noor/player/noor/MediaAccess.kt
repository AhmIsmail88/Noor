package com.noor.player.noor

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

/** Document URIs avoid copying the user's media into the application. */
class MediaAccess(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "noor/media_access")
    private var picker: MethodChannel.Result? = null
    private val pending = mutableListOf<Map<String, Any>>()
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pending" -> { result.success(pending.toList()); pending.clear() }
                "pick" -> {
                    if (picker != null) result.error("busy", "Picker already open", null)
                    else {
                        picker = result
                        val type = if (call.argument<Boolean>("audio") == true) "audio/*" else "video/*"
                        try {
                            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE).setType(type)
                                .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION), 97)
                        } catch (e: Exception) { picker = null; result.error("picker", e.toString(), null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun describe(uri: Uri, intent: Intent): Map<String, Any> {
        val resolver = activity.contentResolver
        try {
            if (intent.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0)
                resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) { /* Open-with may grant temporary read access only. */ }
        var name = uri.lastPathSegment ?: "NOOR"
        var size = 0L
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
            if (it.moveToFirst()) { name = it.getString(0) ?: name; size = it.getLong(1) }
        }
        val mime = resolver.getType(uri) ?: intent.type ?: ""
        return mapOf("path" to uri.toString(), "title" to name, "sizeBytes" to size, "isAudio" to mime.startsWith("audio/"))
    }
    fun incoming(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW || intent.data == null) return
        val uri = intent.data!!
        if (uri.scheme != "content" && uri.scheme != "file") return
        try { pending.add(describe(uri, intent)); channel.invokeMethod("available", null) }
        catch (_: Exception) { /* Invalid external file cannot be opened. */ }
    }
    fun result(request: Int, code: Int, data: Intent?): Boolean {
        if (request != 97) return false
        val callback = picker; picker = null
        if (code != Activity.RESULT_OK || data == null) { callback?.success(emptyList<Any>()); return true }
        try {
            val uris = mutableListOf<Uri>()
            data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
            if (uris.isEmpty()) data.data?.let { uris.add(it) }
            callback?.success(uris.map { describe(it, data) })
        } catch (e: Exception) { callback?.error("read", e.toString(), null) }
        return true
    }
}
