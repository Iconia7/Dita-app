import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dita_app/core/errors/exceptions.dart';
import 'package:dita_app/core/errors/failures.dart';
import 'package:dita_app/core/network/network_info.dart';
import 'package:dita_app/core/utils/either.dart';
import 'package:dita_app/data/datasources/local/user_local_datasource.dart';
import 'package:dita_app/data/datasources/remote/user_remote_datasource.dart';
import 'package:dita_app/data/models/user_model.dart';
import 'package:dita_app/utils/app_logger.dart';

/// User Repository
/// Implements offline-first pattern:
/// 1. Check network connectivity
/// 2. If online: fetch from remote, cache locally
/// 3. If offline: return cached data
/// 4. Handle errors with Either<Failure, Data>
class UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  UserRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Login user
  /// Always requires network (no cached login)
  Future<Either<Failure, UserModel>> login(
    String username,
    String password,
  ) async {
    try {
      // Login always requires network
      if (!await networkInfo.isConnected) {
        AppLogger.warning('Cannot login while offline');
        return const Either.left(NetworkFailure('No internet connection'));
      }

      // Attempt login
      final user = await remoteDataSource.login(username, password);

      // Cache user data and tokens
      await localDataSource.cacheUser(user);
      if (user.accessToken != null) {
        await localDataSource.saveAccessToken(user.accessToken!);
      }
      if (user.refreshToken != null) {
        await localDataSource.saveRefreshToken(user.refreshToken!);
      }

      AppLogger.success('Login successful, user cached');
      return Either.right(user);
    } on AuthenticationException catch (e) {
      AppLogger.warning('Authentication failed: ${e.message}');
      return Either.left(AuthFailure(e.message));
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected login error', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Login failed'));
    }
  }

  /// Get current user (from cache)
  Future<Either<Failure, UserModel?>> getCurrentUser() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      
      if (cachedUser == null) {
        AppLogger.debug('No current user in cache');
        return const Either.right(null);
      }

      // Try to refresh user data if online
      if (await networkInfo.isConnected) {
        try {
          final freshUser = await remoteDataSource.getUserProfile(cachedUser.id);
          await localDataSource.cacheUser(freshUser);
          AppLogger.info('User data refreshed from server');
          return Either.right(freshUser);
        } catch (e) {
          // If refresh fails, return cached data
          AppLogger.debug('Failed to refresh user, using cache');
        }
      }

      return Either.right(cachedUser);
    } on CacheException {
      return const Either.left(CacheFailure());
    } catch (e, stackTrace) {
      AppLogger.error('Error getting current user', 
        error: e, stackTrace: stackTrace);
      return const Either.left(CacheFailure('Failed to get user'));
    }
  }

  /// Get user profile (with offline-first)
  Future<Either<Failure, UserModel>> getUserProfile(int userId) async {
    try {
      // Try to get cached user first
      final cachedUser = await localDataSource.getCachedUser();

      if (await networkInfo.isConnected) {
        try {
          // Fetch from remote
          final user = await remoteDataSource.getUserProfile(userId);
          
          // Cache the result
          await localDataSource.cacheUser(user);
          
          return Either.right(user);
        } on NetworkException {
          // If network fails but we have cache, return cache
          if (cachedUser != null && cachedUser.id == userId) {
            AppLogger.info('Network error, using cached user profile');
            return Either.right(cachedUser);
          }
          return const Either.left(NetworkFailure());
        } on TimeoutException {
          if (cachedUser != null && cachedUser.id == userId) {
            AppLogger.info('Request timeout, using cached user profile');
            return Either.right(cachedUser);
          }
          return const Either.left(TimeoutFailure());
        }
      } else {
        // Offline mode
        if (cachedUser != null && cachedUser.id == userId) {
          AppLogger.info('Offline mode, using cached user profile');
          return Either.right(cachedUser);
        }
        return const Either.left(
          NetworkFailure('No internet and no cached data'),
        );
      }
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error getting user profile', 
        error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to get user profile'));
    }
  }

  /// Update user
  Future<Either<Failure, UserModel>> updateUser(
    int userId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(
          NetworkFailure('Cannot update user while offline'),
        );
      }

      final user = await remoteDataSource.updateUser(userId, data);
      
      // Cache updated user
      await localDataSource.cacheUser(user);
      
      return Either.right(user);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error updating user', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to update user'));
    }
  }

  /// Register new user
  Future<Either<Failure, UserModel>> registerUser(
    Map<String, dynamic> registrationData,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(
          NetworkFailure('Cannot register while offline'),
        );
      }

      final user = await remoteDataSource.registerUser(registrationData);
      
      // Cache registered user
      await localDataSource.cacheUser(user);
      if (user.accessToken != null) {
        await localDataSource.saveAccessToken(user.accessToken!);
      }
      if (user.refreshToken != null) {
        await localDataSource.saveRefreshToken(user.refreshToken!);
      }
      
      return Either.right(user);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } on ValidationException catch (e) {
      return Either.left(ValidationFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error registering user', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Registration failed'));
    }
  }

  /// Logout user (clear cache)
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearCache();
      AppLogger.info('User logged out successfully');
      return const Either.right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error logging out', error: e, stackTrace: stackTrace);
      return const Either.left(CacheFailure('Failed to logout'));
    }
  }

  /// Change password (online only)
  Future<Either<Failure, bool>> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(NetworkFailure('Cannot change password while offline'));
      }

      await remoteDataSource.changePassword(userId, oldPassword, newPassword);
      return const Either.right(true);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error changing password', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to change password'));
    }
  }

  /// Initiate M-Pesa payment (online only)
  Future<Either<Failure, bool>> initiatePayment(
    String phoneNumber,
    int userId,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(NetworkFailure('Cannot pay while offline'));
      }

      final success = await remoteDataSource.initiatePayment(phoneNumber, userId);
      return Either.right(success);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error initiating payment', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to initiate payment'));
    }
  }

  /// Upload profile picture (online only)
  Future<Either<Failure, bool>> uploadProfilePicture(int userId, File imageFile) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(NetworkFailure('Cannot upload while offline'));
      }

      final success = await remoteDataSource.uploadProfilePicture(userId, imageFile);
      return Either.right(success);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading picture', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to upload picture'));
    }
  }

  /// Update FCM token (online only)
  Future<Either<Failure, bool>> updateFcmToken(int userId, String token) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Either.left(NetworkFailure('Cannot sync token while offline'));
      }

      final success = await remoteDataSource.updateFcmToken(userId, token);
      return Either.right(success);
    } on NetworkException {
      return const Either.left(NetworkFailure());
    } on TimeoutException {
      return const Either.left(TimeoutFailure());
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('Error syncing FCM token', error: e, stackTrace: stackTrace);
      return const Either.left(UnknownFailure('Failed to sync token'));
    }
  }
}
