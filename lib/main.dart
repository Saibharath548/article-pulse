import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/bookmarks_history_provider.dart';
import 'providers/category_provider.dart';
import 'providers/home_feed_provider.dart';
import 'providers/live_articles_provider.dart';
import 'providers/search_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/article_repository.dart';
import 'screens/main_screen.dart';
import 'services/database_service.dart';
import 'services/providers/crossref_search_provider.dart';
import 'services/providers/guardian_search_provider.dart';
import 'services/providers/hn_algolia_provider.dart';
import 'services/rss_feed_service.dart';
import 'services/secure_storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  final dbService = DatabaseService();
  final secureStorage = SecureStorageService();
  final rssService = RssFeedService();
  final guardianProvider = GuardianSearchProvider(secureStorage: secureStorage);
  final algoliaProvider = HnAlgoliaSearchProvider();
  final crossrefProvider = CrossrefSearchProvider();

  final articleRepository = ArticleRepository(
    dbService: dbService,
    secureStorage: secureStorage,
    rssService: rssService,
    guardianProvider: guardianProvider,
    algoliaProvider: algoliaProvider,
    crossrefProvider: crossrefProvider,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<ArticleRepository>.value(value: articleRepository),
        ChangeNotifierProvider(
          create: (_) => HomeFeedProvider(repository: articleRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(repository: articleRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => LiveArticlesProvider(repository: articleRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(repository: articleRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => BookmarksHistoryProvider(dbService: dbService),
        ),
      ],
      child: const ArticlePulseApp(),
    ),
  );
}

class ArticlePulseApp extends StatelessWidget {
  const ArticlePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Article Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const MainScreen(),
    );
  }
}
