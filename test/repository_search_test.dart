import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:article_pulse/models/article.dart';
import 'package:article_pulse/models/category.dart';
import 'package:article_pulse/repositories/article_repository.dart';
import 'package:article_pulse/services/database_service.dart';
import 'package:article_pulse/services/providers/search_provider_interface.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ArticleRepository & Search Routing Tests', () {
    late DatabaseService dbService;
    late ArticleRepository repository;

    setUp(() {
      dbService = DatabaseService(
        customFactory: databaseFactoryFfi,
        dbName: inMemoryDatabasePath,
      );
      repository = ArticleRepository(
        dbService: dbService,
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Historical filter covers at least two years back (2024 to 2026)', () {
      final now = DateTime(2026, 11, 22);
      final twoYearsAgo = now.subtract(const Duration(days: 730));

      final filter = ArticleSearchFilter(
        query: 'quantum computing',
        fromDate: twoYearsAgo,
        toDate: now,
        sortByNewest: true,
      );

      expect(filter.fromDate!.year, 2024);
      expect(filter.toDate!.year, 2026);
      expect(filter.sortByNewest, isTrue);
    });

    test('Category definition contains all 11 required initial topics', () {
      final categories = ArticleCategory.initialCategories;
      expect(categories.length, 11);

      final names = categories.map((c) => c.name).toSet();
      expect(names.contains('Game Development'), isTrue);
      expect(names.contains('Technology'), isTrue);
      expect(names.contains('Science'), isTrue);
      expect(names.contains('Psychology'), isTrue);
      expect(names.contains('Government and Politics'), isTrue);
      expect(names.contains('Society and Social Issues'), isTrue);
      expect(names.contains('History'), isTrue);
      expect(names.contains('Business and Economics'), isTrue);
      expect(names.contains('Artificial Intelligence'), isTrue);
      expect(names.contains('Environment'), isTrue);
      expect(names.contains('General Knowledge'), isTrue);
    });

    test('Article model preserves publisher attribution and generates deterministic ID', () {
      const url = 'https://arstechnica.com/science/2025/08/new-particle/';
      const title = 'Particle Physics Milestone';

      final id1 = Article.generateId(url, title);
      final id2 = Article.generateId(url, title);
      expect(id1, id2);

      final article = Article(
        id: id1,
        title: title,
        description: 'Researchers uncover anomaly.',
        url: url,
        author: 'Dr. Evelyn Reed',
        sourceName: 'Ars Technica',
        publishedAt: DateTime(2025, 8, 14),
        discoveredAt: DateTime(2026, 11, 22),
        category: 'Science',
      );

      expect(article.sourceName, 'Ars Technica');
      expect(article.displayAuthor, 'Dr. Evelyn Reed');
      expect(article.formattedPublishedDate, 'Aug 14, 2025');
      expect(article.formattedDiscoveredDate, contains('Nov 22, 2026'));
    });
  });
}
