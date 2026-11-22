import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../repositories/article_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final ArticleRepository _repository;

  ArticleCategory _selectedCategory = ArticleCategory.initialCategories.first;
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;

  CategoryProvider({required ArticleRepository repository}) : _repository = repository;

  ArticleCategory get selectedCategory => _selectedCategory;
  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> selectCategory(ArticleCategory category, {bool forceRefresh = false}) async {
    _selectedCategory = category;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _articles = await _repository.getCategoryArticles(category, forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessage = 'Could not load category articles: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(Article article) async {
    final newStatus = await _repository.db.toggleBookmark(article);
    _articles = _articles
        .map((a) => a.id == article.id ? a.copyWith(isBookmarked: newStatus) : a)
        .toList();
    notifyListeners();
  }
}
