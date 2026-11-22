import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import '../../models/article.dart';
import 'search_provider_interface.dart';

/// Broad news-web discovery through Google's public News RSS search endpoint.
/// No API key is required. Coverage is news-oriented and is not a complete web index.
class GoogleNewsRssSearchProvider implements ArticleSearchProvider {
  static const String baseUrl = 'https://news.google.com/rss/search';
  final http.Client _client;

  GoogleNewsRssSearchProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'Google News Web Search';
  @override
  String get description => 'Broad publisher and news-site discovery through Google News RSS; no API key required.';
  @override
  bool get requiresApiKey => false;
  @override
  DateTime get earliestHistoricalDate => DateTime(2000, 1, 1);
  @override
  List<String> get supportedCategories => const [];

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    try {
      var query = filter.query.trim();
      if (filter.category != null && filter.category != 'All') {
        query = query.isEmpty ? filter.category! : '$query \${filter.category}';
      }
      if (filter.fromDate != null) query += ' after:\${_date(filter.fromDate!)}';
      if (filter.toDate != null) {
        query += ' before:\${_date(filter.toDate!.add(const Duration(days: 1)))}';
      }
      if (query.trim().isEmpty) {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Enter a search phrase to discover publisher articles.',
        );
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'q': query,
        'hl': 'en-US',
        'gl': 'US',
        'ceid': 'US:en',
      });
      final response = await _client.get(uri, headers: {
        'User-Agent': 'ArticlePulseApp/1.0 (compatible; RSS reader)',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Google News RSS returned HTTP \${response.statusCode}.',
          errorMessage: 'HTTP \${response.statusCode}',
        );
      }

      final document = XmlDocument.parse(response.body);
      final articles = <Article>[];
      final now = DateTime.now();
      for (final item in document.findAllElements('item')) {
        final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
        final link = item.findElements('link').firstOrNull?.innerText.trim() ?? '';
        if (title.isEmpty || link.isEmpty) continue;

        final rawDescription = item.findElements('description').firstOrNull?.innerText ?? '';
        final description = rawDescription
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .join(' ');
        final source = item.findElements('source').firstOrNull?.innerText.trim();
        final dateText = item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '';
        final publishedAt = DateTime.tryParse(dateText) ?? _parseRssDate(dateText) ?? now;

        articles.add(Article(
          id: Article.generateId(link, title),
          title: title,
          description: description.isEmpty ? 'News article discovered via Google News.' : description,
          url: link,
          sourceName: source?.isNotEmpty == true ? source! : 'Google News result',
          publishedAt: publishedAt,
          discoveredAt: now,
          category: filter.category ?? 'General Knowledge',
          discoveryType: 'historical',
        ));
      }

      articles.sort((a, b) => filter.sortByNewest
          ? b.publishedAt.compareTo(a.publishedAt)
          : a.publishedAt.compareTo(b.publishedAt));
      final start = ((filter.page - 1) * filter.pageSize).clamp(0, articles.length).toInt();
      final end = (start + filter.pageSize).clamp(0, articles.length).toInt();
      return ArticleSearchResult(
        articles: articles.sublist(start, end),
        totalResults: articles.length,
        hasMore: end < articles.length,
        providerName: name,
        coverageNotice: 'Google News RSS publisher search. This is broad news discovery, not a complete index of all web articles.',
      );
    } catch (error) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'Could not retrieve Google News RSS results.',
        errorMessage: error.toString(),
      );
    }
  }

  String _date(DateTime date) =>
      '\${date.year}-\${date.month.toString().padLeft(2, '0')}-\${date.day.toString().padLeft(2, '0')}';

  DateTime? _parseRssDate(String value) {
    if (value.isEmpty) return null;
    try {
      final comma = value.indexOf(',');
      final normalized = (comma >= 0 ? value.substring(comma + 1) : value)
          .trim()
          .replaceFirst(' GMT', '');
      return DateFormat('d MMM yyyy HH:mm:ss', 'en_US').parseUtc(normalized);
    } catch (_) {
      return null;
    }
  }
}
