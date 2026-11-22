import 'package:flutter/material.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';

class HomeFeedProvider extends ChangeNotifier {
  final ArticleRepository _repository;

  List<Article> _recentArticles = [];
  List<Article> _olderArticles = [];
  List<Article> _randomArticles = [];
  bool _isLoading = false;
  String? _errorMessage;

  HomeFeedProvider({required ArticleRepository repository}) : _repository = repository;

  List<Article> get recentArticles => _recentArticles;
  List<Article> get olderArticles => _olderArticles;
  List<Article> get randomArticles => _randomArticles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isEmpty =>
      _recentArticles.isEmpty && _olderArticles.isEmpty && _randomArticles.isEmpty;

  Future<void> loadFeed({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final feed = await _repository.getDailyDiscoveryFeed(forceRefresh: forceRefresh);
      _recentArticles = feed['recent'] ?? [];
      _olderArticles = feed['older'] ?? [];
      _randomArticles = feed['random'] ?? [];
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Could not refresh feed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(Article article) async {
    final newStatus = await _repository.db.toggleBookmark(article);
    _updateBookmarkStatus(article.id, newStatus);
    notifyListeners();
  }

  void _updateBookmarkStatus(String id, bool status) {
    _recentArticles = _recentArticles
        .map((a) => a.id == id ? a.copyWith(isBookmarked: status) : a)
        .toList();
    _olderArticles = _olderArticles
        .map((a) => a.id == id ? a.copyWith(isBookmarked: status) : a)
        .toList();
    _randomArticles = _randomArticles
        .map((a) => a.id == id ? a.copyWith(isBookmarked: status) : a)
        .toList();
  }
}
