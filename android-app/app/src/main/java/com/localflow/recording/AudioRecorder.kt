package com.localflow.recording

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import timber.log.Timber
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AudioRecorder @Inject constructor(
    private val context: Context
) {
    private var recorder: MediaRecorder? = null
    private var currentFile: File? = null

    val isRecording: Boolean
        get() = recorder != null

    fun startRecording(): File {
        val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
        val filename = "recording_${timestamp}.m4a"
        val file = File(context.cacheDir, filename)

        val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        mr.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioEncodingBitRate(128000)
            setAudioChannels(1)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }

        recorder = mr
        currentFile = file
        Timber.d("Recording started: ${file.name}")
        return file
    }

    fun stopRecording(): File? {
        return try {
            recorder?.apply {
                stop()
                release()
            }
            recorder = null
            val file = currentFile
            currentFile = null
            Timber.d("Recording stopped: ${file?.name}")
            file
        } catch (e: Exception) {
            Timber.e(e, "Error stopping recording")
            recorder?.release()
            recorder = null
            currentFile = null
            null
        }
    }

    fun cancelRecording() {
        try {
            recorder?.apply {
                stop()
                release()
            }
        } catch (_: Exception) {
            recorder?.release()
        }
        recorder = null
        currentFile?.delete()
        currentFile = null
    }
}
