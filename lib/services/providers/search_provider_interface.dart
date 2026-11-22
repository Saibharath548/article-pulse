import '../../models/article.dart';

/// Filter parameters for article search and historical discovery.
class ArticleSearchFilter {
  final String query;
  final String? category;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool sortByNewest;
  final int page;
  final int pageSize;

  const ArticleSearchFilter({
    required this.query,
    this.category,
    this.fromDate,
    this.toDate,
    this.sortByNewest = true,
    this.page = 1,
    this.pageSize = 20,
  });

  ArticleSearchFilter copyWith({
    String? query,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
    bool? sortByNewest,
    int? page,
    int? pageSize,
  }) {
    return ArticleSearchFilter(
      query: query ?? this.query,
      category: category ?? this.category,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      sortByNewest: sortByNewest ?? this.sortByNewest,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Result returned from an ArticleSearchProvider.
class ArticleSearchResult {
  final List<Article> articles;
  final int totalResults;
  final bool hasMore;
  final String providerName;
  final String coverageNotice;
  final bool isRateLimited;
  final String? errorMessage;

  const ArticleSearchResult({
    required this.articles,
    required this.totalResults,
    required this.hasMore,
    required this.providerName,
    required this.coverageNotice,
    this.isRateLimited = false,
    this.errorMessage,
  });

  factory ArticleSearchResult.empty({
    required String providerName,
    required String coverageNotice,
    String? errorMessage,
  }) {
    return ArticleSearchResult(
      articles: const [],
      totalResults: 0,
      hasMore: false,
      providerName: providerName,
      coverageNotice: coverageNotice,
      errorMessage: errorMessage,
    );
  }
}

/// Abstract contract for article search providers.
abstract class ArticleSearchProvider {
  String get name;
  String get description;
  bool get requiresApiKey;
  DateTime get earliestHistoricalDate;
  List<String> get supportedCategories;

  Future<ArticleSearchResult> search(ArticleSearchFilter filter);
}
