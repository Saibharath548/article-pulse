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

    final settled = await Future.wait(
      activeProviders.map((provider) async {
        try {
          return await provider.search(filter).timeout(const Duration(seconds: 18));
        } catch (error) {
          return ArticleSearchResult.empty(
            providerName: provider.name,
            coverageNotice: '${provider.name} could not be reached for this search.',
            errorMessage: error.toString(),
          );
        }
      }),
    );

    final merged = <Article>[];
    final sourceNames = <String>[];
    final failures = <String>[];
    var totalResults = 0;
    var hasMore = false;

    for (final result in settled) {
      sourceNames.add(result.providerName);
      totalResults += result.totalResults;
      hasMore = hasMore || result.hasMore;
      if (result.errorMessage != null && result.articles.isEmpty) {
        failures.add(result.providerName);
      }
      merged.addAll(result.articles);
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
    for (final article in filtered) {
      final key = _identityKey(article);
      final existing = deduplicated[key];
      if (existing == null || _metadataQuality(article) > _metadataQuality(existing)) {
        deduplicated[key] = article;
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

    final start = ((filter.page - 1) * filter.pageSize).clamp(0, results.length);
    final end = (start + filter.pageSize).clamp(0, results.length);
    final pageItems = results.sublist(start, end);

    final notice = 'Combined search across ${sourceNames.join(', ')}. '
        '${results.length} unique matches returned from this search batch.'
        '${failures.isEmpty ? '' : ' Unavailable sources: ${failures.join(', ')}.'}';

    return ArticleSearchResult(
      articles: pageItems,
      totalResults: totalResults > results.length ? totalResults : results.length,
      hasMore: end < results.length || hasMore,
      providerName: 'All Sources',
      coverageNotice: notice,
      errorMessage: pageItems.isEmpty && failures.length == activeProviders.length
          ? 'All search sources failed. Check your connection and try again.'
          : (failures.isEmpty ? null : 'Some sources could not be reached: ${failures.join(', ')}.'),
    );
  }

  String _identityKey(Article article) {
    try {
      final uri = Uri.parse(article.url.trim());
      if (uri.hasAuthority) {
        final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\\.'), '');
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
    return article.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

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
    final tokens = query.split(RegExp(r'\\s+')).where((token) => token.length > 1).toSet();
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

    // Prefer records with useful context when relevance is otherwise comparable.
    score += _metadataQuality(article);
    return score;
  }
}
