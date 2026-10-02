package com.example.project4

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val io = Executors.newSingleThreadExecutor()
    private val audioListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change <= AudioManager.AUDIOFOCUS_LOSS) stopCry()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pft/media").setMethodCallHandler { call, result ->
            when (call.method) {
                "playCry" -> {
                    val id = call.argument<Int>("id")
                    if (id !in setOf(1,6,25,93,95,132,133,134,135,136,146,149,150)) {
                        result.error("cry_missing", "This Pokémon has no bundled cry.", null)
                    } else try {
                        playCry(id!!)
                        result.success(null)
                    } catch (_: Exception) {
                        stopCry()
                        result.error("audio_failed", "Could not play this cry. Check media volume.", null)
                    }
                }
                "stopCry" -> { stopCry(); result.success(null) }
                "shareMedia" -> shareMedia(call.argument<String>("path"), call.argument<String>("destination"), result)
                else -> result.notImplemented()
            }
        }
    }
    private fun playCry(id: Int) {
        stopCry()
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(audioListener).build()
            focus = request
            audio.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(audioListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { stopCry(); return }
        val extension = if (id == 25) "mp3" else "ogg"
        val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/audio/$id.$extension")
        assets.openFd(assetKey).use { fd ->
            val sound = MediaPlayer()
            player = sound
            sound.setAudioAttributes(attributes)
            sound.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            sound.setOnPreparedListener { if (player === it && !isFinishing) it.start() }
            sound.setOnCompletionListener { if (player === it) stopCry() }
            sound.setOnErrorListener { _, _, _ -> stopCry(); true }
            sound.prepareAsync()
        }
    }
    private fun stopCry() {
        player?.release()
        player = null
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else { @Suppress("DEPRECATION") audio.abandonAudioFocus(audioListener) }
        focus = null
    }
    private fun shareMedia(path: String?, destination: String?, result: MethodChannel.Result) {
        val target = when(destination) {
            "instagram" -> "com.instagram.android"
            "twitter" -> "com.twitter.android"
            "other" -> null
            else -> { result.error("share_invalid", "Choose a sharing destination.", null); return }
        }
        io.execute {
            try {
                val root = File(applicationInfo.dataDir, "app_flutter/pft-gallery").canonicalFile
                val source = File(path ?: "").canonicalFile
                require(source.parentFile == root && source.name.matches(Regex("[0-9]+\\.(png|jpg|mp4)")) && source.isFile && source.length() > 0)
                val folder = File(cacheDir, "photobook-share").apply { mkdirs() }
                // Remove only our expired temporary exports, never gallery originals.
                folder.listFiles()?.filter { it.isFile && System.currentTimeMillis()-it.lastModified() > 86_400_000 }?.forEach { it.delete() }
                val export = File(folder, "fieldnotes-${UUID.randomUUID()}.${source.extension}")
                source.copyTo(export)
                val uri = FileProvider.getUriForFile(this, "$packageName.photobook", export)
                val mime = when(source.extension) { "mp4" -> "video/mp4"; "png" -> "image/png"; else -> "image/jpeg" }
                runOnUiThread {
                    if (isFinishing || isDestroyed) { result.error("share_closed", "Open the capture and try again.", null); return@runOnUiThread }
                    try {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newUri(contentResolver, "Fieldnotes capture", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (target != null) setPackage(target)
                        }
                        if (target != null && send.resolveActivity(packageManager) == null) {
                            result.error("app_unavailable", "Install or update ${if(destination == "instagram") "Instagram" else "Twitter / X"}, or use More apps.", null)
                        } else {
                            startActivity(if (target == null) Intent.createChooser(send, "Share your fieldnote") else send)
                            result.success(null) // Composer opened; this does not claim a post was sent.
                        }
                    } catch (_: ActivityNotFoundException) {
                        result.error("app_unavailable", "No compatible app found. Try More apps.", null)
                    } catch (_: Exception) {
                        result.error("share_failed", "Could not open sharing. Try More apps.", null)
                    }
                }
            } catch (_: Exception) {
                runOnUiThread { result.error("share_failed", "Could not prepare this capture. Check free space and try again.", null) }
            }
        }
    }
    override fun onPause() { stopCry(); super.onPause() }
    override fun onDestroy() { stopCry(); io.shutdown(); super.onDestroy() }
}
