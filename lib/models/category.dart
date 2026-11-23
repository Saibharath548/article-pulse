import 'package:flutter/material.dart';

/// Represents a browseable topic category in Article Pulse.
/// Designed for extensibility so new categories can be registered seamlessly.
class ArticleCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<String> searchKeywords;
  final List<String> feedUrls;
  final String defaultProviderHint; // 'crossref', 'algolia', 'guardian', etc.

  const ArticleCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.searchKeywords,
    required this.feedUrls,
    required this.defaultProviderHint,
  });

  static const List<ArticleCategory> initialCategories = [
    ArticleCategory(
      id: 'game_dev',
      name: 'Game Development',
      description: 'Game design, engine programming, graphics, mechanics, and indie development.',
      icon: Icons.sports_esports_outlined,
      searchKeywords: ['game development', 'game design', 'unity', 'unreal engine', 'indie game', 'graphics programming'],
      feedUrls: [
        'https://gamedeveloper.com/rss.xml',
        'https://kotaku.com/rss',
      ],
      defaultProviderHint: 'algolia',
    ),
    ArticleCategory(
      id: 'geopolitics',
      name: 'Geopolitics',
      description: 'International relations, foreign policy, diplomacy, global security, conflicts, and the forces shaping world affairs.',
      icon: Icons.public_outlined,
      searchKeywords: [
        'geopolitics',
        'international relations',
        'foreign policy',
        'diplomacy',
        'global security',
        'armed conflict',
        'international sanctions',
        'global trade',
        'great power competition',
      ],
      feedUrls: [
        'https://feeds.bbci.co.uk/news/world/rss.xml',
        'https://www.theguardian.com/world/rss',
        'https://www.aljazeera.com/xml/rss/all.xml',
      ],
      defaultProviderHint: 'algolia',
    ),
    ArticleCategory(
      id: 'technology',
      name: 'Technology',
      description: 'Software engineering, open-source, cybersecurity, hardware, and digital trends.',
      icon: Icons.computer_outlined,
      searchKeywords: ['technology', 'software engineering', 'open source', 'hardware', 'cybersecurity'],
      feedUrls: [
        'https://arstechnica.com/feed/',
        'https://techcrunch.com/feed/',
      ],
      defaultProviderHint: 'algolia',
    ),
    ArticleCategory(
      id: 'science',
      name: 'Science',
      description: 'Astrophysics, biology, quantum mechanics, earth sciences, and exploration.',
      icon: Icons.biotech_outlined,
      searchKeywords: ['physics', 'astronomy', 'biology', 'quantum', 'neuroscience'],
      feedUrls: [
        'https://api.quantamagazine.org/feed/',
        'https://phys.org/rss-feed/',
      ],
      defaultProviderHint: 'crossref',
    ),
    ArticleCategory(
      id: 'psychology',
      name: 'Psychology',
      description: 'Cognitive science, human behavior, emotional intelligence, and perception.',
      icon: Icons.psychology_outlined,
      searchKeywords: ['psychology', 'cognitive science', 'neuroscience', 'mental health', 'behavioral economics'],
      feedUrls: [
        'https://psyche.co/feed',
      ],
      defaultProviderHint: 'crossref',
    ),
    ArticleCategory(
      id: 'gov_politics',
      name: 'Government and Politics',
      description: 'Public policy, governance, constitutional law, international diplomacy, and civic systems.',
      icon: Icons.account_balance_outlined,
      searchKeywords: ['governance', 'public policy', 'democracy', 'international relations', 'geopolitics'],
      feedUrls: [
        'https://www.theguardian.com/politics/rss',
      ],
      defaultProviderHint: 'guardian',
    ),
    ArticleCategory(
      id: 'society',
      name: 'Society and Social Issues',
      description: 'Culture, community dynamics, education, urbanism, and ethical questions.',
      icon: Icons.groups_outlined,
      searchKeywords: ['society', 'sociology', 'education', 'urban planning', 'ethics'],
      feedUrls: [
        'https://aeon.co/feed.rss',
      ],
      defaultProviderHint: 'crossref',
    ),
    ArticleCategory(
      id: 'history',
      name: 'History',
      description: 'Ancient civilizations, world milestones, archaeology, and historical archives.',
      icon: Icons.history_edu_outlined,
      searchKeywords: ['ancient history', 'archaeology', 'world war', 'renaissance', 'civilization'],
      feedUrls: [
        'https://www.theguardian.com/culture/rss',
      ],
      defaultProviderHint: 'guardian',
    ),
    ArticleCategory(
      id: 'business',
      name: 'Business and Economics',
      description: 'Economic theories, markets, entrepreneurship, macro trends, and trade.',
      icon: Icons.trending_up_outlined,
      searchKeywords: ['economics', 'macroeconomics', 'markets', 'startups', 'finance'],
      feedUrls: [
        'https://www.economist.com/finance-and-economics/rss.xml',
      ],
      defaultProviderHint: 'crossref',
    ),
    ArticleCategory(
      id: 'ai',
      name: 'Artificial Intelligence',
      description: 'Machine learning, neural networks, LLMs, computer vision, and AI ethics.',
      icon: Icons.auto_awesome_outlined,
      searchKeywords: ['artificial intelligence', 'machine learning', 'deep learning', 'large language models', 'neural networks'],
      feedUrls: [
        'https://www.technologyreview.com/feed/',
      ],
      defaultProviderHint: 'algolia',
    ),
    ArticleCategory(
      id: 'environment',
      name: 'Environment',
      description: 'Climate science, renewable energy, ecology, biodiversity, and conservation.',
      icon: Icons.eco_outlined,
      searchKeywords: ['climate change', 'renewable energy', 'biodiversity', 'ecology', 'conservation'],
      feedUrls: [
        'https://www.theguardian.com/environment/rss',
      ],
      defaultProviderHint: 'crossref',
    ),
    ArticleCategory(
      id: 'general_knowledge',
      name: 'General Knowledge',
      description: 'Curious trivia, interdisciplinary ideas, linguistics, and philosophy.',
      icon: Icons.lightbulb_outline,
      searchKeywords: ['philosophy', 'linguistics', 'general science', 'discovery'],
      feedUrls: [
        'https://aeon.co/feed.rss',
      ],
      defaultProviderHint: 'algolia',
    ),
  ];

  static ArticleCategory byId(String id) {
    return initialCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => initialCategories.last,
    );
  }

  static ArticleCategory byName(String name) {
    final lower = name.toLowerCase().trim();
    return initialCategories.firstWhere(
      (c) => c.name.toLowerCase() == lower || c.id.toLowerCase() == lower,
      orElse: () => initialCategories.last,
    );
  }
}
