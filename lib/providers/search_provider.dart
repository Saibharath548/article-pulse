import 'package:flutter/material.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/providers/search_provider_interface.dart';

class SearchProvider extends ChangeNotifier {
  final ArticleRepository _repository;

  String _query = '';
  String? _category;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _sortByNewest = true;
  String? _preferredProviderName;

  List<Article> _articles = [];
  int _totalResults = 0;
  bool _hasMore = false;
  int _currentPage = 1;
  String _coverageNotice = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  SearchProvider({required ArticleRepository repository})
      : _repository = repository,
        // Default historical search covers at least the previous 2 years
        _fromDate = DateTime.now().subtract(const Duration(days: 730)),
        _toDate = DateTime.now();

  String get query => _query;
  String? get category => _category;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  bool get sortByNewest => _sortByNewest;
  String? get preferredProviderName => _preferredProviderName;

  List<Article> get articles => _articles;
  int get totalResults => _totalResults;
  bool get hasMore => _hasMore;
  String get coverageNotice => _coverageNotice;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  void setQuery(String q) {
    _query = q;
  }

  void setCategory(String? cat) {
    _category = cat;
    notifyListeners();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void setSortByNewest(bool newest) {
    _sortByNewest = newest;
    notifyListeners();
  }

  void setPreferredProvider(String? providerName) {
    _preferredProviderName = providerName;
    notifyListeners();
  }

  Future<void> search({bool newSearch = true}) async {
    if (newSearch) {
      _currentPage = 1;
      _articles = [];
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final filter = ArticleSearchFilter(
        query: _query,
        category: _category,
        fromDate: _fromDate,
        toDate: _toDate,
        sortByNewest: _sortByNewest,
        page: _currentPage,
        pageSize: 20,
      );

      final result = await _repository.searchArticles(
        filter,
        preferredProviderName: _preferredProviderName,
      );

      if (newSearch) {
        _articles = result.articles;
      } else {
        _articles.addAll(result.articles);
      }

      _totalResults = result.totalResults;
      _hasMore = result.hasMore;
      _coverageNotice = result.coverageNotice;
      _errorMessage = result.errorMessage;
    } catch (e) {
      _errorMessage = 'Search failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _currentPage++;
    await search(newSearch: false);
  }

  Future<void> toggleBookmark(Article article) async {
    final newStatus = await _repository.db.toggleBookmark(article);
    _articles = _articles
        .map((a) => a.id == article.id ? a.copyWith(isBookmarked: newStatus) : a)
        .toList();
    notifyListeners();
  }
}
