package com.localflow.model

data class PairedDevice(
    val deviceId: String,
    val serverName: String,
    val host: String,
    val port: Int,
    val token: String,
    val pairedAt: Long = System.currentTimeMillis()
)
