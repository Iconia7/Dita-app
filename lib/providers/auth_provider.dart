import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/core/network/network_info.dart';
import 'package:dita_app/data/datasources/local/user_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/user_remote_datasource.dart';
import 'package:dita_app/data/repositories/user_repository.dart';
import 'package:dita_app/data/models/user_model.dart';
import 'package:dita_app/utils/app_logger.dart';

// ========== Dependency Injection Providers ==========

import 'package:dita_app/providers/network_provider.dart';

/// User local data source provider
final userLocalDataSourceProvider = Provider<UserLocalDataSource>((ref) {
  return UserLocalDataSource();
});

/// User remote data source provider
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource();
});

/// User repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    remoteDataSource: ref.watch(userRemoteDataSourceProvider),
    localDataSource: ref.watch(userLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ========== State Providers ==========

/// Authentication state provider
/// Manages current user state
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final UserRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadCurrentUser();
  }

  /// Load current user from cache
  Future<void> _loadCurrentUser() async {
    try {
      AppLogger.info('Loading current user...');
      
      final result = await _repository.getCurrentUser();
      
      result.fold(
        (failure) {
          AppLogger.warning('Failed to load user: ${failure.message}');
          state = const AsyncValue.data(null);
        },
        (user) {
          if (user != null) {
            AppLogger.success('User loaded: ${user.username}');
            state = AsyncValue.data(user);
          } else {
            AppLogger.info('No user logged in');
            state = const AsyncValue.data(null);
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error loading user', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Login
  Future<bool> login(String username, String password) async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Attempting login...');

      final result = await _repository.login(username, password);

      return result.fold(
        (failure) {
          AppLogger.warning('Login failed: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
          return false;
        },
        (user) {
          AppLogger.success('Login successful: ${user.username}');
          state = AsyncValue.data(user);
          return true;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Login error', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Register new user
  Future<bool> register(Map<String, dynamic> data) async {
    try {
      state = const AsyncValue.loading();
      AppLogger.info('Attempting registration...');

      final result = await _repository.registerUser(data);

      return result.fold(
        (failure) {
          AppLogger.warning('Registration failed: ${failure.message}');
          state = AsyncValue.error(failure.message, StackTrace.current);
          return false;
        },
        (user) {
          AppLogger.success('Registration successful: ${user.username}');
          state = AsyncValue.data(user);
          return true;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Registration error', error: e, stackTrace: stackTrace);
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      AppLogger.info('Logging out...');
      
      await _repository.logout();
      
      state = const AsyncValue.data(null);
      AppLogger.success('Logout successful');
    } catch (e, stackTrace) {
      AppLogger.error('Logout error', error: e, stackTrace: stackTrace);
      // Still clear state even if cache clear fails
      state = const AsyncValue.data(null);
    }
  }

  /// Update user
  Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      AppLogger.info('Updating user...');
      
      final result = await _repository.updateUser(userId, data);

      return result.fold(
        (failure) {
          AppLogger.warning('Update failed: ${failure.message}');
          return false;
        },
        (user) {
          AppLogger.success('User updated: ${user.username}');
          state = AsyncValue.data(user);
          return true;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Update error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Refresh current user
  Future<void> refresh() async {
    await _loadCurrentUser();
  }

  /// Initiate M-Pesa payment
  Future<bool> initiatePayment(String phoneNumber) async {
    final user = state.value;
    if (user == null) return false;

    final result = await _repository.initiatePayment(phoneNumber, user.id);
    return result.fold(
      (failure) {
        AppLogger.warning('Payment initiation failed: ${failure.message}');
        return false;
      },
      (success) => success,
    );
  }

  /// Change password
  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    try {
      AppLogger.info('Changing password...');
      final result = await _repository.changePassword(userId, oldPassword, newPassword);
      
      return result.fold(
        (failure) {
          AppLogger.error('Change password failed: ${failure.message}');
          return false;
        },
        (success) {
          AppLogger.success('Password changed');
          return success;
        },
      );
    } catch (e) {
      AppLogger.error('Change password error', error: e);
      return false;
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(File file) async {
    final user = state.value;
    if (user == null) return false;

    final result = await _repository.uploadProfilePicture(user.id, file);
    return result.fold(
      (failure) {
        AppLogger.warning('Upload failed: ${failure.message}');
        return false;
      },
      (success) async {
        if (success) {
          await refresh(); // Refresh to get new URL
        }
        return success;
      },
    );
  }

  /// Update FCM token
  Future<void> updateFcmToken(String token) async {
    final user = state.value;
    if (user == null) return;

    final result = await _repository.updateFcmToken(user.id, token);
    result.fold(
      (failure) => AppLogger.warning('FCM update failed: ${failure.message}'),
      (success) => AppLogger.success('FCM sync complete'),
    );
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return AuthNotifier(repository);
});

/// Helper provider to check if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Helper provider to get current user (null-safe)
final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});
