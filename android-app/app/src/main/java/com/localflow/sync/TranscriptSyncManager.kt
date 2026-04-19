package com.localflow.sync

import com.localflow.data.local.TranscriptDao
import com.localflow.data.local.TranscriptEntity
import com.localflow.data.remote.LocalFlowApi
import com.localflow.model.PairedDevice
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import timber.log.Timber
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TranscriptSyncManager @Inject constructor(
    private val api: LocalFlowApi,
    private val transcriptDao: TranscriptDao
) {
    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing

    val transcripts: Flow<List<TranscriptEntity>> = transcriptDao.getRecent(20)

    suspend fun sync(device: PairedDevice) {
        if (_isSyncing.value) return
        _isSyncing.value = true

        try {
            val latestCreatedAt = transcriptDao.getLatestCreatedAt()
            val since = latestCreatedAt?.let { formatISO8601(it) }

            val result = api.fetchTranscripts(device, since)
            result.onSuccess { response ->
                val entities = response.transcripts.map { item ->
                    TranscriptEntity(
                        id = item.id,
                        text = item.text,
                        createdAt = parseISO8601(item.createdAt),
                        syncedAt = System.currentTimeMillis()
                    )
                }
                if (entities.isNotEmpty()) {
                    transcriptDao.insertAll(entities)
                }
            }.onFailure { e ->
                Timber.e(e, "Transcript sync failed")
            }
        } finally {
            _isSyncing.value = false
        }
    }

    companion object {
        private val iso8601Format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        private fun formatISO8601(epochMillis: Long): String {
            return iso8601Format.format(epochMillis)
        }

        private fun parseISO8601(dateString: String): Long {
            return try {
                iso8601Format.parse(dateString)?.time ?: 0L
            } catch (e: Exception) {
                0L
            }
        }
    }
}
