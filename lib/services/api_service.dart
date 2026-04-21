import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class ApiService {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─── AUTH ────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(
      String email, String password, String username) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/register'),
      headers: _headers,
      body: jsonEncode(
          {'email': email, 'password': password, 'username': username}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> firebaseSync(String idToken, {String? username}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/firebase-sync'),
      headers: _headers,
      body: jsonEncode({
        'idToken': idToken,
        if (username != null && username.isNotEmpty) 'username': username,
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmail(String code) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/verify-email'),
      headers: _headers,
      body: jsonEncode({'token': code}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resendVerification() async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/resend-verification'),
      headers: _headers,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resetPassword(
      String email, String token, String newPassword) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiUrl}/auth/reset-password'),
      headers: _headers,
      body: jsonEncode(
          {'email': email, 'token': token, 'newPassword': newPassword}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('${AppConstants.apiUrl}/auth/me'),
      headers: _headers,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── USERS ───────────────────────────────────────────────

  Future<List<dynamic>> searchUsers(String query) async {
    final res = await http.get(
      Uri.parse('${AppConstants.apiUrl}/users/search?query=$query'),
      headers: _headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['users'] as List?) ?? [];
  }

  // ─── GAMES ───────────────────────────────────────────────

  Future<List<dynamic>> getGames() async {
    final res = await http.get(
      Uri.parse('${AppConstants.apiUrl}/games'),
      headers: _headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['games'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> getGame(String gameId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.apiUrl}/games/$gameId'),
      headers: _headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['game'] is Map<String, dynamic>) {
      return data['game'] as Map<String, dynamic>;
    }
    throw Exception('Game not found');
  }
}
