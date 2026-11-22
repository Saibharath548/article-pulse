import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CategoryProvider>();
      if (provider.articles.isEmpty) {
        provider.selectCategory(provider.selectedCategory);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<CategoryProvider>();
    final repo = context.read<ArticleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Categories'),
      ),
      body: Column(
        children: [
          // Category Selector Chips (All 11 Categories)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ArticleCategory.initialCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = ArticleCategory.initialCategories[index];
                final isSelected = cat.id == provider.selectedCategory.id;

                return FilterChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                  ),
                  label: Text(cat.name),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      provider.selectCategory(cat);
                    }
                  },
                );
              },
            ),
          ),

          // Active Category Description Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(provider.selectedCategory.icon, size: 24, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.selectedCategory.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.selectedCategory.description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Article List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.selectCategory(provider.selectedCategory, forceRefresh: true),
              child: _buildList(context, provider, repo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, CategoryProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);

    if (provider.isLoading && provider.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.orange),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => provider.selectCategory(provider.selectedCategory, forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.articles.isEmpty) {
      return Center(
        child: Text(
          'No articles found for ${provider.selectedCategory.name}. Pull to refresh.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: provider.articles.length,
      itemBuilder: (context, index) {
        final article = provider.articles[index];
        return ArticleCard(
          article: article,
          onBookmarkToggle: () => provider.toggleBookmark(article),
          dbService: repo.db,
        );
      },
    );
  }
}
