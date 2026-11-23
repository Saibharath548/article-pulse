import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/article_repository.dart';
import '../services/providers/guardian_rate_limiter.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _guardianKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _hasSavedKey = false;
  int _remainingRequests = 500;
  bool _isSaving = false;
  bool _autoCheckUpdates = true;
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _guardianKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final repo = context.read<ArticleRepository>();
    final key = await repo.secureStorage.getGuardianApiKey();
    final limiter = GuardianRateLimiter();
    final remaining = await limiter.getRemainingRequestsToday();
    final autoCheckUpdates = await AppUpdateService.getAutoCheckEnabled();

    if (mounted) {
      setState(() {
        if (key != null && key.isNotEmpty) {
          _guardianKeyController.text = key;
          _hasSavedKey = true;
        }
        _remainingRequests = remaining;
        _autoCheckUpdates = autoCheckUpdates;
      });
    }
  }

  Future<void> _saveGuardianKey() async {
    final repo = context.read<ArticleRepository>();
    final key = _guardianKeyController.text.trim();

    setState(() => _isSaving = true);
    await repo.secureStorage.saveGuardianApiKey(key);
    setState(() {
      _hasSavedKey = key.isNotEmpty;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isNotEmpty
              ? 'Guardian API key saved securely in Android Keystore.'
              : 'Guardian API key removed.'),
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    final repo = context.read<ArticleRepository>();
    await repo.db.clearNonBookmarkedCache();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non-bookmarked article cache cleared.')),
      );
    }
  }

  Future<void> _setAutoCheckUpdates(bool enabled) async {
    setState(() => _autoCheckUpdates = enabled);
    await AppUpdateService.setAutoCheckEnabled(enabled);
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdates = true);
    try {
      final update = await AppUpdateService().checkForUpdate(force: true);
      if (!mounted) return;

      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No newer APK release is available.')),
        );
      } else {
        await showAppUpdateDialog(context, update);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check for updates: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader('Appearance'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Theme'),
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Theme'),
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Search Providers & API Keys
          _buildSectionHeader('Optional Search Provider: The Guardian API'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_outlined, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Stored via flutter_secure_storage',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Guardian developer tier allows 500 requests per day (1 req/sec). Free keys can be obtained instantly from open-platform.theguardian.com/access/.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),

                  // API Key Input
                  TextField(
                    controller: _guardianKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Guardian Developer API Key',
                      hintText: 'e.g. test or your-guid-key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quota Info Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Remaining Quota Today: $_remainingRequests / 500 requests',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: Text(_isSaving ? 'Saving...' : 'Save Key'),
                        onPressed: _isSaving ? null : _saveGuardianKey,
                      ),
                      if (_hasSavedKey) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Clear Key'),
                          onPressed: () {
                            _guardianKeyController.clear();
                            _saveGuardianKey();
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section: Local Storage & Offline Cache
          _buildSectionHeader('Storage & Offline Cache'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear Non-Bookmarked Cache'),
                  subtitle: const Text('Frees space while keeping all bookmarks and reading history intact.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: App Updates
          _buildSectionHeader('App Updates'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.system_update_outlined),
                  title: const Text('Check for updates automatically'),
                  subtitle: const Text('Check GitHub Releases when Article Pulse opens.'),
                  value: _autoCheckUpdates,
                  onChanged: _setAutoCheckUpdates,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Check now'),
                  subtitle: const Text('Look for the latest APK on GitHub.'),
                  trailing: _isCheckingUpdates
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isCheckingUpdates ? null : _checkForUpdates,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: About
          _buildSectionHeader('About Article Pulse'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Article Pulse v1.1.0',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A distraction-free, personal article discovery application designed to cultivate knowledge instead of doom-scrolling.\n\n'
                    '• Zero commercial AI or paid dependencies required.\n'
                    '• Multi-provider historical search covering 2+ years of archives.\n'
                    '• Local SQLite storage for offline bookmarks and reading history.\n'
                    '• Full publisher attribution and direct external article links.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
