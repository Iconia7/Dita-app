import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/network/network_info.dart';

/// Connectivity provider (base)
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// Network info provider
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return NetworkInfo(connectivity);
});

/// Connectivity status provider (Stream)
final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  return ref.watch(networkInfoProvider).onConnectivityChanged;
});

/// Is online provider (Boolean)
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).value;
  // If status is loading, assume online for now or check current status
  if (status == null) return true; 
  return status != ConnectivityResult.none;
});
