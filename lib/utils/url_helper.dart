import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../services/database_service.dart';

class UrlHelper {
  /// Opens an article in the device's external browser, preserving copyright and original attribution.
  /// Automatically logs the article to local reading history in SQLite.
  static Future<void> openArticle(
    BuildContext context,
    Article article, {
    DatabaseService? dbService,
  }) async {
    final rawUrl = article.url.trim();
    if (rawUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No article URL available.')),
        );
      }
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid article link.')),
        );
      }
      return;
    }

    try {
      // Record reading history in SQLite
      if (dbService != null) {
        await dbService.recordReadingHistory(article);
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external browser for this article.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open link: ${e.toString()}')),
        );
      }
    }
  }
}
