import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  AuthRepository(this._dio) : _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': email, // OAuth2 espera username
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('E-mail ou senha incorretos.');
      }
      throw Exception('Não foi possível conectar ao EcoPulse. Verifique sua conexão e tente novamente.');
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String city,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'city': city,
        },
      );

      if (response.statusCode == 201) {
        // Logar automaticamente após cadastro
        return await login(email, password);
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['detail'] ?? 'Erro no cadastro.');
      }
      throw Exception('Não foi possível conectar ao EcoPulse. Verifique sua conexão e tente novamente.');
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final response = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
