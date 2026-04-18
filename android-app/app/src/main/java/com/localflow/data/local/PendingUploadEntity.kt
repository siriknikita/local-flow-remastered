package com.localflow.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "pending_uploads")
data class PendingUploadEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val filePath: String,
    val filename: String,
    val createdAt: Long = System.currentTimeMillis(),
    val retryCount: Int = 0
)
