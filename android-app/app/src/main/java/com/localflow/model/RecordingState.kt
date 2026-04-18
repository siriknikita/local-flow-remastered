package com.localflow.model

sealed class RecordingState {
    data object Idle : RecordingState()
    data class Recording(val startTime: Long = System.currentTimeMillis()) : RecordingState()
    data object Stopping : RecordingState()
}
