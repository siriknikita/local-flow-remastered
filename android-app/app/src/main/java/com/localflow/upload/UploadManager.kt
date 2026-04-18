package com.localflow.upload

import com.localflow.data.remote.LocalFlowApi
import com.localflow.model.PairedDevice
import com.localflow.model.UploadResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UploadManager @Inject constructor(
    private val api: LocalFlowApi
) {
    private val _uploadState = MutableStateFlow<UploadResult>(UploadResult.Idle)
    val uploadState: StateFlow<UploadResult> = _uploadState

    suspend fun upload(device: PairedDevice, audioFile: File): UploadResult {
        _uploadState.value = UploadResult.Uploading

        return withContext(Dispatchers.IO) {
            val result = api.uploadAudio(device, audioFile)

            result.fold(
                onSuccess = { filename ->
                    Timber.d("Upload successful: $filename")
                    val uploadResult = UploadResult.Success(filename)
                    _uploadState.value = uploadResult
                    // Clean up the local cache file after successful upload
                    audioFile.delete()
                    uploadResult
                },
                onFailure = { error ->
                    Timber.e(error, "Upload failed")
                    val uploadResult = UploadResult.Failure(error.message ?: "Upload failed")
                    _uploadState.value = uploadResult
                    uploadResult
                }
            )
        }
    }

    fun resetState() {
        _uploadState.value = UploadResult.Idle
    }
}
