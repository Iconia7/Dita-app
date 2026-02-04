import '../datasources/remote/ai_remote_datasource.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

class AiRepository {
  final AiRemoteDataSource remoteDataSource;

  AiRepository({required this.remoteDataSource});

  Future<Either<Failure, String>> getChatResponse(
    List<Map<String, dynamic>> history,
    String systemInstruction, {
    String? base64File,
    String? mimeType,
  }) async {
    try {
      final response = await remoteDataSource.getChatResponse(
        history, 
        systemInstruction,
        base64File: base64File,
        mimeType: mimeType
      );
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
