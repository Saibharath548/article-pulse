import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/article.dart';
import '../secure_storage_service.dart';
import 'guardian_rate_limiter.dart';
import 'search_provider_interface.dart';

/// The Guardian Open Platform search provider.
/// Provides journalistic articles dating back to 1999 (>25 years of history).
/// Developer tier is limited to 500 requests/day, 1 req/sec.
class GuardianSearchProvider implements ArticleSearchProvider {
  static const String baseUrl = 'https://content.guardianapis.com/search';

  final SecureStorageService _secureStorage;
  final GuardianRateLimiter _rateLimiter;
  final http.Client _client;

  GuardianSearchProvider({
    SecureStorageService? secureStorage,
    GuardianRateLimiter? rateLimiter,
    http.Client? client,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _rateLimiter = rateLimiter ?? GuardianRateLimiter(),
        _client = client ?? http.Client();

  @override
  String get name => 'The Guardian';

  @override
  String get description => 'Journalistic reporting across politics, society, history, science, and world events (1999–Present).';

  @override
  bool get requiresApiKey => true;

  @override
  DateTime get earliestHistoricalDate => DateTime(1999, 1, 1);

  @override
  List<String> get supportedCategories => [
        'Government and Politics',
        'Society and Social Issues',
        'History',
        'Business and Economics',
        'Environment',
        'Science',
        'Technology',
        'General Knowledge',
      ];

  String? _mapCategoryToSection(String? category) {
    if (category == null || category == 'All') return null;
    switch (category.toLowerCase()) {
      case 'government and politics':
      case 'gov_politics':
        return 'politics';
      case 'society and social issues':
      case 'society':
        return 'society';
      case 'history':
        return 'culture|books';
      case 'business and economics':
      case 'business':
        return 'business';
      case 'environment':
        return 'environment';
      case 'science':
      case 'psychology':
        return 'science';
      case 'technology':
      case 'game development':
      case 'game_dev':
      case 'artificial intelligence':
      case 'ai':
        return 'technology';
      default:
        return null;
    }
  }

  @override
  Future<ArticleSearchResult> search(ArticleSearchFilter filter) async {
    final apiKey = await _secureStorage.getGuardianApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'The Guardian API requires a free developer key (500 requests/day). Add your key in Settings to activate.',
        errorMessage: 'Guardian API key not configured. Obtain a free key at open-platform.theguardian.com and paste it in Settings.',
      );
    }

    final canRequest = await _rateLimiter.canMakeRequest();
    if (!canRequest) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'Daily developer quota of 500 requests reached. Resets at 00:00 UTC.',
        errorMessage: 'Quota exceeded for today.',
      );
    }

    try {
      await _rateLimiter.acquire();

      final queryParams = <String, String>{
        'api-key': apiKey,
        'page': filter.page.toString(),
        'page-size': filter.pageSize.clamp(1, 50).toString(),
        'show-fields': 'trailText,byline,headline',
        'order-by': filter.sortByNewest ? 'newest' : 'oldest',
      };

      if (filter.query.trim().isNotEmpty) {
        queryParams['q'] = filter.query.trim();
      }

      final section = _mapCategoryToSection(filter.category);
      if (section != null) {
        queryParams['section'] = section;
      }

      final dateFormat = DateFormat('yyyy-MM-dd');
      if (filter.fromDate != null) {
        queryParams['from-date'] = dateFormat.format(filter.fromDate!);
      }
      if (filter.toDate != null) {
        queryParams['to-date'] = dateFormat.format(filter.toDate!);
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseObj = data['response'] as Map<String, dynamic>? ?? {};
        final results = responseObj['results'] as List<dynamic>? ?? [];
        final total = responseObj['total'] as int? ?? 0;
        final pages = responseObj['pages'] as int? ?? 1;

        final articles = <Article>[];
        final now = DateTime.now();

        for (final item in results) {
          final fields = item['fields'] as Map<String, dynamic>? ?? {};
          final webTitle = item['webTitle'] as String? ?? 'Untitled';
          final webUrl = item['webUrl'] as String? ?? '';
          final trailText = fields['trailText'] as String? ?? '';
          final cleanSummary = trailText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          final byline = fields['byline'] as String?;
          final pubDateStr = item['webPublicationDate'] as String? ?? '';
          final publishedAt = DateTime.tryParse(pubDateStr) ?? now;
          final sectionName = item['sectionName'] as String? ?? 'The Guardian';

          if (webUrl.isNotEmpty) {
            articles.add(Article(
              id: Article.generateId(webUrl, webTitle),
              title: webTitle,
              description: cleanSummary.isNotEmpty ? cleanSummary : webTitle,
              url: webUrl,
              author: byline,
              sourceName: 'The Guardian ($sectionName)',
              publishedAt: publishedAt,
              discoveredAt: now,
              category: filter.category ?? sectionName,
              discoveryType: 'historical',
            ));
          }
        }

        final remaining = await _rateLimiter.getRemainingRequestsToday();
        return ArticleSearchResult(
          articles: articles,
          totalResults: total,
          hasMore: filter.page < pages,
          providerName: name,
          coverageNotice: 'Showing Guardian archive (1999–Present). Remaining requests today: $remaining / 500.',
        );
      } else if (response.statusCode == 429) {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Guardian API rate limit reached (max 1 req/sec or 500/day). Please wait.',
          errorMessage: 'HTTP 429: Rate limit exceeded.',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Invalid Guardian API key. Please check your key in Settings.',
          errorMessage: 'Authentication failed: Invalid API key.',
        );
      } else {
        return ArticleSearchResult.empty(
          providerName: name,
          coverageNotice: 'Failed to fetch from The Guardian (HTTP ${response.statusCode}).',
          errorMessage: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return ArticleSearchResult.empty(
        providerName: name,
        coverageNotice: 'Network or parsing error connecting to The Guardian.',
        errorMessage: e.toString(),
      );
    }
  }
}
