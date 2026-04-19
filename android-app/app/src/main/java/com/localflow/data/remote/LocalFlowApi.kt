package com.localflow.data.remote

import com.localflow.model.PairedDevice
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import timber.log.Timber
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LocalFlowApi @Inject constructor() {

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    fun healthCheck(host: String, port: Int): Boolean {
        return try {
            val request = Request.Builder()
                .url("http://$host:$port/api/health")
                .get()
                .build()
            val response = client.newCall(request).execute()
            response.isSuccessful
        } catch (e: IOException) {
            Timber.e(e, "Health check failed")
            false
        }
    }

    sealed class PairInitResult {
        data object NeedCode : PairInitResult()
        data class AutoAccepted(val device: PairedDevice) : PairInitResult()
        data class Error(val message: String) : PairInitResult()
    }

    fun initiatePairing(host: String, port: Int, deviceId: String, deviceName: String): PairInitResult {
        return try {
            val json = JSONObject().apply {
                put("deviceId", deviceId)
                put("deviceName", deviceName)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("http://$host:$port/api/pair")
                .post(body)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            if (response.isSuccessful) {
                val responseJson = JSONObject(responseBody)
                val status = responseJson.getString("status")

                if (status == "already_paired" && responseJson.has("token")) {
                    // Auto-accepted — server returned token directly
                    val device = PairedDevice(
                        deviceId = deviceId,
                        serverName = responseJson.getString("serverName"),
                        host = host,
                        port = port,
                        token = responseJson.getString("token")
                    )
                    PairInitResult.AutoAccepted(device)
                } else {
                    PairInitResult.NeedCode
                }
            } else {
                PairInitResult.Error("Pairing failed: ${response.code}")
            }
        } catch (e: Exception) {
            Timber.e(e, "Pairing initiation failed")
            PairInitResult.Error(e.message ?: "Connection failed")
        }
    }

    fun confirmPairing(host: String, port: Int, deviceId: String, code: String): Result<PairedDevice> {
        return try {
            val json = JSONObject().apply {
                put("deviceId", deviceId)
                put("code", code)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("http://$host:$port/api/pair/confirm")
                .post(body)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            if (response.isSuccessful) {
                val responseJson = JSONObject(responseBody)
                val device = PairedDevice(
                    deviceId = deviceId,
                    serverName = responseJson.getString("serverName"),
                    host = host,
                    port = port,
                    token = responseJson.getString("token")
                )
                Result.success(device)
            } else {
                Result.failure(IOException("Pairing confirmation failed: ${response.code} $responseBody"))
            }
        } catch (e: Exception) {
            Timber.e(e, "Pairing confirmation failed")
            Result.failure(e)
        }
    }

    fun notifyRecordingState(device: PairedDevice, isRecording: Boolean): Boolean {
        return try {
            val json = JSONObject().apply {
                put("recording", isRecording)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("http://${device.host}:${device.port}/api/recording")
                .header("Authorization", "Bearer ${device.token}")
                .post(body)
                .build()
            val response = client.newCall(request).execute()
            response.isSuccessful
        } catch (e: Exception) {
            Timber.d(e, "Recording state notification failed")
            false
        }
    }

    fun checkStatus(device: PairedDevice): Boolean {
        return try {
            val request = Request.Builder()
                .url("http://${device.host}:${device.port}/api/status")
                .header("Authorization", "Bearer ${device.token}")
                .get()
                .build()
            val response = client.newCall(request).execute()
            if (response.isSuccessful) {
                val json = JSONObject(response.body?.string() ?: "")
                json.optBoolean("stopRequested", false)
            } else {
                false
            }
        } catch (e: Exception) {
            Timber.d(e, "Status check failed")
            false
        }
    }

    data class TranscriptItem(
        val id: String,
        val filename: String,
        val text: String,
        val createdAt: String
    )

    data class TranscriptsResponse(
        val transcripts: List<TranscriptItem>,
        val serverTime: String
    )

    fun fetchTranscripts(device: PairedDevice, since: String? = null, limit: Int = 20): Result<TranscriptsResponse> {
        return try {
            val urlBuilder = StringBuilder("http://${device.host}:${device.port}/api/transcripts?limit=$limit")
            if (since != null) {
                urlBuilder.append("&since=$since")
            }

            val request = Request.Builder()
                .url(urlBuilder.toString())
                .header("Authorization", "Bearer ${device.token}")
                .get()
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            if (response.isSuccessful) {
                val json = JSONObject(responseBody)
                val transcriptsArray = json.getJSONArray("transcripts")
                val transcripts = mutableListOf<TranscriptItem>()
                for (i in 0 until transcriptsArray.length()) {
                    val item = transcriptsArray.getJSONObject(i)
                    transcripts.add(
                        TranscriptItem(
                            id = item.getString("id"),
                            filename = item.getString("filename"),
                            text = item.getString("text"),
                            createdAt = item.getString("createdAt")
                        )
                    )
                }
                Result.success(
                    TranscriptsResponse(
                        transcripts = transcripts,
                        serverTime = json.getString("serverTime")
                    )
                )
            } else if (response.code == 401) {
                Result.failure(IOException("Unauthorized"))
            } else {
                Result.failure(IOException("Failed to fetch transcripts: ${response.code}"))
            }
        } catch (e: Exception) {
            Timber.e(e, "Fetch transcripts failed")
            Result.failure(e)
        }
    }

    fun uploadAudio(device: PairedDevice, audioFile: File): Result<String> {
        return try {
            val requestBody = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart(
                    "audio",
                    audioFile.name,
                    audioFile.asRequestBody("audio/wav".toMediaType())
                )
                .build()

            val request = Request.Builder()
                .url("http://${device.host}:${device.port}/api/upload?filename=${audioFile.name}")
                .header("Authorization", "Bearer ${device.token}")
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            if (response.isSuccessful) {
                val responseJson = JSONObject(responseBody)
                Result.success(responseJson.getString("filename"))
            } else if (response.code == 401) {
                Result.failure(IOException("Unauthorized — device may need to re-pair"))
            } else {
                Result.failure(IOException("Upload failed: ${response.code} $responseBody"))
            }
        } catch (e: Exception) {
            Timber.e(e, "Upload failed")
            Result.failure(e)
        }
    }
}
