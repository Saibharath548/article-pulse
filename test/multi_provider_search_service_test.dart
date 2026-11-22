import 'package:flutter_test/flutter_test.dart';
import 'package:article_pulse/models/article.dart';
import 'package:article_pulse/services/multi_provider_search_service.dart';
import 'package:article_pulse/services/providers/search_provider_interface.dart';

void main() {
  group('MultiProviderSearchService', () {
    test('merges sources, deduplicates same titles, and ranks exact title matches first', () async {
      final exact = _article(
        title: 'Why Men Who Rape Are Not Monsters',
        url: 'https://example.com/exact',
        author: 'Author',
        description: 'A detailed article description with useful context for readers.',
      );
      final duplicate = _article(
        title: 'Why Men Who Rape Are Not Monsters',
        url: 'https://another.example.com/story',
        description: 'Short summary.',
      );
      final partial = _article(
        title: 'Understanding violence and social behavior',
        url: 'https://example.com/partial',
        description: 'An article about why men who rape are not monsters.',
      );

      final service = MultiProviderSearchService(providers: [
        _FakeProvider('Archive A', [partial, duplicate]),
        _FakeProvider('Archive B', [exact]),
      ]);

      final result = await service.search(
        const ArticleSearchFilter(query: 'Why Men Who Rape Are Not Monsters', pageSize: 10),
        includeGuardian: false,
      );

      expect(result.providerName, 'All Sources');
      expect(result.articles.length, 2);
      expect(result.articles.first.title, exact.title);
      expect(result.articles.where((a) => a.title == exact.title).length, 1);
    });

    test('excludes Guardian when no API key is configured', () async {
      final service = MultiProviderSearchService(providers: [
        _FakeProvider('The Guardian', [_article(title: 'Guardian result', url: 'https://guardian.example/a')]),
        _FakeProvider('Crossref Open Works', [_article(title: 'Research result', url: 'https://doi.org/10.1/example')]),
      ]);

      final result = await service.search(
        const ArticleSearchFilter(query: 'research'),
        includeGuardian: false,
      );

      expect(result.articles.map((a) => a.title), ['Research result']);
      expect(result.coverageNotice, isNot(contains('The Guardian')));
    });

    test('keeps going when one provider throws', () async {
      final service = MultiProviderSearchService(providers: [
        _ThrowingProvider(),
        _FakeProvider('Working source', [_article(title: 'Available result', url: 'https://example.com/ok')]),
      ]);

      final result = await service.search(
        const ArticleSearchFilter(query: 'available'),
        includeGuardian: false,
      );

      expect(result.articles.single.title, 'Available result');
      expect(result.errorMessage, contains('Some sources'));
    });
  });
}

Article _article({
  required String title,
  required String url,
  String? author,
  String description = 'A useful article description.',
}) {
  final now = DateTime(2025, 4, 10);
  return Article(
    id: Article.generateId(url, title),
    title: title,
    description: description,
    url: url,
    author: author,
    sourceName: 'Test Publisher',
    publishedAt: now,
    discoveredAt: now,
    category: 'General Knowledge',
  );
}

class _FakeProvider implements ArticleSearchProvider {
  @override
  final String name;
  final List<Article> articles;

  _FakeProvider(this.name, this.articles);

  @override
  String get description => 'Test provider';
  @override
  bool get requiresApiKey => false;
  @override
  DateTime get earliestHistoricalDate => DateTime(2000);
  @override
  List<String> get supportedCategories => const [];

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    return ArticleSearchResult(
      articles: articles,
      totalResults: articles.length,
      hasMore: false,
      providerName: name,
      coverageNotice: 'Test results',
    );
  }
}

class _ThrowingProvider extends _FakeProvider {
  _ThrowingProvider() : super('Unavailable source', const []);

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    throw Exception('network unavailable');
  }
}
