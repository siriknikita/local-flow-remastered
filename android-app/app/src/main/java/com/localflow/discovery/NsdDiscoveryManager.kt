package com.localflow.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import com.localflow.model.ConnectionState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NsdDiscoveryManager @Inject constructor(
    private val context: Context
) {
    companion object {
        private const val SERVICE_TYPE = "_localflow._tcp."
    }

    private val nsdManager: NsdManager by lazy {
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }

    private val _discoveryState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val discoveryState: StateFlow<ConnectionState> = _discoveryState

    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var isDiscovering = false

    fun startDiscovery() {
        if (isDiscovering) return

        _discoveryState.value = ConnectionState.Discovering

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Timber.d("Discovery started for $serviceType")
                isDiscovering = true
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Timber.d("Service found: ${serviceInfo.serviceName}")
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Timber.d("Service lost: ${serviceInfo.serviceName}")
                _discoveryState.value = ConnectionState.Disconnected
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Timber.d("Discovery stopped")
                isDiscovering = false
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Timber.e("Discovery start failed: $errorCode")
                _discoveryState.value = ConnectionState.Error("Discovery failed (error $errorCode)")
                isDiscovering = false
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Timber.e("Discovery stop failed: $errorCode")
            }
        }

        nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }

    fun stopDiscovery() {
        if (!isDiscovering) return
        try {
            discoveryListener?.let { nsdManager.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Timber.e(e, "Error stopping discovery")
        }
        isDiscovering = false
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        nsdManager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Timber.e("Resolve failed: $errorCode")
            }

            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                val host = serviceInfo.host?.hostAddress ?: return
                val port = serviceInfo.port
                val name = serviceInfo.serviceName

                Timber.d("Resolved: $name at $host:$port")
                _discoveryState.value = ConnectionState.Found(host, port, name)
            }
        })
    }

    fun setManualConnection(host: String, port: Int) {
        _discoveryState.value = ConnectionState.Found(host, port, "Manual")
    }
}
