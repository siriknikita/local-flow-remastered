package com.localflow.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [PendingUploadEntity::class, TranscriptEntity::class],
    version = 2,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun pendingUploadDao(): PendingUploadDao
    abstract fun transcriptDao(): TranscriptDao
}
