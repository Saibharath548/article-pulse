import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:article_pulse/services/providers/guardian_rate_limiter.dart';
import 'package:article_pulse/services/rss_feed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianRateLimiter Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Acquire request increments daily count up to 500 max', () async {
      final limiter = GuardianRateLimiter();

      final initialRemaining = await limiter.getRemainingRequestsToday();
      expect(initialRemaining, 500);

      expect(await limiter.canMakeRequest(), isTrue);
    });
  });

  group('RssFeedService Tests', () {
    late RssFeedService rssService;

    setUp(() {
      rssService = RssFeedService();
    });

    test('Parses RSS 2.0 XML with title, link, and clean description', () {
      const sampleRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Quanta Magazine</title>
    <link>https://www.quantamagazine.org</link>
    <description>Illuminating science</description>
    <item>
      <title>The New Math of Black Holes</title>
      <link>https://www.quantamagazine.org/math-black-holes-2025/</link>
      <description>&lt;p&gt;Physicists have found a &lt;b&gt;novel symmetry&lt;/b&gt; in gravitational waves.&lt;/p&gt;</description>
      <dc:creator>Natalie Wolchover</dc:creator>
      <pubDate>Thu, 15 Jan 2026 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

      final articles = rssService.parseFeedXml(sampleRss, defaultCategory: 'Science');

      expect(articles.length, 1);
      final article = articles.first;
      expect(article.title, 'The New Math of Black Holes');
      expect(article.url, 'https://www.quantamagazine.org/math-black-holes-2025/');
      expect(article.sourceName, 'Quanta Magazine');
      expect(article.author, 'Natalie Wolchover');
      expect(article.description, contains('Physicists have found a novel symmetry in gravitational waves.'));
      expect(article.publishedAt.year, 2026);
      expect(article.publishedAt.month, 1);
    });

    test('Parses Atom XML with entry, summary, and author', () {
      const sampleAtom = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Ars Technica</title>
  <entry>
    <title>Quantum Sensors Break Resolution Records</title>
    <link href="https://arstechnica.com/science/2025/11/quantum-sensors/"/>
    <summary>Diamond-based defects allow nanoscale magnetic resonance imaging.</summary>
    <published>2025-11-20T10:30:00Z</published>
    <author>
      <name>John Timmer</name>
    </author>
  </entry>
</feed>''';

      final articles = rssService.parseFeedXml(sampleAtom, defaultCategory: 'Technology');

      expect(articles.length, 1);
      final article = articles.first;
      expect(article.title, 'Quantum Sensors Break Resolution Records');
      expect(article.url, 'https://arstechnica.com/science/2025/11/quantum-sensors/');
      expect(article.sourceName, 'Ars Technica');
      expect(article.author, 'John Timmer');
      expect(article.publishedAt.year, 2025);
    });
  });
}
