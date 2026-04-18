package com.localflow.ui.pairing

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Link
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PairingScreen(
    viewModel: PairingViewModel,
    host: String,
    port: Int,
    serverName: String,
    onPaired: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    val code by viewModel.code.collectAsState()
    var hasNavigated by remember { mutableStateOf(false) }

    // Auto-initiate pairing (guarded in ViewModel)
    LaunchedEffect(Unit) {
        viewModel.initiatePairing(host, port)
    }

    // Navigate on successful pairing (once)
    LaunchedEffect(state) {
        if (state is PairingState.Paired && !hasNavigated) {
            hasNavigated = true
            onPaired()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Pair with $serverName") })
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.Link,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(24.dp))

            when (state) {
                is PairingState.Idle, is PairingState.Initiating -> {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Connecting to $serverName...")
                }

                is PairingState.WaitingForCode -> {
                    Text(
                        "Enter the 6-digit code shown on your Mac",
                        style = MaterialTheme.typography.bodyLarge,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    OutlinedTextField(
                        value = code,
                        onValueChange = { viewModel.setCode(it) },
                        label = { Text("Pairing Code") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        textStyle = MaterialTheme.typography.headlineMedium.copy(
                            textAlign = TextAlign.Center
                        ),
                        modifier = Modifier.width(200.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = { viewModel.confirmPairing(host, port) },
                        enabled = code.length == 6
                    ) {
                        Text("Pair")
                    }
                }

                is PairingState.Confirming -> {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Verifying code...")
                }

                is PairingState.Paired -> {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text("Paired successfully!", style = MaterialTheme.typography.headlineSmall)
                }

                is PairingState.Error -> {
                    val errorMsg = (state as PairingState.Error).message
                    Text(
                        errorMsg,
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.retryPairing(host, port) }) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}
