import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:article_pulse/models/article.dart';
import 'package:article_pulse/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService(
        customFactory: databaseFactoryFfi,
        dbName: inMemoryDatabasePath,
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Insert articles, retrieve cached, and deduplicate', () async {
      final article1 = Article(
        id: Article.generateId('https://example.com/article1'),
        title: 'Exploring Quantum Computing',
        description: 'An overview of quantum algorithms.',
        url: 'https://example.com/article1',
        author: 'Dr. Alice Smith',
        sourceName: 'Quantum Daily',
        publishedAt: DateTime(2025, 6, 15),
        discoveredAt: DateTime.now(),
        category: 'Science',
      );

      final article2 = Article(
        id: Article.generateId('https://example.com/article2'),
        title: 'Deep Learning in 2026',
        description: 'Advancements in transformer models.',
        url: 'https://example.com/article2',
        author: 'Bob Vance',
        sourceName: 'AI Journal',
        publishedAt: DateTime(2026, 1, 10),
        discoveredAt: DateTime.now(),
        category: 'Artificial Intelligence',
      );

      await dbService.saveArticles([article1, article2]);

      final cached = await dbService.getCachedArticles();
      expect(cached.length, 2);
      expect(cached.first.title, 'Deep Learning in 2026'); // newest first

      // Test category filter
      final scienceOnly = await dbService.getCachedArticles(category: 'Science');
      expect(scienceOnly.length, 1);
      expect(scienceOnly.first.title, 'Exploring Quantum Computing');
    });

    test('Bookmark toggle and query', () async {
      final article = Article(
        id: Article.generateId('https://example.com/bookmark-test'),
        title: 'History of Mars Rovers',
        description: 'A timeline of space exploration.',
        url: 'https://example.com/bookmark-test',
        sourceName: 'Space Exploration Review',
        publishedAt: DateTime(2024, 11, 20),
        discoveredAt: DateTime.now(),
        category: 'History',
      );

      await dbService.saveArticles([article]);

      expect(await dbService.isArticleBookmarked(article.id), isFalse);

      // Toggle ON
      final bookmarked = await dbService.toggleBookmark(article);
      expect(bookmarked, isTrue);
      expect(await dbService.isArticleBookmarked(article.id), isTrue);

      final saved = await dbService.getBookmarks();
      expect(saved.length, 1);
      expect(saved.first.title, 'History of Mars Rovers');
      expect(saved.first.isBookmarked, isTrue);

      // Toggle OFF
      final unbookmarked = await dbService.toggleBookmark(article);
      expect(unbookmarked, isFalse);
      expect(await dbService.isArticleBookmarked(article.id), isFalse);
    });

    test('Reading history tracking', () async {
      final article = Article(
        id: Article.generateId('https://example.com/history-test'),
        title: 'Psychology of Focus',
        description: 'Deep work habits.',
        url: 'https://example.com/history-test',
        sourceName: 'Mind & Behavior',
        publishedAt: DateTime(2025, 4, 12),
        discoveredAt: DateTime.now(),
        category: 'Psychology',
      );

      await dbService.recordReadingHistory(article);

      final history = await dbService.getReadingHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Psychology of Focus');

      await dbService.clearReadingHistory();
      final cleared = await dbService.getReadingHistory();
      expect(cleared.isEmpty, isTrue);
    });

    test('Article impressions to prevent repetitive recommendations', () async {
      const id1 = 'id_alpha';
      const id2 = 'id_beta';

      await dbService.recordImpressions([id1, id2], 'home_feed');

      final impressionIds = await dbService.getRecentImpressionIds(
        window: const Duration(hours: 1),
      );

      expect(impressionIds.contains(id1), isTrue);
      expect(impressionIds.contains(id2), isTrue);
      expect(impressionIds.contains('id_gamma'), isFalse);
    });
  });
}
