package com.localflow.ui.discovery

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.localflow.model.ConnectionState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoveryScreen(
    viewModel: DiscoveryViewModel,
    onDeviceFound: (host: String, port: Int, name: String) -> Unit,
    onAlreadyPaired: () -> Unit
) {
    val discoveryState by viewModel.discoveryState.collectAsState()
    val pairedDevice by viewModel.pairedDevice.collectAsState()
    val manualHost by viewModel.manualHost.collectAsState()
    val manualPort by viewModel.manualPort.collectAsState()
    var showManualEntry by remember { mutableStateOf(false) }
    var hasNavigated by remember { mutableStateOf(false) }

    // If already paired, navigate to main (once)
    LaunchedEffect(pairedDevice) {
        if (pairedDevice != null && !hasNavigated) {
            hasNavigated = true
            onAlreadyPaired()
        }
    }

    // Start discovery on appear
    LaunchedEffect(Unit) {
        viewModel.startDiscovery()
    }

    // Navigate when device found (once)
    LaunchedEffect(discoveryState) {
        if (discoveryState is ConnectionState.Found && !hasNavigated) {
            hasNavigated = true
            val found = discoveryState as ConnectionState.Found
            onDeviceFound(found.host, found.port, found.name)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("LocalFlow") })
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
                imageVector = Icons.Default.Wifi,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(24.dp))

            when (discoveryState) {
                is ConnectionState.Discovering -> {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Searching for LocalFlow on your network...",
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
                is ConnectionState.Error -> {
                    val error = (discoveryState as ConnectionState.Error).message
                    Text(
                        "Discovery error: $error",
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.startDiscovery() }) {
                        Icon(Icons.Default.Search, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Retry")
                    }
                }
                is ConnectionState.Disconnected -> {
                    Text(
                        "No LocalFlow receiver found",
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.startDiscovery() }) {
                        Icon(Icons.Default.Search, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Search Again")
                    }
                }
                else -> {}
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Manual entry toggle
            OutlinedButton(onClick = { showManualEntry = !showManualEntry }) {
                Icon(Icons.Default.Computer, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Enter IP Manually")
            }

            if (showManualEntry) {
                Spacer(modifier = Modifier.height(16.dp))
                OutlinedTextField(
                    value = manualHost,
                    onValueChange = { viewModel.setManualHost(it) },
                    label = { Text("IP Address") },
                    placeholder = { Text("192.168.1.100") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = manualPort,
                    onValueChange = { viewModel.setManualPort(it) },
                    label = { Text("Port") },
                    singleLine = true,
                    modifier = Modifier.width(120.dp)
                )
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = { viewModel.connectManually() },
                    enabled = manualHost.isNotBlank()
                ) {
                    Text("Connect")
                }
            }
        }
    }
}
