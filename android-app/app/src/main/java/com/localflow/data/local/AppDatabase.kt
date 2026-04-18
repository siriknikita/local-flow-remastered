package com.localflow.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [PendingUploadEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun pendingUploadDao(): PendingUploadDao
}
