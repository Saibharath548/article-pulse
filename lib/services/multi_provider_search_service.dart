import '../models/article.dart';
import 'providers/search_provider_interface.dart';

/// Runs independent archives together and produces one stable, ranked result set.
/// Provider-specific selection remains available through ArticleRepository.
class MultiProviderSearchService {
  final List<ArticleSearchProvider> providers;

  const MultiProviderSearchService({required this.providers});

  Future<ArticleSearchResult> search(
    ArticleSearchFilter filter, {
    required bool includeGuardian,
  }) async {
    final activeProviders = providers
        .where((provider) => includeGuardian || provider.name != 'The Guardian')
        .toList();

    // Fetch enough provider pages to fill the requested global page after merging.
    // Each provider is paged sequentially so The Guardian's 1-request/second limit is respected.
    final requestedEnd = filter.page * filter.pageSize;
    final providerPageCount = (requestedEnd / 50).ceil().clamp(1, 100).toInt();
    final providerBatches = await Future.wait(
      activeProviders.map((provider) => _searchProviderPages(
        provider,
        filter,
        providerPageCount,
      )),
    );

    final merged = <Article>[];
    final sourceNames = <String>[];
    final failures = <String>[];
    var providerHasMore = false;

    for (var i = 0; i < providerBatches.length; i++) {
      final batch = providerBatches[i];
      sourceNames.add(activeProviders[i].name);
      for (final result in batch) {
        providerHasMore = providerHasMore || result.hasMore;
        if (result.errorMessage != null && result.articles.isEmpty) {
          if (!failures.contains(result.providerName)) failures.add(result.providerName);
        }
        merged.addAll(result.articles);
      }
    }

    final filtered = merged.where((article) {
      if (filter.fromDate != null && article.publishedAt.isBefore(filter.fromDate!)) {
        return false;
      }
      if (filter.toDate != null && article.publishedAt.isAfter(
        filter.toDate!.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)),
      )) {
        return false;
      }
      return true;
    }).toList();

    final deduplicated = <String, Article>{};
    final titleIndex = <String, String>{};
    for (final article in filtered) {
      final key = _identityKey(article);
      final titleKey = _normalizedTitle(article.title);
      final existingKey = deduplicated.containsKey(key) ? key : titleIndex[titleKey];
      final existing = existingKey == null ? null : deduplicated[existingKey];
      if (existing == null || _metadataQuality(article) > _metadataQuality(existing)) {
        if (existingKey != null && existingKey != key) deduplicated.remove(existingKey);
        deduplicated[key] = article;
        titleIndex[titleKey] = key;
      }
    }

    final results = deduplicated.values.toList()
      ..sort((a, b) {
        final relevance = _relevanceScore(b, filter.query).compareTo(
          _relevanceScore(a, filter.query),
        );
        if (relevance != 0) return relevance;
        return filter.sortByNewest
            ? b.publishedAt.compareTo(a.publishedAt)
            : a.publishedAt.compareTo(b.publishedAt);
      });

    final start = ((filter.page - 1) * filter.pageSize).clamp(0, results.length).toInt();
    final end = (start + filter.pageSize).clamp(0, results.length).toInt();
    final pageItems = results.sublist(start, end);

    final notice = 'Combined search across ${sourceNames.join(', ')}. '
        '${results.length} unique matches loaded so far.'
        '${failures.isEmpty ? '' : ' Unavailable sources: ${failures.join(', ')}.'}';

    return ArticleSearchResult(
      articles: pageItems,
      totalResults: results.length,
      hasMore: end < results.length || providerHasMore,
      providerName: 'All Sources',
      coverageNotice: notice,
      errorMessage: pageItems.isEmpty && failures.length == activeProviders.length
          ? 'All search sources failed. Check your connection and try again.'
          : (failures.isEmpty ? null : 'Some sources could not be reached: ${failures.join(', ')}.'),
    );
  }

  Future<List<ArticleSearchResult>> _searchProviderPages(
    ArticleSearchProvider provider,
    ArticleSearchFilter filter,
    int pageCount,
  ) async {
    final results = <ArticleSearchResult>[];
    for (var page = 1; page <= pageCount; page++) {
      try {
        final result = await provider.search(
          filter.copyWith(page: page, pageSize: 50),
        ).timeout(const Duration(seconds: 18));
        results.add(result);
        if (!result.hasMore || (result.errorMessage != null && result.articles.isEmpty)) {
          break;
        }
      } catch (error) {
        results.add(ArticleSearchResult.empty(
          providerName: provider.name,
          coverageNotice: '${provider.name} could not be reached for this search.',
          errorMessage: error.toString(),
        ));
        break;
      }
    }
    return results;
  }

  String _identityKey(Article article) {
    try {
      final uri = Uri.parse(article.url.trim());
      if (uri.hasAuthority) {
        final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
        final path = uri.path.replaceAll(RegExp(r'/+$'), '');
        final ignored = {'utm_source', 'utm_medium', 'utm_campaign', 'utm_term',
          'utm_content', 'fbclid', 'gclid', 'ref', 'source'};
        final query = Map<String, String>.from(uri.queryParameters)
          ..removeWhere((key, _) => ignored.contains(key.toLowerCase()));
        final sortedQuery = query.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return '$host$path?${Uri(queryParameters: Map.fromEntries(sortedQuery)).query}';
      }
    } catch (_) {}
    return _normalizedTitle(article.title);
  }

  String _normalizedTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  int _metadataQuality(Article article) {
    var score = 0;
    if (article.author?.trim().isNotEmpty ?? false) score += 2;
    if (article.description.trim().length > 80) score += 2;
    if (article.sourceName.trim().isNotEmpty) score++;
    if (!article.url.contains('news.ycombinator.com/item')) score++;
    return score;
  }

  int _relevanceScore(Article article, String rawQuery) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return 0;

    final title = article.title.toLowerCase();
    final description = article.description.toLowerCase();
    final tokens = query.split(RegExp(r'\s+')).where((token) => token.length > 1).toSet();
    var score = 0;
    if (title == query) score += 100;
    if (title.contains(query)) score += 60;
    if (description.contains(query)) score += 20;

    var titleMatches = 0;
    var descriptionMatches = 0;
    for (final token in tokens) {
      if (title.contains(token)) titleMatches++;
      if (description.contains(token)) descriptionMatches++;
    }
    if (tokens.isNotEmpty) {
      score += ((titleMatches / tokens.length) * 35).round();
      score += ((descriptionMatches / tokens.length) * 10).round();
    }

    score += _metadataQuality(article);
    return score;
  }
}
