import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';
import 'bookmarks_history_screen.dart';
import 'category_screen.dart';
import 'home_screen.dart';
import 'live_articles_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdatesOnLaunch());
  }

  Future<void> _checkForUpdatesOnLaunch() async {
    try {
      if (!await AppUpdateService.getAutoCheckEnabled()) return;
      final update = await AppUpdateService().checkForUpdate();
      if (!mounted || update == null) return;
      await showAppUpdateDialog(context, update);
    } catch (_) {
      // Update checks are best-effort and must never block app startup.
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoryScreen(),
    LiveArticlesScreen(),
    SearchScreen(),
    BookmarksHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}
