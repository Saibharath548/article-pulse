import 'dart:math';
import '../models/article.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/multi_provider_search_service.dart';
import '../services/providers/crossref_search_provider.dart';
import '../services/providers/guardian_search_provider.dart';
import '../services/providers/hn_algolia_provider.dart';
import '../services/providers/search_provider_interface.dart';
import '../services/rss_feed_service.dart';
import '../services/secure_storage_service.dart';

/// Central repository orchestrating multi-provider search, live discovery feeds,
/// Daily Discovery culling, offline caching, and impression tracking.
class ArticleRepository {
  final DatabaseService _dbService;
  final SecureStorageService _secureStorage;
  final RssFeedService _rssService;
  final GuardianSearchProvider _guardianProvider;
  final HnAlgoliaSearchProvider _algoliaProvider;
  final CrossrefSearchProvider _crossrefProvider;

  ArticleRepository({
    DatabaseService? dbService,
    SecureStorageService? secureStorage,
    RssFeedService? rssService,
    GuardianSearchProvider? guardianProvider,
    HnAlgoliaSearchProvider? algoliaProvider,
    CrossrefSearchProvider? crossrefProvider,
  })  : _dbService = dbService ?? DatabaseService(),
        _secureStorage = secureStorage ?? SecureStorageService(),
        _rssService = rssService ?? RssFeedService(),
        _guardianProvider = guardianProvider ?? GuardianSearchProvider(),
        _algoliaProvider = algoliaProvider ?? HnAlgoliaSearchProvider(),
        _crossrefProvider = crossrefProvider ?? CrossrefSearchProvider();

  DatabaseService get db => _dbService;
  SecureStorageService get secureStorage => _secureStorage;

  /// Fetches a dynamic Daily Discovery bundle:
  /// 1. Recent Articles (freshly published from live feeds)
  /// 2. Older / Timeless Discoveries (published 1-2 years ago from historical archives)
  /// 3. Random Discoveries (exploring varied subjects)
  /// Excludes articles shown in recent impressions to avoid repetitive recommendations.
  Future<Map<String, List<Article>>> getDailyDiscoveryFeed({bool forceRefresh = false}) async {
    final recentImpressionIds = await _dbService.getRecentImpressionIds(
      window: const Duration(hours: 48),
    );

    final recentList = <Article>[];
    final olderList = <Article>[];
    final randomList = <Article>[];

    // Pick 3-4 varied categories for today's discovery seed
    final allCategories = List<ArticleCategory>.from(ArticleCategory.initialCategories);
    allCategories.shuffle(Random(DateTime.now().day + (forceRefresh ? Random().nextInt(100) : 0)));
    final selectedCategories = allCategories.take(4).toList();

    // 1. Fetch fresh live candidates across selected categories
    for (final cat in selectedCategories) {
      try {
        final liveItems = await _rssService.fetchArticlesForCategory(cat, maxArticles: 6);
        for (final item in liveItems) {
          if (!recentImpressionIds.contains(item.id)) {
            recentList.add(item.copyWith(discoveryType: 'recent'));
          }
        }
      } catch (_) {}
    }

    // 2. Fetch older / timeless discoveries (published 1 to 2 years ago)
    final now = DateTime.now();
    final twoYearsAgo = now.subtract(const Duration(days: 730));
    final oneYearAgo = now.subtract(const Duration(days: 365));

    try {
      final historicalResult = await _crossrefProvider.search(ArticleSearchFilter(
        query: selectedCategories.first.searchKeywords.first,
        category: selectedCategories.first.name,
        fromDate: twoYearsAgo,
        toDate: oneYearAgo,
        sortByNewest: true,
        pageSize: 10,
      ));

      for (final item in historicalResult.articles) {
        if (!recentImpressionIds.contains(item.id)) {
          olderList.add(item.copyWith(discoveryType: 'historical'));
        }
      }
    } catch (_) {}

    // Fallback if olderList is sparse: query HN Algolia for older tech/science gems
    if (olderList.length < 3) {
      try {
        final hnResult = await _algoliaProvider.search(ArticleSearchFilter(
          query: 'essay OR discovery',
          fromDate: twoYearsAgo,
          toDate: oneYearAgo,
          sortByNewest: false,
          pageSize: 10,
        ));
        for (final item in hnResult.articles) {
          if (!recentImpressionIds.contains(item.id) && !olderList.any((a) => a.id == item.id)) {
            olderList.add(item.copyWith(discoveryType: 'historical'));
          }
        }
      } catch (_) {}
    }

    // 3. Random discoveries across remaining categories
    final randomCategory = allCategories.last;
    try {
      final randomCandidates = await _rssService.fetchArticlesForCategory(randomCategory, maxArticles: 6);
      for (final item in randomCandidates) {
        if (!recentImpressionIds.contains(item.id)) {
          randomList.add(item.copyWith(discoveryType: 'random'));
        }
      }
    } catch (_) {}

    // If offline or remote feeds yielded too few, supplement with non-impressed cached articles
    if (recentList.isEmpty && olderList.isEmpty) {
      final cached = await _dbService.getCachedArticles(limit: 30);
      for (final c in cached) {
        if (c.publishedAt.isBefore(oneYearAgo)) {
          olderList.add(c);
        } else {
          recentList.add(c);
        }
      }
    }

    // Deduplicate across groups
    final seen = <String>{};
    recentList.removeWhere((a) => !seen.add(a.id));
    olderList.removeWhere((a) => !seen.add(a.id));
    randomList.removeWhere((a) => !seen.add(a.id));

    // Cache fetched articles in SQLite
    final allFetched = [...recentList, ...olderList, ...randomList];
    await _dbService.saveArticles(allFetched);

    // Record impressions so they won't repeat immediately
    final shownIds = allFetched.map((a) => a.id).toList();
    await _dbService.recordImpressions(shownIds, 'home_feed');

    return {
      'recent': recentList.take(6).toList(),
      'older': olderList.take(6).toList(),
      'random': randomList.take(6).toList(),
    };
  }

