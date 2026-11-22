import 'package:flutter/material.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';

class LiveArticlesProvider extends ChangeNotifier {
  final ArticleRepository _repository;

  List<Article> _articles = [];
  String? _selectedCategoryFilter;
  bool _isLoading = false;
  String? _errorMessage;

  LiveArticlesProvider({required ArticleRepository repository}) : _repository = repository;

  List<Article> get articles => _articles;
  String? get selectedCategoryFilter => _selectedCategoryFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLiveArticles({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _articles = await _repository.getLiveArticles(
        categoryName: _selectedCategoryFilter,
        forceRefresh: forceRefresh,
      );
      // Ensure sorted by newest published date
      _articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    } catch (e) {
      _errorMessage = 'Could not fetch live articles: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(String? categoryName) {
    if (_selectedCategoryFilter == categoryName) return;
    _selectedCategoryFilter = categoryName;
    loadLiveArticles(forceRefresh: true);
  }

  Future<void> toggleBookmark(Article article) async {
    final newStatus = await _repository.db.toggleBookmark(article);
    _articles = _articles
        .map((a) => a.id == article.id ? a.copyWith(isBookmarked: newStatus) : a)
        .toList();
    notifyListeners();
  }
}
