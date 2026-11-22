import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

/// Represents an article metadata item in Article Pulse.
/// Preserves publisher attribution, original URL, and publication date.
/// Full copyrighted article bodies are never stored or scraped.
class Article {
  final String id;
  final String title;
  final String description;
  final String url;
  final String? author;
  final String sourceName;
  final DateTime publishedAt;
  final DateTime discoveredAt;
  final String category;
  final String discoveryType; // 'recent', 'historical', 'random', 'daily_discovery'
  final bool isBookmarked;

  const Article({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.author,
    required this.sourceName,
    required this.publishedAt,
    required this.discoveredAt,
    required this.category,
    this.discoveryType = 'recent',
    this.isBookmarked = false,
  });

  /// Generates a consistent, deterministic ID from the article's URL or title.
  static String generateId(String url, [String? title]) {
    final raw = url.isNotEmpty ? url.trim() : (title?.trim() ?? DateTime.now().toIso8601String());
    return md5.convert(utf8.encode(raw)).toString();
  }

  Article copyWith({
    String? id,
    String? title,
    String? description,
    String? url,
    String? author,
    String? sourceName,
    DateTime? publishedAt,
    DateTime? discoveredAt,
    String? category,
    String? discoveryType,
    bool? isBookmarked,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      author: author ?? this.author,
      sourceName: sourceName ?? this.sourceName,
      publishedAt: publishedAt ?? this.publishedAt,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      category: category ?? this.category,
      discoveryType: discoveryType ?? this.discoveryType,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'author': author,
      'source_name': sourceName,
      'published_at': publishedAt.toIso8601String(),
      'discovered_at': discoveredAt.toIso8601String(),
      'category': category,
      'discovery_type': discoveryType,
      'is_bookmarked': isBookmarked ? 1 : 0,
    };
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled Article',
      description: map['description'] as String? ?? '',
      url: map['url'] as String? ?? '',
      author: map['author'] as String?,
      sourceName: map['source_name'] as String? ?? 'Unknown Source',
      publishedAt: DateTime.tryParse(map['published_at'] as String? ?? '') ?? DateTime.now(),
      discoveredAt: DateTime.tryParse(map['discovered_at'] as String? ?? '') ?? DateTime.now(),
      category: map['category'] as String? ?? 'General Knowledge',
      discoveryType: map['discovery_type'] as String? ?? 'recent',
      isBookmarked: (map['is_bookmarked'] as int? ?? 0) == 1,
    );
  }

  String get formattedPublishedDate {
    return DateFormat('MMM d, yyyy').format(publishedAt);
  }

  String get formattedDiscoveredDate {
    return DateFormat('MMM d, yyyy – HH:mm').format(discoveredAt);
  }

  String get displayAuthor {
    if (author != null && author!.trim().isNotEmpty) {
      return author!.trim();
    }
    return sourceName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
