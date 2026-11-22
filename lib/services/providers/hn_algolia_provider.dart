import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/article.dart';
import 'search_provider_interface.dart';

/// Hacker News Algolia historical search provider.
/// Completely free, requires zero API keys, covers 2007 to Present (>18 years).
/// Ideal for Technology, Game Development, AI, and digital society topics.
class HnAlgoliaSearchProvider implements ArticleSearchProvider {
  static const String baseUrlDate = 'https://hn.algolia.com/api/v1/search_by_date';
  static const String baseUrlRelevance = 'https://hn.algolia.com/api/v1/search';

  final http.Client _client;

  HnAlgoliaSearchProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'Hacker News Search (Algolia)';

  @override
  String get description => 'Articles, blog posts, essays, and reports in Tech, AI, Game Dev, and Startups (2007–Present).';

  @override
  bool get requiresApiKey => false;

  @override
  DateTime get earliestHistoricalDate => DateTime(2007, 1, 1);

  @override
  List<String> get supportedCategories => [
        'Technology',
        'Game Development',
        'Artificial Intelligence',
        'Business and Economics',
        'Society and Social Issues',
        'General Knowledge',
      ];

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    try {
      final endpoint = filter.sortByNewest ? baseUrlDate : baseUrlRelevance;
      final numericFilters = <String>[];

      if (filter.fromDate != null) {
        final fromSec = filter.fromDate!.millisecondsSinceEpoch ~/ 1000;
        numericFilters.add('created_at_i>=$fromSec');
      }

      if (filter.toDate != null) {
        final toSec = filter.toDate!.millisecondsSinceEpoch ~/ 1000;
        numericFilters.add('created_at_i<=$toSec');
      }

      final queryParams = <String, String>{
        'tags': 'story',
        'page': (filter.page - 1).clamp(0, 999).toString(),
        'hitsPerPage': filter.pageSize.clamp(1, 50).toString(),
      };

      // Combine query and category keywords if relevant
      String query = filter.query.trim();
      if (filter.category != null && filter.category != 'All') {
        if (query.isEmpty) {
          query = filter.category!;
        }
      }
      if (query.isNotEmpty) {
        queryParams['query'] = query;
      }

      if (numericFilters.isNotEmpty) {
        queryParams['numericFilters'] = numericFilters.join(',');
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['hits'] as List<dynamic>? ?? [];
        final nbHits = data['nbHits'] as int? ?? 0;
        final nbPages = data['nbPages'] as int? ?? 1;

        final articles = <Article>[];
        final now = DateTime.now();

        for (final hit in hits) {
          final title = hit['title'] as String? ?? hit['story_title'] as String? ?? '';
          if (title.isEmpty) continue;

          var url = hit['url'] as String? ?? hit['story_url'] as String? ?? '';
          final objectId = hit['objectID'] as String? ?? '';
          if (url.isEmpty && objectId.isNotEmpty) {
            url = 'https://news.ycombinator.com/item?id=$objectId';
          }
          if (url.isEmpty) continue;

          final author = hit['author'] as String?;
          final createdAtStr = hit['created_at'] as String? ?? '';
          final publishedAt = DateTime.tryParse(createdAtStr) ?? now;
          final points = hit['points'] as int? ?? 0;

          // Infer domain / publisher from URL
          String sourceName = 'Web Discovery';
          try {
            final parsedUri = Uri.parse(url);
            if (parsedUri.host.isNotEmpty) {
              sourceName = parsedUri.host.replaceFirst(RegExp(r'^www\.'), '');
            }
          } catch (_) {}

          final description = points > 0
              ? 'Community curation with $points upvotes. Published in $sourceName.'
              : 'Informative article published in $sourceName.';

          articles.add(Article(
            id: Article.generateId(url, title),
            title: title,
            description: description,
            url: url,
            author: author,
            sourceName: sourceName,
            publishedAt: publishedAt,
            discoveredAt: now,
            category: filter.category ?? 'Technology',
            discoveryType: 'historical',
          ));
        }

        return ArticleSearchResult(
          articles: articles,
          totalResults: nbHits,
          hasMore: filter.page < nbPages,
          providerName: name,
          coverageNotice: 'Showing Algolia Hacker News archive (2007–Present). Covers Tech, AI, Game Dev, and digital society.',
        );
      } else {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Failed to search Algolia archive (HTTP ${response.statusCode}).',
          errorMessage: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'Network error connecting to Algolia search.',
        errorMessage: e.toString(),
      );
    }
  }
}
