package com.localflow.ui.discovery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.localflow.data.local.PairedDeviceStore
import com.localflow.discovery.NsdDiscoveryManager
import com.localflow.model.ConnectionState
import com.localflow.model.PairedDevice
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DiscoveryViewModel @Inject constructor(
    private val discoveryManager: NsdDiscoveryManager,
    private val pairedDeviceStore: PairedDeviceStore
) : ViewModel() {

    val discoveryState: StateFlow<ConnectionState> = discoveryManager.discoveryState

    val pairedDevice: StateFlow<PairedDevice?> = pairedDeviceStore.pairedDevice
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _manualHost = MutableStateFlow("")
    val manualHost: StateFlow<String> = _manualHost

    private val _manualPort = MutableStateFlow("8080")
    val manualPort: StateFlow<String> = _manualPort

    fun startDiscovery() {
        discoveryManager.startDiscovery()
    }

    fun stopDiscovery() {
        discoveryManager.stopDiscovery()
    }

    fun setManualHost(host: String) {
        _manualHost.value = host
    }

    fun setManualPort(port: String) {
        _manualPort.value = port
    }

    fun connectManually() {
        val host = _manualHost.value
        val port = _manualPort.value.toIntOrNull() ?: 8080
        if (host.isNotBlank()) {
            discoveryManager.setManualConnection(host, port)
        }
    }

    fun unpair() {
        viewModelScope.launch {
            pairedDeviceStore.clearDevice()
        }
    }

    override fun onCleared() {
        super.onCleared()
        discoveryManager.stopDiscovery()
    }
}
