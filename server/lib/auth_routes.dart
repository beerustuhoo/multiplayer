import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'config.dart';
import 'encryption.dart';
import 'email_service.dart';
import 'auth_middleware.dart';

class AuthRoutes {
  final DatabaseService db;
  final ServerConfig config;
  late final EncryptionService _encryption;
  late final EmailService _email;
  late final AuthMiddleware _auth;
  final _uuid = const Uuid();

  AuthRoutes(this.db, this.config) {
    _encryption = EncryptionService(config.encryptionKey);
    _email = EmailService(config);
    _auth = AuthMiddleware(config);
  }

  Router get router {
    final r = Router();

    r.post('/register', _register);
    r.post('/login', _login);
    r.post('/firebase-sync', _firebaseSync);
    r.post('/verify-email', _verifyEmail);
    r.get('/verify-email', _verifyEmailGet);
    r.post('/resend-verification', _auth.middleware(_resendVerification));
    r.post('/forgot-password', _forgotPassword);
    r.post('/reset-password', _resetPassword);
    r.get('/me', _auth.middleware(_getMe));

    return r;
  }

  List<String> _validatePassword(String password) {
    final errors = <String>[];
    if (password.length < 8) {
      errors.add('Password must be at least 8 characters');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least 1 lowercase letter');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least 1 uppercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least 1 digit');
    }
    if (!password.contains(RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]'''))) {
      errors.add('Password must contain at least 1 special character');
    }
    return errors;
  }

  String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<Response> _register(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final email = (body['email'] as String?)?.trim();
      final password = body['password'] as String?;
      final username = (body['username'] as String?)?.trim();

      if (email == null || password == null || username == null ||
          email.isEmpty || password.isEmpty || username.isEmpty) {
        return _json(400, {'error': 'Email, password, and username are required'});
      }

      final passwordErrors = _validatePassword(password);
      if (passwordErrors.isNotEmpty) {
        return _json(400, {'error': 'Password too weak', 'details': passwordErrors});
      }

      final emailHash = _encryption.hash(email);
      final existing = db.queryOne(
          'SELECT id FROM users WHERE email_hash = ?', [emailHash]);
      if (existing != null) {
        return _json(409, {'error': 'Email already in use'});
      }

      final usernameHash = _encryption.hash(username);
      final existingUser = db.queryOne(
          'SELECT id FROM users WHERE username_hash = ?', [usernameHash]);
      if (existingUser != null) {
        return _json(409, {'error': 'Username already taken'});
      }

      final id = _uuid.v4();
      final passwordHash = _encryption.hashPassword(password);
      final verificationToken = _generateCode();

      db.execute('''
        INSERT INTO users (id, email_encrypted, email_hash, username_encrypted,
          username_hash, password_hash, verification_token)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        _encryption.encrypt(email),
        emailHash,
        _encryption.encrypt(username),
        usernameHash,
        passwordHash,
        verificationToken,
      ]);

      await _email.sendVerificationEmail(email, verificationToken);

      final token = _auth.generateToken(id, email);

      return _json(201, {
        'message': 'Account created. Please verify your email.',
        'token': token,
        'user': {'id': id, 'username': username, 'email': email, 'emailVerified': false},
      });
    } catch (e) {
      print('Register error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _login(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final email = (body['email'] as String?)?.trim();
      final password = body['password'] as String?;

      if (email == null || password == null || email.isEmpty || password.isEmpty) {
        return _json(400, {'error': 'Email and password are required'});
      }

      final emailHash = _encryption.hash(email);
      final user = db.queryOne(
          'SELECT * FROM users WHERE email_hash = ?', [emailHash]);

      if (user == null) {
        return _json(401, {'error': 'Invalid email or password'});
      }

      if (!_encryption.verifyPassword(password, user['password_hash'] as String)) {
        return _json(401, {'error': 'Invalid email or password'});
      }

      final token = _auth.generateToken(user['id'] as String, email);
      final username = _encryption.decrypt(user['username_encrypted'] as String);

      return _json(200, {
        'token': token,
        'user': {
          'id': user['id'],
          'username': username,
          'email': email,
          'emailVerified': user['email_verified'] == 1,
        },
      });
    } catch (e) {
      print('Login error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _verifyEmail(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final token = body['token'] as String?;

      if (token == null || token.isEmpty) {
        return _json(400, {'error': 'Verification token required'});
      }

      final user = db.queryOne(
          'SELECT * FROM users WHERE verification_token = ?', [token]);
      if (user == null) {
        return _json(400, {'error': 'Invalid verification token'});
      }

      db.execute(
          'UPDATE users SET email_verified = 1, verification_token = NULL WHERE id = ?',
          [user['id']]);

      return _json(200, {'message': 'Email verified successfully'});
    } catch (e) {
      print('Verify email error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _verifyEmailGet(Request request) async {
    final token = request.url.queryParameters['token'];
    if (token == null) {
      return Response.ok('<h2>Invalid verification link</h2>',
          headers: {'Content-Type': 'text/html'});
    }

    final user = db.queryOne(
        'SELECT * FROM users WHERE verification_token = ?', [token]);
    if (user == null) {
      return Response.ok('<h2>Invalid or expired verification link</h2>',
          headers: {'Content-Type': 'text/html'});
    }

    db.execute(
        'UPDATE users SET email_verified = 1, verification_token = NULL WHERE id = ?',
        [user['id']]);

    return Response.ok(
        '<h2>Email verified successfully!</h2><p>You can close this page and return to the app.</p>',
        headers: {'Content-Type': 'text/html'});
  }

  Future<Response> _resendVerification(Request request) async {
    try {
      final userId = request.context['userId'] as String;
      final user = db.queryOne('SELECT * FROM users WHERE id = ?', [userId]);

      if (user == null) return _json(404, {'error': 'User not found'});
      if (user['email_verified'] == 1) {
        return _json(400, {'error': 'Email already verified'});
      }

      final verificationToken = _generateCode();
      db.execute('UPDATE users SET verification_token = ? WHERE id = ?',
          [verificationToken, userId]);

      final email = _encryption.decrypt(user['email_encrypted'] as String);
      await _email.sendVerificationEmail(email, verificationToken);

      return _json(200, {'message': 'Verification email sent'});
    } catch (e) {
      print('Resend verification error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _forgotPassword(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final email = (body['email'] as String?)?.trim();

      if (email == null || email.isEmpty) {
        return _json(400, {'error': 'Email is required'});
      }

      final emailHash = _encryption.hash(email);
      final user = db.queryOne(
          'SELECT * FROM users WHERE email_hash = ?', [emailHash]);

      if (user != null) {
        final resetToken = _generateCode();
        final expires = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;

        db.execute(
            'UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?',
            [resetToken, expires, user['id']]);

        await _email.sendPasswordResetEmail(email, resetToken);
      }

      return _json(200, {'message': 'If the email exists, a reset code has been sent'});
    } catch (e) {
      print('Forgot password error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _resetPassword(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final email = (body['email'] as String?)?.trim();
      final token = body['token'] as String?;
      final newPassword = body['newPassword'] as String?;

      if (email == null || token == null || newPassword == null) {
        return _json(400, {'error': 'Email, token, and new password are required'});
      }

      final passwordErrors = _validatePassword(newPassword);
      if (passwordErrors.isNotEmpty) {
        return _json(400, {'error': 'Password too weak', 'details': passwordErrors});
      }

      final emailHash = _encryption.hash(email);
      final user = db.queryOne(
          'SELECT * FROM users WHERE email_hash = ? AND reset_token = ?',
          [emailHash, token]);

      if (user == null) {
        return _json(400, {'error': 'Invalid reset token'});
      }

      if (DateTime.now().millisecondsSinceEpoch > (user['reset_token_expires'] as int)) {
        return _json(400, {'error': 'Reset token has expired'});
      }

      final passwordHash = _encryption.hashPassword(newPassword);
      db.execute('''
        UPDATE users SET password_hash = ?, reset_token = NULL,
          reset_token_expires = NULL WHERE id = ?
      ''', [passwordHash, user['id']]);

      return _json(200, {'message': 'Password reset successfully'});
    } catch (e) {
      print('Reset password error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _getMe(Request request) async {
    try {
      final userId = request.context['userId'] as String;
      final user = db.queryOne('SELECT * FROM users WHERE id = ?', [userId]);

      if (user == null) return _json(404, {'error': 'User not found'});

      return _json(200, {
        'user': {
          'id': user['id'],
          'username': _encryption.decrypt(user['username_encrypted'] as String),
          'email': _encryption.decrypt(user['email_encrypted'] as String),
          'emailVerified': user['email_verified'] == 1,
        },
      });
    } catch (e) {
      print('Get me error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _firebaseSync(Request request) async {
    try {
      if (config.firebaseWebApiKey.isEmpty) {
        return _json(500, {'error': 'Server missing FIREBASE_WEB_API_KEY'});
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;
      final requestedUsername = (body['username'] as String?)?.trim();
      if (idToken == null || idToken.isEmpty) {
        return _json(400, {'error': 'idToken is required'});
      }

      final firebaseUser = await _lookupFirebaseUser(idToken);
      if (firebaseUser == null) {
        return _json(401, {'error': 'Invalid Firebase token'});
      }

      final email = (firebaseUser['email'] as String?)?.trim();
      final firebaseUid = firebaseUser['localId'] as String?;
      final emailVerified = firebaseUser['emailVerified'] == true;
      if (email == null || firebaseUid == null) {
        return _json(400, {'error': 'Firebase token missing email/localId'});
      }

      final existingByFirebase =
          db.queryOne('SELECT * FROM users WHERE firebase_uid = ?', [firebaseUid]);
      if (existingByFirebase != null) {
        db.execute(
            'UPDATE users SET email_verified = ?, updated_at = datetime(\'now\') WHERE id = ?',
            [emailVerified ? 1 : 0, existingByFirebase['id']]);
        final token = _auth.generateToken(existingByFirebase['id'] as String, email);
        return _json(200, {
          'token': token,
          'user': {
            'id': existingByFirebase['id'],
            'username':
                _encryption.decrypt(existingByFirebase['username_encrypted'] as String),
            'email': email,
            'emailVerified': emailVerified,
          },
        });
      }

      final emailHash = _encryption.hash(email);
      final existingByEmail = db.queryOne('SELECT * FROM users WHERE email_hash = ?', [emailHash]);
      if (existingByEmail != null) {
        db.execute(
            'UPDATE users SET firebase_uid = ?, email_verified = ?, updated_at = datetime(\'now\') WHERE id = ?',
            [firebaseUid, emailVerified ? 1 : 0, existingByEmail['id']]);
        final token = _auth.generateToken(existingByEmail['id'] as String, email);
        return _json(200, {
          'token': token,
          'user': {
            'id': existingByEmail['id'],
            'username':
                _encryption.decrypt(existingByEmail['username_encrypted'] as String),
            'email': email,
            'emailVerified': emailVerified,
          },
        });
      }

      if (requestedUsername == null || requestedUsername.isEmpty) {
        return _json(409, {'error': 'Username required for first sign in'});
      }
      final usernameHash = _encryption.hash(requestedUsername);
      final existingByUsername =
          db.queryOne('SELECT id FROM users WHERE username_hash = ?', [usernameHash]);
      if (existingByUsername != null) {
        return _json(409, {'error': 'Username already taken'});
      }

      final id = _uuid.v4();
      db.execute('''
        INSERT INTO users (id, firebase_uid, email_encrypted, email_hash, username_encrypted,
          username_hash, password_hash, email_verified)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        firebaseUid,
        _encryption.encrypt(email),
        emailHash,
        _encryption.encrypt(requestedUsername),
        usernameHash,
        'firebase_auth',
        emailVerified ? 1 : 0,
      ]);

      final token = _auth.generateToken(id, email);
      return _json(201, {
        'token': token,
        'user': {
          'id': id,
          'username': requestedUsername,
          'email': email,
          'emailVerified': emailVerified,
        },
      });
    } catch (e) {
      print('Firebase sync error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Map<String, dynamic>?> _lookupFirebaseUser(String idToken) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${config.firebaseWebApiKey}');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'idToken': idToken}));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(body) as Map<String, dynamic>;
      final users = data['users'] as List?;
      if (users == null || users.isEmpty) return null;
      return users.first as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Response _json(int statusCode, Map<String, dynamic> body) {
    return Response(statusCode,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }
}
