import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/database_service.dart';
import '../utils/url_helper.dart';

/// Clean, typography-first card displaying article metadata, publisher attribution,
/// dates, bookmark action, and a button to open the original external article.
class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onBookmarkToggle;
  final DatabaseService dbService;
  final bool showDiscoveredDate;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onBookmarkToggle,
    required this.dbService,
    this.showDiscoveredDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => UrlHelper.openArticle(context, article, dbService: dbService),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Metadata Bar: Source, Category & Bookmark Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Source Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.sourceName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Category Tag
                  Text(
                    '•  ${article.category}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Bookmark Button
                  IconButton(
                    icon: Icon(
                      article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: article.isBookmarked ? colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: article.isBookmarked ? 'Remove bookmark' : 'Bookmark article',
                    onPressed: onBookmarkToggle,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                article.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Short Description / Summary
              if (article.description.isNotEmpty)
                Text(
                  article.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Footer: Dates, Author & Read Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author byline
                        if (article.author != null && article.author!.isNotEmpty)
                          Text(
                            'By ${article.author}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        // Dates
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              'Published: ${article.formattedPublishedDate}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (showDiscoveredDate) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.radar_outlined, size: 12, color: theme.colorScheme.secondary),
                              const SizedBox(width: 4),
                              Text(
                                'Discovered: ${article.formattedDiscoveredDate}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Open External Article Action Button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Read Original', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => UrlHelper.openArticle(context, article, dbService: dbService),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
