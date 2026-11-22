import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/database_service.dart';

class BookmarksHistoryProvider extends ChangeNotifier {
  final DatabaseService _dbService;

  List<Article> _bookmarks = [];
  List<Article> _history = [];
  String _searchQuery = '';
  bool _isLoading = false;

  BookmarksHistoryProvider({required DatabaseService dbService}) : _dbService = dbService;

  List<Article> get bookmarks => _bookmarks;
  List<Article> get history => _history;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      loadBookmarks(),
      loadHistory(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBookmarks() async {
    _bookmarks = await _dbService.getBookmarks(
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _history = await _dbService.getReadingHistory();
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    loadBookmarks();
  }

  Future<void> toggleBookmark(Article article) async {
    final status = await _dbService.toggleBookmark(article);
    if (!status) {
      _bookmarks.removeWhere((a) => a.id == article.id);
    } else {
      _bookmarks.insert(0, article.copyWith(isBookmarked: true));
    }
    // Also update history item bookmark state
    _history = _history
        .map((a) => a.id == article.id ? a.copyWith(isBookmarked: status) : a)
        .toList();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _dbService.clearReadingHistory();
    _history = [];
    notifyListeners();
  }
}
