package com.localflow.ui.pairing

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.localflow.data.local.PairedDeviceStore
import com.localflow.data.remote.LocalFlowApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject

sealed class PairingState {
    data object Idle : PairingState()
    data object Initiating : PairingState()
    data object WaitingForCode : PairingState()
    data object Confirming : PairingState()
    data object Paired : PairingState()
    data class Error(val message: String) : PairingState()
}

@HiltViewModel
class PairingViewModel @Inject constructor(
    private val api: LocalFlowApi,
    private val deviceStore: PairedDeviceStore
) : ViewModel() {

    private val _state = MutableStateFlow<PairingState>(PairingState.Idle)
    val state: StateFlow<PairingState> = _state

    private val _code = MutableStateFlow("")
    val code: StateFlow<String> = _code

    private val deviceId = UUID.randomUUID().toString()
    private var hasPairingStarted = false

    fun setCode(code: String) {
        _code.value = code.filter { it.isDigit() }.take(6)
    }

    fun initiatePairing(host: String, port: Int) {
        if (hasPairingStarted) return
        hasPairingStarted = true

        viewModelScope.launch {
            _state.value = PairingState.Initiating

            val result = withContext(Dispatchers.IO) {
                api.initiatePairing(host, port, deviceId, android.os.Build.MODEL)
            }

            result.fold(
                onSuccess = {
                    _state.value = PairingState.WaitingForCode
                },
                onFailure = { error ->
                    _state.value = PairingState.Error(error.message ?: "Pairing failed")
                    hasPairingStarted = false
                }
            )
        }
    }

    fun confirmPairing(host: String, port: Int) {
        val enteredCode = _code.value
        if (enteredCode.length != 6) {
            _state.value = PairingState.Error("Please enter the 6-digit code")
            return
        }

        viewModelScope.launch {
            _state.value = PairingState.Confirming

            val result = withContext(Dispatchers.IO) {
                api.confirmPairing(host, port, deviceId, enteredCode)
            }

            result.fold(
                onSuccess = { device ->
                    deviceStore.saveDevice(device)
                    _state.value = PairingState.Paired
                },
                onFailure = { error ->
                    _state.value = PairingState.Error(error.message ?: "Pairing confirmation failed")
                }
            )
        }
    }

    fun retryPairing(host: String, port: Int) {
        hasPairingStarted = false
        _code.value = ""
        initiatePairing(host, port)
    }
}
