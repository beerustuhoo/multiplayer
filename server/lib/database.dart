import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class DatabaseService {
  final String dbPath;
  late Database _db;

  DatabaseService(this.dbPath);

  Database get db => _db;

  void initialize() {
    final dir = Directory(dbPath).parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    _db = sqlite3.open(dbPath);
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA foreign_keys = ON');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        firebase_uid TEXT UNIQUE,
        email_encrypted TEXT NOT NULL,
        email_hash TEXT NOT NULL UNIQUE,
        username_encrypted TEXT NOT NULL,
        username_hash TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        email_verified INTEGER DEFAULT 0,
        verification_token TEXT,
        reset_token TEXT,
        reset_token_expires INTEGER,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    _ensureColumn('users', 'firebase_uid', 'TEXT');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS games (
        id TEXT PRIMARY KEY,
        player_x TEXT NOT NULL,
        player_o TEXT NOT NULL,
        board TEXT DEFAULT '["","","","","","","","",""]',
        current_turn TEXT DEFAULT 'X',
        status TEXT DEFAULT 'playing',
        winner TEXT,
        timer_x INTEGER DEFAULT 300000,
        timer_o INTEGER DEFAULT 300000,
        time_control INTEGER DEFAULT 300000,
        last_move_time INTEGER,
        moves TEXT DEFAULT '[]',
        paused INTEGER DEFAULT 0,
        pause_reason TEXT,
        pause_start INTEGER,
        restart_requested_by TEXT,
        restart_requested_at INTEGER,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (player_x) REFERENCES users(id),
        FOREIGN KEY (player_o) REFERENCES users(id)
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS invites (
        id TEXT PRIMARY KEY,
        from_user TEXT NOT NULL,
        to_user TEXT NOT NULL,
        time_control INTEGER DEFAULT 300000,
        status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (from_user) REFERENCES users(id),
        FOREIGN KEY (to_user) REFERENCES users(id)
      )
    ''');

    print('Database initialized at $dbPath');
  }

  void _ensureColumn(String table, String column, String typeSql) {
    try {
      _db.execute('ALTER TABLE $table ADD COLUMN $column $typeSql');
    } catch (_) {
      // Column already exists.
    }
  }

  Map<String, dynamic>? queryOne(String sql, [List<Object?> params = const []]) {
    final result = _db.select(sql, params);
    if (result.isEmpty) return null;
    return Map<String, dynamic>.from(result.first);
  }

  List<Map<String, dynamic>> queryAll(String sql, [List<Object?> params = const []]) {
    final result = _db.select(sql, params);
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void execute(String sql, [List<Object?> params = const []]) {
    final stmt = _db.prepare(sql);
    stmt.execute(params);
    stmt.dispose();
  }
}
