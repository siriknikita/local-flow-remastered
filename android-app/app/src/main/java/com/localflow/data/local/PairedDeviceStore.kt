package com.localflow.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.localflow.model.PairedDevice
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "paired_device")

@Singleton
class PairedDeviceStore @Inject constructor(
    private val context: Context
) {
    companion object {
        private val KEY_DEVICE_JSON = stringPreferencesKey("paired_device_json")
    }

    val pairedDevice: Flow<PairedDevice?> = context.dataStore.data.map { prefs ->
        prefs[KEY_DEVICE_JSON]?.let { json ->
            try {
                val obj = JSONObject(json)
                PairedDevice(
                    deviceId = obj.getString("deviceId"),
                    serverName = obj.getString("serverName"),
                    host = obj.getString("host"),
                    port = obj.getInt("port"),
                    token = obj.getString("token"),
                    pairedAt = obj.getLong("pairedAt")
                )
            } catch (e: Exception) {
                null
            }
        }
    }

    suspend fun saveDevice(device: PairedDevice) {
        val json = JSONObject().apply {
            put("deviceId", device.deviceId)
            put("serverName", device.serverName)
            put("host", device.host)
            put("port", device.port)
            put("token", device.token)
            put("pairedAt", device.pairedAt)
        }
        context.dataStore.edit { prefs ->
            prefs[KEY_DEVICE_JSON] = json.toString()
        }
    }

    suspend fun clearDevice() {
        context.dataStore.edit { prefs ->
            prefs.remove(KEY_DEVICE_JSON)
        }
    }
}
