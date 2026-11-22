import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bookmarks_history_provider.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';

class BookmarksHistoryScreen extends StatefulWidget {
  const BookmarksHistoryScreen({super.key});

  @override
  State<BookmarksHistoryScreen> createState() => _BookmarksHistoryScreenState();
}

class _BookmarksHistoryScreenState extends State<BookmarksHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarksHistoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClearHistory(BuildContext context, BookmarksHistoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Reading History?'),
        content: const Text('This will remove all reading history logs from your device. Bookmarks will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<BookmarksHistoryProvider>();
    final repo = context.read<ArticleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved & History'),
        actions: [
          if (_tabController.index == 1 && provider.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: () => _confirmClearHistory(context, provider),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(
              icon: const Icon(Icons.bookmark_outline),
              text: 'Bookmarks (${provider.bookmarks.length})',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'History (${provider.history.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline Status Notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surface,
            child: Row(
              children: [
                Icon(Icons.offline_pin_outlined, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stored locally on your device. Article metadata is accessible offline. Opening original publisher links requires internet.',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Filter for Saved Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search saved articles...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => provider.setSearchQuery(val),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Bookmarks List
                _buildBookmarksTab(context, provider, repo),
                // 2. Reading History List
                _buildHistoryTab(context, provider, repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab(BuildContext context, BookmarksHistoryProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);

    if (provider.bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 54, color: theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No Bookmarked Articles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Bookmark interesting articles from the discovery feed or search to read them later.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: provider.bookmarks.length,
      itemBuilder: (context, index) {
        final article = provider.bookmarks[index];
        return ArticleCard(
          article: article,
          onBookmarkToggle: () => provider.toggleBookmark(article),
          dbService: repo.db,
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context, BookmarksHistoryProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);

    if (provider.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 54, color: theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No Reading History Yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Articles you open to read will appear here for easy reference.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: provider.history.length,
      itemBuilder: (context, index) {
        final article = provider.history[index];
        return ArticleCard(
          article: article,
          onBookmarkToggle: () => provider.toggleBookmark(article),
          dbService: repo.db,
        );
      },
    );
  }
}
