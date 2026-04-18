package com.localflow.ui.main

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.localflow.model.ConnectionState
import com.localflow.model.RecordingState
import com.localflow.model.UploadResult

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(viewModel: MainViewModel) {
    val connectionState by viewModel.connectionState.collectAsState()
    val recordingState by viewModel.recordingState.collectAsState()
    val uploadState by viewModel.uploadState.collectAsState()
    val recordingDuration by viewModel.recordingDuration.collectAsState()
    val haptic = LocalHapticFeedback.current
    var showMenu by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.startRecording()
    }

    val isConnected = connectionState is ConnectionState.Connected
    val isRecording = recordingState is RecordingState.Recording

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("LocalFlow") },
                actions = {
                    // Connection indicator
                    Icon(
                        imageVector = if (isConnected) Icons.Default.Wifi else Icons.Default.WifiOff,
                        contentDescription = "Connection status",
                        tint = if (isConnected) MaterialTheme.colorScheme.primary
                               else MaterialTheme.colorScheme.error
                    )
                    IconButton(onClick = { showMenu = true }) {
                        Icon(Icons.Default.MoreVert, contentDescription = "Menu")
                    }
                    DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("Refresh Connection") },
                            onClick = {
                                viewModel.refreshConnection()
                                showMenu = false
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Unpair") },
                            onClick = {
                                viewModel.unpair()
                                showMenu = false
                            }
                        )
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Connection status
            if (connectionState is ConnectionState.Connected) {
                val device = (connectionState as ConnectionState.Connected).device
                Text(
                    "Connected to ${device.serverName}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else if (connectionState is ConnectionState.Error) {
                val error = (connectionState as ConnectionState.Error).message
                Text(
                    error,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error
                )
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Record button
            RecordButton(
                isRecording = isRecording,
                isConnected = isConnected,
                onClick = {
                    if (isRecording) {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        viewModel.stopRecording()
                    } else {
                        if (viewModel.hasRecordPermission()) {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            viewModel.startRecording()
                        } else {
                            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    }
                }
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Duration or status
            if (isRecording) {
                Text(
                    formatDuration(recordingDuration),
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.error
                )
            } else {
                Text(
                    if (isConnected) "Tap to record" else "Not connected",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Upload status
            UploadStatusCard(uploadState)
        }
    }
}

@Composable
private fun RecordButton(
    isRecording: Boolean,
    isConnected: Boolean,
    onClick: () -> Unit
) {
    val pulseAnim = rememberInfiniteTransition(label = "pulse")
    val scale by pulseAnim.animateFloat(
        initialValue = 1f,
        targetValue = if (isRecording) 1.15f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    val buttonColor by animateColorAsState(
        targetValue = when {
            isRecording -> MaterialTheme.colorScheme.error
            isConnected -> MaterialTheme.colorScheme.primary
            else -> MaterialTheme.colorScheme.surfaceVariant
        },
        label = "buttonColor"
    )

    Box(
        modifier = Modifier
            .size(120.dp)
            .scale(if (isRecording) scale else 1f)
            .clip(CircleShape)
            .background(buttonColor)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                enabled = isConnected,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (isRecording) Icons.Default.Stop else Icons.Default.Mic,
            contentDescription = if (isRecording) "Stop recording" else "Start recording",
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onPrimary
        )
    }
}

@Composable
private fun UploadStatusCard(uploadState: UploadResult) {
    when (uploadState) {
        is UploadResult.Idle -> {}
        is UploadResult.Uploading -> {
            Card(modifier = Modifier.padding(horizontal = 24.dp)) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Uploading...")
                }
            }
        }
        is UploadResult.Success -> {
            Card(
                modifier = Modifier.padding(horizontal = 24.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Delivered", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        is UploadResult.Failure -> {
            Card(
                modifier = Modifier.padding(horizontal = 24.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Error,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text("Transfer failed", style = MaterialTheme.typography.bodyLarge)
                    }
                    Text(
                        uploadState.message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onErrorContainer
                    )
                }
            }
        }
        is UploadResult.Queued -> {
            Card(modifier = Modifier.padding(horizontal = 24.dp)) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Schedule, contentDescription = null)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Queued — will retry when connected")
                }
            }
        }
    }
}

private fun formatDuration(ms: Long): String {
    val seconds = (ms / 1000) % 60
    val minutes = (ms / 1000) / 60
    return "%d:%02d".format(minutes, seconds)
}
