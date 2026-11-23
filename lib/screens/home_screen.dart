import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_feed_provider.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HomeFeedProvider>();
      if (provider.isEmpty) {
        provider.loadFeed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<HomeFeedProvider>();
    final repo = context.read<ArticleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bubble_chart_outlined, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Article Pulse'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Discoveries',
            onPressed: provider.isLoading ? null : () => provider.loadFeed(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadFeed(forceRefresh: true),
        child: _buildBody(context, provider, repo),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeFeedProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (provider.isLoading && provider.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Gathering fresh discoveries...'),
          ],
        ),
      );
    }

    if (provider.errorMessage != null && provider.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Unable to reach live feeds',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                provider.errorMessage!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                onPressed: () => provider.loadFeed(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Daily Discovery Intro Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Discovery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Curated mix of fresh pulses, timeless archive discoveries (1–2 yrs ago), and random sparks across 12 subjects.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section 1: Fresh Pulses (Recent)
        if (provider.recentArticles.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Fresh Pulses',
            subtitle: 'Recently published informative articles',
            icon: Icons.bolt_outlined,
          ),
          ...provider.recentArticles.map(
            (article) => ArticleCard(
              article: article,
              onBookmarkToggle: () => provider.toggleBookmark(article),
              dbService: repo.db,
            ),
          ),
        ],

        // Section 2: Timeless Vault (Historical Discoveries 1-2 years ago)
        if (provider.olderArticles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(
            context,
            title: 'From the Vault',
            subtitle: 'Timeless discoveries published 1 to 2 years ago',
            icon: Icons.hourglass_bottom_outlined,
          ),
          ...provider.olderArticles.map(
            (article) => ArticleCard(
              article: article,
              onBookmarkToggle: () => provider.toggleBookmark(article),
              dbService: repo.db,
            ),
          ),
        ],

        // Section 3: Random Sparks
        if (provider.randomArticles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(
            context,
            title: 'Random Spark',
            subtitle: 'Surprise subjects from curious domains',
            icon: Icons.lightbulb_outline,
          ),
          ...provider.randomArticles.map(
            (article) => ArticleCard(
              article: article,
              onBookmarkToggle: () => provider.toggleBookmark(article),
              dbService: repo.db,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
