package com.localflow.model

sealed class ConnectionState {
    data object Disconnected : ConnectionState()
    data object Discovering : ConnectionState()
    data class Found(val host: String, val port: Int, val name: String) : ConnectionState()
    data class Connected(val device: PairedDevice) : ConnectionState()
    data class Error(val message: String) : ConnectionState()
}
