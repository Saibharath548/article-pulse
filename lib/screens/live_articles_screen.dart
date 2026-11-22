import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/live_articles_provider.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';

class LiveArticlesScreen extends StatefulWidget {
  const LiveArticlesScreen({super.key});

  @override
  State<LiveArticlesScreen> createState() => _LiveArticlesScreenState();
}

class _LiveArticlesScreenState extends State<LiveArticlesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LiveArticlesProvider>();
      if (provider.articles.isEmpty) {
        provider.loadLiveArticles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<LiveArticlesProvider>();
    final repo = context.read<ArticleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sensors, size: 22),
            SizedBox(width: 8),
            Text('Live Articles'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Live Stream',
            onPressed: provider.isLoading ? null : () => provider.loadLiveArticles(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Informational Banner: Explaining Live stream and Date Distinction
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Real-time stream from internet publications. Publication dates reflect the author\'s release, while Discovered dates mark when Article Pulse retrieved them.',
                    style: TextStyle(fontSize: 12, color: colorScheme.secondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Horizontal Scroll
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                FilterChip(
                  label: const Text('All Topics'),
                  selected: provider.selectedCategoryFilter == null,
                  onSelected: (selected) {
                    if (selected) provider.setCategoryFilter(null);
                  },
                ),
                const SizedBox(width: 8),
                ...ArticleCategory.initialCategories.map((c) {
                  final isSelected = provider.selectedCategoryFilter == c.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        provider.setCategoryFilter(selected ? c.name : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Live Articles List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadLiveArticles(forceRefresh: true),
              child: _buildList(context, provider, repo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, LiveArticlesProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);

    if (provider.isLoading && provider.articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Listening for live publications...'),
          ],
        ),
      );
    }

    if (provider.errorMessage != null && provider.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_connected_no_internet_4, size: 40, color: Colors.orange),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => provider.loadLiveArticles(forceRefresh: true),
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.articles.isEmpty) {
      return Center(
        child: Text(
          'No recent articles retrieved. Pull down to refresh.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: provider.articles.length,
      itemBuilder: (context, index) {
        final article = provider.articles[index];
        return ArticleCard(
          article: article,
          onBookmarkToggle: () => provider.toggleBookmark(article),
          dbService: repo.db,
          showDiscoveredDate: true, // Highlights distinction between Published vs Discovered
        );
      },
    );
  }
}
