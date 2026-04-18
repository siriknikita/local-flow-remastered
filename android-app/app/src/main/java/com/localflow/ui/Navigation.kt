package com.localflow.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.localflow.model.ConnectionState
import com.localflow.ui.discovery.DiscoveryScreen
import com.localflow.ui.discovery.DiscoveryViewModel
import com.localflow.ui.main.MainScreen
import com.localflow.ui.main.MainViewModel
import com.localflow.ui.pairing.PairingScreen
import com.localflow.ui.pairing.PairingViewModel

@Composable
fun LocalFlowNavigation() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = "discovery") {
        composable("discovery") {
            val viewModel: DiscoveryViewModel = hiltViewModel()
            DiscoveryScreen(
                viewModel = viewModel,
                onDeviceFound = { host, port, name ->
                    navController.navigate("pairing/$host/$port/$name") {
                        launchSingleTop = true
                    }
                },
                onAlreadyPaired = {
                    navController.navigate("main") {
                        popUpTo("discovery") { inclusive = true }
                        launchSingleTop = true
                    }
                }
            )
        }

        composable("pairing/{host}/{port}/{name}") { backStackEntry ->
            val host = backStackEntry.arguments?.getString("host") ?: return@composable
            val port = backStackEntry.arguments?.getString("port")?.toIntOrNull() ?: return@composable
            val name = backStackEntry.arguments?.getString("name") ?: return@composable

            val viewModel: PairingViewModel = hiltViewModel()
            PairingScreen(
                viewModel = viewModel,
                host = host,
                port = port,
                serverName = name,
                onPaired = {
                    navController.navigate("main") {
                        popUpTo("discovery") { inclusive = true }
                        launchSingleTop = true
                    }
                }
            )
        }

        composable("main") {
            val viewModel: MainViewModel = hiltViewModel()
            MainScreen(
                viewModel = viewModel,
                onUnpaired = {
                    navController.navigate("discovery") {
                        popUpTo("main") { inclusive = true }
                        launchSingleTop = true
                    }
                }
            )
        }
    }
}
