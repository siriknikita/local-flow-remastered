package com.localflow.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface PendingUploadDao {
    @Query("SELECT * FROM pending_uploads ORDER BY createdAt DESC")
    fun getAll(): Flow<List<PendingUploadEntity>>

    @Query("SELECT * FROM pending_uploads ORDER BY createdAt ASC LIMIT 1")
    suspend fun getOldest(): PendingUploadEntity?

    @Query("SELECT COUNT(*) FROM pending_uploads")
    fun getCount(): Flow<Int>

    @Insert
    suspend fun insert(upload: PendingUploadEntity)

    @Update
    suspend fun update(upload: PendingUploadEntity)

    @Delete
    suspend fun delete(upload: PendingUploadEntity)

    @Query("DELETE FROM pending_uploads WHERE id = :id")
    suspend fun deleteById(id: Long)
}
