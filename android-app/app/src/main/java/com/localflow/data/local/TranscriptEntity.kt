package com.localflow.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "transcripts")
data class TranscriptEntity(
    @PrimaryKey val id: String,
    val text: String,
    val createdAt: Long,
    val syncedAt: Long = System.currentTimeMillis()
)
