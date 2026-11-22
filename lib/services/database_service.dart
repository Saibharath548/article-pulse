import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/article.dart';

/// Database service managing SQLite local persistence for Article Pulse.
/// Handles offline caching, saved bookmarks, reading history, and impression tracking.
class DatabaseService {
  static const String defaultDbName = 'article_pulse.db';
  static const int _dbVersion = 1;

  final String _dbName;
  Database? _db;
  final DatabaseFactory? _customFactory;

  DatabaseService({
    DatabaseFactory? customFactory,
    String dbName = defaultDbName,
  })  : _customFactory = customFactory,
        _dbName = dbName;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final factory = _customFactory ?? databaseFactory;
    final path = _dbName == inMemoryDatabasePath
        ? inMemoryDatabasePath
        : join(await factory.getDatabasesPath(), _dbName);

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Articles Cache table
    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        url TEXT NOT NULL,
        author TEXT,
        source_name TEXT NOT NULL,
        published_at TEXT NOT NULL,
        discovered_at TEXT NOT NULL,
        category TEXT NOT NULL,
        discovery_type TEXT NOT NULL DEFAULT 'recent',
        is_bookmarked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_articles_category ON articles(category)');
    await db.execute('CREATE INDEX idx_articles_published_at ON articles(published_at)');
    await db.execute('CREATE INDEX idx_articles_discovered_at ON articles(discovered_at)');

    // 2. Bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        article_id TEXT PRIMARY KEY,
        saved_at TEXT NOT NULL,
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
      )
    ''');

    // 3. Reading History table
    await db.execute('''
      CREATE TABLE reading_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        article_id TEXT NOT NULL,
        opened_at TEXT NOT NULL,
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_history_opened_at ON reading_history(opened_at DESC)');

    // 4. Impressions table (to avoid repetitive recommendations on home feed)
    await db.execute('''
      CREATE TABLE article_impressions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        article_id TEXT NOT NULL,
        section TEXT NOT NULL,
        shown_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_impressions_shown_at ON article_impressions(shown_at DESC)');
    await db.execute('CREATE INDEX idx_impressions_article ON article_impressions(article_id)');
  }

  /// Inserts or updates articles in the local cache. Preserves bookmark status.
  Future<void> saveArticles(List<Article> articles) async {
    if (articles.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final article in articles) {
      batch.rawInsert('''
        INSERT INTO articles (
          id, title, description, url, author, source_name,
          published_at, discovered_at, category, discovery_type, is_bookmarked
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          url = excluded.url,
          author = COALESCE(excluded.author, articles.author),
          source_name = excluded.source_name,
          published_at = excluded.published_at,
          category = excluded.category,
          discovery_type = excluded.discovery_type
      ''', [
        article.id,
        article.title,
        article.description,
        article.url,
        article.author,
        article.sourceName,
        article.publishedAt.toIso8601String(),
        article.discoveredAt.toIso8601String(),
        article.category,
        article.discoveryType,
        article.isBookmarked ? 1 : 0,
      ]);
    }

    await batch.commit(noResult: true);
  }

  /// Retrieves cached articles with optional filters.
  Future<List<Article>> getCachedArticles({
    String? category,
    String? discoveryType,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
    bool orderByNewest = true,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (discoveryType != null && discoveryType.isNotEmpty) {
      whereClauses.add('discovery_type = ?');
      whereArgs.add(discoveryType);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR description LIKE ? OR source_name LIKE ? OR author LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term, term]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final order = orderByNewest ? 'published_at DESC' : 'published_at ASC';

    final maps = await db.query(
      'articles',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: order,
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => Article.fromMap(m)).toList();
  }

  /// Retrieves a single article by ID.
  Future<Article?> getArticleById(String id) async {
    final db = await database;
    final maps = await db.query('articles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Article.fromMap(maps.first);
  }

  /// Toggles bookmark state for an article.
  Future<bool> toggleBookmark(Article article) async {
    final db = await database;
    final existing = await db.query('bookmarks', where: 'article_id = ?', whereArgs: [article.id]);

    if (existing.isNotEmpty) {
      await db.delete('bookmarks', where: 'article_id = ?', whereArgs: [article.id]);
      await db.update('articles', {'is_bookmarked': 0}, where: 'id = ?', whereArgs: [article.id]);
      return false;
    } else {
      // Ensure article exists in articles table
      await saveArticles([article.copyWith(isBookmarked: true)]);
      await db.insert('bookmarks', {
        'article_id': article.id,
        'saved_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.update('articles', {'is_bookmarked': 1}, where: 'id = ?', whereArgs: [article.id]);
      return true;
    }
  }

  /// Checks if an article is bookmarked.
  Future<bool> isArticleBookmarked(String id) async {
    final db = await database;
    final maps = await db.query('bookmarks', where: 'article_id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty;
  }

  /// Retrieves all bookmarked articles, ordered by save time descending.
  Future<List<Article>> getBookmarks({int limit = 50, int offset = 0, String? searchQuery}) async {
    final db = await database;
    String sql = '''
      SELECT a.* FROM articles a
      INNER JOIN bookmarks b ON a.id = b.article_id
    ''';
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql += ' WHERE (a.title LIKE ? OR a.description LIKE ? OR a.source_name LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    sql += ' ORDER BY b.saved_at DESC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => Article.fromMap(m).copyWith(isBookmarked: true)).toList();
  }

  /// Records reading history when an article is opened.
  Future<void> recordReadingHistory(Article article) async {
    final db = await database;
    // Save/update article in cache
    await saveArticles([article]);

    await db.insert('reading_history', {
      'article_id': article.id,
      'opened_at': DateTime.now().toIso8601String(),
    });
  }

  /// Retrieves reading history articles ordered by read time descending.
  Future<List<Article>> getReadingHistory({int limit = 50, int offset = 0}) async {
    final db = await database;
    const sql = '''
      SELECT a.*, MAX(h.opened_at) as last_opened FROM articles a
      INNER JOIN reading_history h ON a.id = h.article_id
      GROUP BY a.id
      ORDER BY last_opened DESC
      LIMIT ? OFFSET ?
    ''';

    final maps = await db.rawQuery(sql, [limit, offset]);
    return maps.map((m) => Article.fromMap(m)).toList();
  }

  /// Clears all reading history.
  Future<void> clearReadingHistory() async {
    final db = await database;
    await db.delete('reading_history');
  }

  /// Records article impressions to avoid repeating recent recommendations.
  Future<void> recordImpressions(List<String> articleIds, String section) async {
    if (articleIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    for (final id in articleIds) {
      batch.insert('article_impressions', {
        'article_id': id,
        'section': section,
        'shown_at': now,
      });
    }

    await batch.commit(noResult: true);
  }

  /// Returns IDs of articles shown within the last [window] (e.g. past 48 hours).
  Future<Set<String>> getRecentImpressionIds({Duration window = const Duration(hours: 48)}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(window).toIso8601String();

    final maps = await db.query(
      'article_impressions',
      columns: ['article_id'],
      where: 'shown_at >= ?',
      whereArgs: [cutoff],
      distinct: true,
    );

    return maps.map((m) => m['article_id'] as String).toSet();
  }

  /// Cleans up older impressions beyond 14 days.
  Future<void> pruneOldImpressions() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
    await db.delete('article_impressions', where: 'shown_at < ?', whereArgs: [cutoff]);
  }

  /// Clears cache (except bookmarks).
  Future<void> clearNonBookmarkedCache() async {
    final db = await database;
    await db.delete(
      'articles',
      where: 'id NOT IN (SELECT article_id FROM bookmarks)',
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
