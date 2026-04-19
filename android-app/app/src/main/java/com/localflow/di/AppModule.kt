package com.localflow.di

import android.content.Context
import androidx.room.Room
import com.localflow.data.local.AppDatabase
import com.localflow.data.local.PairedDeviceStore
import com.localflow.data.local.PendingUploadDao
import com.localflow.data.local.TranscriptDao
import com.localflow.data.remote.LocalFlowApi
import com.localflow.discovery.NsdDiscoveryManager
import com.localflow.recording.AudioRecorder
import com.localflow.sync.TranscriptSyncManager
import com.localflow.upload.UploadManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideContext(@ApplicationContext context: Context): Context = context

    @Provides
    @Singleton
    fun provideLocalFlowApi(): LocalFlowApi = LocalFlowApi()

    @Provides
    @Singleton
    fun provideNsdDiscoveryManager(@ApplicationContext context: Context): NsdDiscoveryManager =
        NsdDiscoveryManager(context)

    @Provides
    @Singleton
    fun providePairedDeviceStore(@ApplicationContext context: Context): PairedDeviceStore =
        PairedDeviceStore(context)

    @Provides
    @Singleton
    fun provideAudioRecorder(@ApplicationContext context: Context): AudioRecorder =
        AudioRecorder(context)

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "localflow.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    @Singleton
    fun providePendingUploadDao(db: AppDatabase): PendingUploadDao = db.pendingUploadDao()

    @Provides
    @Singleton
    fun provideTranscriptDao(db: AppDatabase): TranscriptDao = db.transcriptDao()

    @Provides
    @Singleton
    fun provideUploadManager(api: LocalFlowApi, pendingUploadDao: PendingUploadDao): UploadManager =
        UploadManager(api, pendingUploadDao)

    @Provides
    @Singleton
    fun provideTranscriptSyncManager(api: LocalFlowApi, dao: TranscriptDao): TranscriptSyncManager =
        TranscriptSyncManager(api, dao)
}