  /// Fetches live articles for Live Articles screen.
  Future<List<Article>> getLiveArticles({String? categoryName, bool forceRefresh = false}) async {
    try {
      if (categoryName != null) {
        final cat = ArticleCategory.byName(categoryName);
        final articles = await _rssService.fetchArticlesForCategory(cat, maxArticles: 25);
        await _dbService.saveArticles(articles);
        return articles;
      }

      // "All" categories: Fetch live feeds across all categories concurrently
      final futures = ArticleCategory.initialCategories.map((cat) {
        return _rssService.fetchArticlesForCategory(cat, maxArticles: 5);
      });
      final results = await Future.wait(futures);
      final combined = <Article>[];
      final seenIds = <String>{};

      for (final list in results) {
        for (final article in list) {
          if (seenIds.add(article.id)) {
            combined.add(article);
          }
        }
      }

      // Sort globally newest first
      combined.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      await _dbService.saveArticles(combined);
      return combined;
    } catch (e) {
      // Offline fallback: return cached live/recent articles
      return await _dbService.getCachedArticles(
        category: categoryName,
        limit: 30,
        orderByNewest: true,
      );
    }
  }

  /// Searches all free archives by default, while preserving explicit provider selection.
  /// Results are merged, deduplicated, ranked, and cached without changing existing screens.
  Future<ArticleSearchResult> searchArticles(ArticleSearchFilter filter, {String? preferredProviderName}) async {
    final hasGuardianKey = await _secureStorage.hasGuardianApiKey();

    // Keep the existing provider selector behavior for users who intentionally choose one source.
    if (preferredProviderName != null) {
      final ArticleSearchProvider? selectedProvider = switch (preferredProviderName) {
        'The Guardian' => _guardianProvider,
        'Hacker News Search (Algolia)' => _algoliaProvider,
        'Crossref Open Works' => _crossrefProvider,
        _ => null,
      };

      if (selectedProvider != null) {
        try {
          final result = await selectedProvider.search(filter);
          if (result.articles.isNotEmpty) {
            await _dbService.saveArticles(result.articles);
          }
          return result;
        } catch (e) {
          return _offlineSearchFallback(filter, e);
        }
      }
    }

    try {
      final searchService = MultiProviderSearchService(
        providers: [
          _algoliaProvider,
          _crossrefProvider,
          _guardianProvider,
        ],
      );
      final result = await searchService.search(
        filter,
        includeGuardian: hasGuardianKey,
      );

      if (result.articles.isNotEmpty) {
        await _dbService.saveArticles(result.articles);
      }
      return result;
    } catch (e) {
      return _offlineSearchFallback(filter, e);
    }
  }

  Future<ArticleSearchResult> _offlineSearchFallback(
    ArticleSearchFilter filter,
    Object error,
  ) async {
    final cached = await _dbService.getCachedArticles(
      category: filter.category,
      searchQuery: filter.query,
      limit: filter.pageSize,
      offset: (filter.page - 1) * filter.pageSize,
      orderByNewest: filter.sortByNewest,
    );

    return ArticleSearchResult(
      articles: cached,
      totalResults: cached.length,
      hasMore: false,
      providerName: 'Offline Local Cache',
      coverageNotice: 'Offline Mode: Displaying matching articles saved from previous discovery sessions.',
      errorMessage: 'Search failed; showing local results: $error',
    );
  }

  /// Fetches articles for a specific category browser view.
  Future<List<Article>> getCategoryArticles(ArticleCategory category, {bool forceRefresh = false}) async {
    try {
      final articles = await _rssService.fetchArticlesForCategory(category, maxArticles: 20);
      if (articles.isNotEmpty) {
        await _dbService.saveArticles(articles);
        return articles;
      }
    } catch (_) {}

    // Fallback to cached category articles
    return await _dbService.getCachedArticles(
      category: category.name,
      limit: 20,
      orderByNewest: true,
    );
  }
}
