package com.localflow.upload

import com.localflow.data.local.PendingUploadDao
import com.localflow.data.local.PendingUploadEntity
import com.localflow.data.remote.LocalFlowApi
import com.localflow.model.PairedDevice
import com.localflow.model.UploadResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UploadManager @Inject constructor(
    private val api: LocalFlowApi,
    private val pendingUploadDao: PendingUploadDao
) {
    private val _uploadState = MutableStateFlow<UploadResult>(UploadResult.Idle)
    val uploadState: StateFlow<UploadResult> = _uploadState

    val pendingCount: Flow<Int> = pendingUploadDao.getCount()
    val pendingUploads: Flow<List<PendingUploadEntity>> = pendingUploadDao.getAll()

    suspend fun upload(device: PairedDevice, audioFile: File): UploadResult {
        _uploadState.value = UploadResult.Uploading

        return withContext(Dispatchers.IO) {
            val result = api.uploadAudio(device, audioFile)

            result.fold(
                onSuccess = { filename ->
                    Timber.d("Upload successful: $filename")
                    val uploadResult = UploadResult.Success(filename)
                    _uploadState.value = uploadResult
                    audioFile.delete()
                    uploadResult
                },
                onFailure = { error ->
                    Timber.e(error, "Upload failed, queueing for retry")
                    pendingUploadDao.insert(
                        PendingUploadEntity(
                            filePath = audioFile.absolutePath,
                            filename = audioFile.name
                        )
                    )
                    val uploadResult = UploadResult.Queued
                    _uploadState.value = uploadResult
                    uploadResult
                }
            )
        }
    }

    suspend fun retryPending(device: PairedDevice): Boolean {
        val pending = pendingUploadDao.getOldest() ?: return false
        val file = File(pending.filePath)

        if (!file.exists()) {
            pendingUploadDao.delete(pending)
            return retryPending(device)
        }

        return withContext(Dispatchers.IO) {
            val result = api.uploadAudio(device, file)
            result.fold(
                onSuccess = {
                    Timber.d("Retry successful: ${pending.filename}")
                    pendingUploadDao.delete(pending)
                    file.delete()
                    true
                },
                onFailure = {
                    Timber.e(it, "Retry failed: ${pending.filename}")
                    pendingUploadDao.update(pending.copy(retryCount = pending.retryCount + 1))
                    false
                }
            )
        }
    }

    suspend fun deletePending(id: Long) {
        pendingUploadDao.deleteById(id)
    }

    fun resetState() {
        _uploadState.value = UploadResult.Idle
    }
}
