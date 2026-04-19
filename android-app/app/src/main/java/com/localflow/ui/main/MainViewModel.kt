package com.localflow.ui.main

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.localflow.data.local.PairedDeviceStore
import com.localflow.data.local.TranscriptEntity
import com.localflow.data.remote.LocalFlowApi
import com.localflow.model.ConnectionState
import com.localflow.model.PairedDevice
import com.localflow.model.RecordingState
import com.localflow.model.UploadResult
import com.localflow.recording.AudioRecorder
import com.localflow.sync.TranscriptSyncManager
import com.localflow.upload.UploadManager
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val pairedDeviceStore: PairedDeviceStore,
    private val audioRecorder: AudioRecorder,
    private val uploadManager: UploadManager,
    private val api: LocalFlowApi,
    private val transcriptSyncManager: TranscriptSyncManager
) : ViewModel() {

    private val pairedDevice: StateFlow<PairedDevice?> = pairedDeviceStore.pairedDevice
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState

    private val _recordingState = MutableStateFlow<RecordingState>(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState

    val uploadState: StateFlow<UploadResult> = uploadManager.uploadState

    val pendingCount: StateFlow<Int> = uploadManager.pendingCount
        .stateIn(viewModelScope, SharingStarted.Eagerly, 0)

    private val _recordingDuration = MutableStateFlow(0L)
    val recordingDuration: StateFlow<Long> = _recordingDuration

    val transcripts: StateFlow<List<TranscriptEntity>> = transcriptSyncManager.transcripts
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val isSyncingTranscripts: StateFlow<Boolean> = transcriptSyncManager.isSyncing

    init {
        // Watch paired device and check connection
        viewModelScope.launch {
            pairedDevice.collect { device ->
                if (device != null) {
                    checkConnection(device)
                } else {
                    _connectionState.value = ConnectionState.Disconnected
                }
            }
        }

        // Retry pending uploads and sync transcripts when connected
        viewModelScope.launch {
            connectionState.collect { state ->
                if (state is ConnectionState.Connected) {
                    while (uploadManager.retryPending(state.device)) {
                        // keep retrying until queue is empty or a retry fails
                    }
                }
            }
        }

        // Sync transcripts periodically while connected
        viewModelScope.launch {
            connectionState.collect { state ->
                if (state is ConnectionState.Connected) {
                    transcriptSyncManager.sync(state.device)
                    // Start periodic sync
                    while (connectionState.value is ConnectionState.Connected) {
                        delay(10_000)
                        val currentState = connectionState.value
                        if (currentState is ConnectionState.Connected) {
                            transcriptSyncManager.sync(currentState.device)
                        }
                    }
                }
            }
        }
    }

    private suspend fun checkConnection(device: PairedDevice) {
        val isHealthy = withContext(Dispatchers.IO) {
            api.healthCheck(device.host, device.port)
        }
        _connectionState.value = if (isHealthy) {
            ConnectionState.Connected(device)
        } else {
            ConnectionState.Error("MacBook unreachable")
        }
    }

    fun refreshConnection() {
        viewModelScope.launch {
            pairedDevice.value?.let { checkConnection(it) }
        }
    }

    fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun startRecording() {
        if (!hasRecordPermission()) return

        try {
            audioRecorder.startRecording()
            _recordingState.value = RecordingState.Recording()
            uploadManager.resetState()

            // Notify Mac that phone started recording
            viewModelScope.launch {
                val device = pairedDevice.value ?: return@launch
                withContext(Dispatchers.IO) {
                    api.notifyRecordingState(device, true)
                }
            }

            // Track duration
            viewModelScope.launch {
                val startTime = System.currentTimeMillis()
                while (_recordingState.value is RecordingState.Recording) {
                    _recordingDuration.value = System.currentTimeMillis() - startTime
                    delay(100)
                }
            }

            // Poll Mac for stop command
            viewModelScope.launch {
                val device = pairedDevice.value ?: return@launch
                while (_recordingState.value is RecordingState.Recording) {
                    delay(1500)
                    val shouldStop = withContext(Dispatchers.IO) {
                        api.checkStatus(device)
                    }
                    if (shouldStop && _recordingState.value is RecordingState.Recording) {
                        stopRecording()
                        break
                    }
                }
            }
        } catch (e: Exception) {
            _recordingState.value = RecordingState.Idle
        }
    }

    fun stopRecording() {
        _recordingState.value = RecordingState.Stopping

        val file = audioRecorder.stopRecording()
        _recordingState.value = RecordingState.Idle
        _recordingDuration.value = 0

        // Notify Mac that phone stopped recording
        viewModelScope.launch {
            val device = pairedDevice.value ?: return@launch
            withContext(Dispatchers.IO) {
                api.notifyRecordingState(device, false)
            }
        }

        if (file == null) return

        val device = pairedDevice.value ?: return

        viewModelScope.launch {
            val result = uploadManager.upload(device, file)
            if (result is UploadResult.Success) {
                delay(3000)
                uploadManager.resetState()
                // Sync transcripts after upload — give transcription time to complete
                delay(5000)
                (connectionState.value as? ConnectionState.Connected)?.device?.let {
                    transcriptSyncManager.sync(it)
                }
            }
        }
    }

    fun refreshTranscripts() {
        viewModelScope.launch {
            (connectionState.value as? ConnectionState.Connected)?.device?.let {
                transcriptSyncManager.sync(it)
            }
        }
    }

    fun unpair() {
        viewModelScope.launch {
            pairedDeviceStore.clearDevice()
            _connectionState.value = ConnectionState.Disconnected
        }
    }
}
