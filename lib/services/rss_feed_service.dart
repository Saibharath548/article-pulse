import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../../models/article.dart';
import '../../models/category.dart';

/// Service for fetching and parsing real-time RSS / Atom feeds.
/// Powers Live Articles and Home Feed Discovery with genuine publisher content.
class RssFeedService {
  final http.Client _client;

  RssFeedService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches live articles for a specific category from verified curated feeds.
  Future<List<Article>> fetchArticlesForCategory(ArticleCategory category, {int maxArticles = 15}) async {
    final articles = <Article>[];

    for (final feedUrl in category.feedUrls) {
      try {
        final feedArticles = await fetchFeed(feedUrl, defaultCategory: category.name);
        articles.addAll(feedArticles);
        if (articles.length >= maxArticles) break;
      } catch (_) {
        // Continue to fallback feed
      }
    }

    // Sort newest first
    articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return articles.take(maxArticles).toList();
  }

  /// Fetches and parses a single RSS or Atom feed URL.
  Future<List<Article>> fetchFeed(String url, {required String defaultCategory}) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'ArticlePulseApp/1.0 (Mozilla/5.0 compatible)',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} while fetching feed');
    }

    return parseFeedXml(response.body, defaultCategory: defaultCategory, fallbackUrl: url);
  }

  /// Parses RSS 2.0 or Atom XML content into a list of Articles.
  List<Article> parseFeedXml(String xmlString, {required String defaultCategory, String? fallbackUrl}) {
    final document = XmlDocument.parse(xmlString);
    final articles = <Article>[];
    final now = DateTime.now();

    // 1. Try RSS 2.0 (<channel><item>...</item></channel>)
    final items = document.findAllElements('item');
    if (items.isNotEmpty) {
      final channelTitle = document.findAllElements('channel').firstOrNull
          ?.findElements('title').firstOrNull?.innerText.trim() ?? 'Verified Publication';

      for (final item in items) {
        final title = item.findElements('title').firstOrNull?.innerText.trim() ?? '';
        var link = item.findElements('link').firstOrNull?.innerText.trim() ?? '';
        if (link.isEmpty) {
          link = item.findElements('guid').firstOrNull?.innerText.trim() ?? '';
        }
        if (title.isEmpty || link.isEmpty) continue;

        var description = item.findElements('description').firstOrNull?.innerText.trim() ?? '';
        description = _cleanHtml(description);

        final author = item.findElements('dc:creator').firstOrNull?.innerText.trim() ??
            item.findElements('author').firstOrNull?.innerText.trim();

        final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '';
        final publishedAt = _parseDate(pubDateStr) ?? now;

        articles.add(Article(
          id: Article.generateId(link, title),
          title: title,
          description: description.isNotEmpty ? description : title,
          url: link,
          author: author,
          sourceName: channelTitle,
          publishedAt: publishedAt,
          discoveredAt: now,
          category: defaultCategory,
          discoveryType: 'recent',
        ));
      }
      return articles;
    }

    // 2. Try Atom (<feed><entry>...</entry></feed>)
    final entries = document.findAllElements('entry');
    if (entries.isNotEmpty) {
      final feedTitle = document.findAllElements('feed').firstOrNull
          ?.findElements('title').firstOrNull?.innerText.trim() ?? 'Verified Publication';

      for (final entry in entries) {
        final title = entry.findElements('title').firstOrNull?.innerText.trim() ?? '';
        var link = '';
        final linkElements = entry.findElements('link');
        for (final l in linkElements) {
          final href = l.getAttribute('href');
          if (href != null && href.isNotEmpty) {
            link = href.trim();
            break;
          }
        }
        if (link.isEmpty && entry.findElements('id').isNotEmpty) {
          final idText = entry.findElements('id').first.innerText.trim();
          if (idText.startsWith('http')) link = idText;
        }
        if (title.isEmpty || link.isEmpty) continue;

        var summary = entry.findElements('summary').firstOrNull?.innerText.trim() ??
            entry.findElements('content').firstOrNull?.innerText.trim() ?? '';
        summary = _cleanHtml(summary);

        final author = entry.findAllElements('author').firstOrNull
            ?.findElements('name').firstOrNull?.innerText.trim();

        final dateStr = entry.findElements('published').firstOrNull?.innerText.trim() ??
            entry.findElements('updated').firstOrNull?.innerText.trim() ?? '';
        final publishedAt = _parseDate(dateStr) ?? now;

        articles.add(Article(
          id: Article.generateId(link, title),
          title: title,
          description: summary.isNotEmpty ? summary : title,
          url: link,
          author: author,
          sourceName: feedTitle,
          publishedAt: publishedAt,
          discoveredAt: now,
          category: defaultCategory,
          discoveryType: 'recent',
        ));
      }
    }

    return articles;
  }

  static String _cleanHtml(String html) {
    if (html.isEmpty) return '';
    // Strip HTML tags
    var clean = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common entities
    clean = clean
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > 300) {
      return '${clean.substring(0, 297)}...';
    }
    return clean;
  }

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    // Standard ISO 8601
    final iso = DateTime.tryParse(dateStr);
    if (iso != null) return iso;

    // RFC 822 / 1123 e.g. "Wed, 18 Nov 2026 17:01:07 GMT"
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 4) {
        // Find day, month, year
        final months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        int? day;
        int? month;
        int? year;

        for (final p in parts) {
          final clean = p.replaceAll(',', '').trim();
          final num = int.tryParse(clean);
          if (num != null) {
            if (num > 1900) {
              year = num;
            } else if (day == null && num >= 1 && num <= 31) {
              day = num;
            }
          } else {
            final m = months[clean.toLowerCase()];
            if (m != null) month = m;
          }
        }

        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}

    return null;
  }
}
