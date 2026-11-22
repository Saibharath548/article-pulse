import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/search_provider.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<SearchProvider>();
      if (!provider.isLoading && !provider.isLoadingMore && provider.hasMore) {
        provider.loadNextPage();
      }
    }
  }

  void _executeSearch(BuildContext context) {
    FocusScope.of(context).unfocus();
    final provider = context.read<SearchProvider>();
    provider.setQuery(_textController.text.trim());
    provider.search(newSearch: true);
  }

  Future<void> _pickDateRange(BuildContext context, SearchProvider provider) async {
    final now = DateTime.now();
    final earliest = DateTime(2000, 1, 1);
    final initialRange = DateTimeRange(
      start: provider.fromDate ?? now.subtract(const Duration(days: 730)),
      end: provider.toDate ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: now,
      initialDateRange: initialRange,
      helpText: 'Select Historical Date Window (2+ Years Supported)',
    );

    if (picked != null) {
      provider.setDateRange(picked.start, picked.end);
      if (_textController.text.trim().isNotEmpty || provider.category != null) {
        provider.search(newSearch: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SearchProvider>();
    final repo = context.read<ArticleRepository>();

    final dateFormat = DateFormat('MMM yyyy');
    final fromStr = provider.fromDate != null ? dateFormat.format(provider.fromDate!) : 'Any';
    final toStr = provider.toDate != null ? dateFormat.format(provider.toDate!) : 'Present';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Search'),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Search keywords, topics, authors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _textController.clear();
                          provider.setQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _executeSearch(context),
            ),
          ),

          // Filters Row: Date Range & Sort Order
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Historical Date Range Picker Button
                  ActionChip(
                    avatar: const Icon(Icons.date_range_outlined, size: 16),
                    label: Text('$fromStr – $toStr (2+ Yrs)'),
                    onPressed: () => _pickDateRange(context, provider),
                  ),
                  const SizedBox(width: 8),

                  // Sort By Newest / Oldest
                  ActionChip(
                    avatar: Icon(
                      provider.sortByNewest ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16,
                    ),
                    label: Text(provider.sortByNewest ? 'Newest First' : 'Oldest First'),
                    onPressed: () {
                      provider.setSortByNewest(!provider.sortByNewest);
                      if (provider.articles.isNotEmpty) {
                        provider.search(newSearch: true);
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Category Filter Dropdown
                  DropdownButton<String?>(
                    value: provider.category,
                    hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
                    isDense: true,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...ArticleCategory.initialCategories.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.name,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      provider.setCategory(val);
                      if (_textController.text.trim().isNotEmpty) {
                        provider.search(newSearch: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Provider Coverage & Limitation Banner
          if (provider.coverageNotice.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.coverageNotice,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Search Results List
          Expanded(
            child: _buildResultsList(context, provider, repo),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, SearchProvider provider, ArticleRepository repo) {
    final theme = Theme.of(context);

    if (provider.isLoading && provider.articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching historical archive (covering 2+ years)...'),
          ],
        ),
      );
    }

    if (provider.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_outlined, size: 54, color: theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'Historical Discovery',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Search articles across the previous two years and beyond (2024–2026). Enter a topic, author, or keyword above.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: provider.articles.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.articles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

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
