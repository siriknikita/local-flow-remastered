package com.localflow.model

sealed class UploadResult {
    data object Idle : UploadResult()
    data object Uploading : UploadResult()
    data class Success(val filename: String) : UploadResult()
    data class Failure(val message: String) : UploadResult()
    data object Queued : UploadResult()
}
