package com.localflow.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface TranscriptDao {
    @Query("SELECT * FROM transcripts ORDER BY createdAt DESC LIMIT :limit")
    fun getRecent(limit: Int): Flow<List<TranscriptEntity>>

    @Query("SELECT MAX(createdAt) FROM transcripts")
    suspend fun getLatestCreatedAt(): Long?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(transcripts: List<TranscriptEntity>)
}
