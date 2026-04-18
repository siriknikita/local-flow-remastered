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

    fun initiatePairing(host: String, port: Int, deviceId: String, deviceName: String): Result<String> {
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
                Result.success(responseJson.getString("message"))
            } else {
                Result.failure(IOException("Pairing failed: ${response.code} $responseBody"))
            }
        } catch (e: Exception) {
            Timber.e(e, "Pairing initiation failed")
            Result.failure(e)
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
