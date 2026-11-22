import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/article.dart';
import 'search_provider_interface.dart';

/// Crossref Open Works search provider.
/// Completely free, requires zero API keys, covers peer-reviewed informative articles,
/// reviews, and scholarship across Science, Psychology, Economics, Environment, and History.
class CrossrefSearchProvider implements ArticleSearchProvider {
  static const String baseUrl = 'https://api.crossref.org/works';

  final http.Client _client;

  CrossrefSearchProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'Crossref Open Works';

  @override
  String get description => 'Scholarly and informative articles across Science, Psychology, Economics, Environment, and History (Decades of archive).';

  @override
  bool get requiresApiKey => false;

  @override
  DateTime get earliestHistoricalDate => DateTime(1970, 1, 1);

  @override
  List<String> get supportedCategories => [
        'Science',
        'Psychology',
        'Environment',
        'Business and Economics',
        'Society and Social Issues',
        'History',
        'Artificial Intelligence',
      ];

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    try {
      final filters = <String>[];

      if (filter.fromDate != null) {
        final f = filter.fromDate!;
        final month = f.month.toString().padLeft(2, '0');
        final day = f.day.toString().padLeft(2, '0');
        filters.add('from-pub-date:${f.year}-$month-$day');
      }

      if (filter.toDate != null) {
        final t = filter.toDate!;
        final month = t.month.toString().padLeft(2, '0');
        final day = t.day.toString().padLeft(2, '0');
        filters.add('until-pub-date:${t.year}-$month-$day');
      }

      final offset = (filter.page - 1) * filter.pageSize;
      final queryParams = <String, String>{
        'rows': filter.pageSize.clamp(1, 50).toString(),
        'offset': offset.clamp(0, 9999).toString(),
        'sort': 'published',
        'order': filter.sortByNewest ? 'desc' : 'asc',
      };

      String query = filter.query.trim();
      if (filter.category != null && filter.category != 'All') {
        if (query.isEmpty) {
          query = filter.category!;
        }
      }
      if (query.isNotEmpty) {
        queryParams['query'] = query;
      }

      if (filters.isNotEmpty) {
        queryParams['filter'] = filters.join(',');
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'ArticlePulseApp/1.0 (mailto:discovery@articlepulse.local)',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['message'] as Map<String, dynamic>? ?? {};
        final items = message['items'] as List<dynamic>? ?? [];
        final totalResults = message['total-results'] as int? ?? 0;

        final articles = <Article>[];
        final now = DateTime.now();

        for (final item in items) {
          // Extract title
          final titleList = item['title'] as List<dynamic>? ?? [];
          final title = titleList.isNotEmpty ? titleList.first.toString().trim() : '';
          if (title.isEmpty) continue;

          // Extract URL
          final resource = item['resource'] as Map<String, dynamic>? ?? {};
          final primary = resource['primary'] as Map<String, dynamic>? ?? {};
          var url = primary['URL'] as String? ?? item['URL'] as String? ?? '';
          if (url.isEmpty && item['DOI'] != null) {
            url = 'https://doi.org/${item['DOI']}';
          }
          if (url.isEmpty) continue;

          // Extract publication date
          DateTime publishedAt = now;
          final published = item['published'] as Map<String, dynamic>? ??
              item['published-print'] as Map<String, dynamic>? ??
              item['published-online'] as Map<String, dynamic>? ??
              item['created'] as Map<String, dynamic>? ??
              {};
          final dateParts = published['date-parts'] as List<dynamic>?;
          if (dateParts != null && dateParts.isNotEmpty) {
            final parts = dateParts.first as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final year = parts[0] as int? ?? now.year;
              final month = parts.length > 1 ? (parts[1] as int? ?? 1) : 1;
              final day = parts.length > 2 ? (parts[2] as int? ?? 1) : 1;
              publishedAt = DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
            }
          }

          // Extract authors
          String? author;
          final authorsList = item['author'] as List<dynamic>?;
          if (authorsList != null && authorsList.isNotEmpty) {
            final names = <String>[];
            for (final a in authorsList.take(3)) {
              final given = a['given'] as String? ?? '';
              final family = a['family'] as String? ?? '';
              final full = '$given $family'.trim();
              if (full.isNotEmpty) names.add(full);
            }
            if (names.isNotEmpty) {
              author = names.join(', ');
              if (authorsList.length > 3) author += ' et al.';
            }
          }

          // Extract source / journal name
          final container = item['container-title'] as List<dynamic>?;
          final sourceName = container != null && container.isNotEmpty
              ? container.first.toString().trim()
              : (item['publisher'] as String? ?? 'Open Scholarly Publication');

          // Extract abstract / description
          var abstractText = item['abstract'] as String? ?? '';
          abstractText = abstractText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          final description = abstractText.isNotEmpty
              ? (abstractText.length > 250 ? '${abstractText.substring(0, 247)}...' : abstractText)
              : 'Informative publication in $sourceName.';

          articles.add(Article(
            id: Article.generateId(url, title),
            title: title,
            description: description,
            url: url,
            author: author,
            sourceName: sourceName,
            publishedAt: publishedAt,
            discoveredAt: now,
            category: filter.category ?? 'Science',
            discoveryType: 'historical',
          ));
        }

        return ArticleSearchResult(
          articles: articles,
          totalResults: totalResults,
          hasMore: (offset + articles.length) < totalResults,
          providerName: name,
          coverageNotice: 'Showing Crossref Open Works archive. Covers Science, Psychology, Economics, and Environment.',
        );
      } else {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Failed to search Crossref archive (HTTP ${response.statusCode}).',
          errorMessage: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'Network error connecting to Crossref.',
        errorMessage: e.toString(),
      );
    }
  }
}
