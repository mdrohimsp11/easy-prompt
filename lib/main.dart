import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// GitHub রিপোজিটরির তথ্য
const repoOwner = 'mdrohimsp11';
const repoName = 'easy-prompt';
const mediaFolder = 'media';
const rawBase =
    'https://raw.githubusercontent.com/$repoOwner/$repoName/main/$mediaFolder';

// Privacy Policy ও যোগাযোগ
const privacyUrl = 'https://mdrohimsp11.github.io/easy-prompt/privacy.html';
const contactEmail = 'mdrohimsp33@gmail.com';

// বিজ্ঞাপন
// useTestAds = true হলে সবার জন্য টেস্ট বিজ্ঞাপন। এখন false = আসল বিজ্ঞাপন।
const useTestAds = false;
const testBannerId = 'ca-app-pub-3940256099942544/6300978111';
const testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
const realBannerId = 'ca-app-pub-7904413176110804/3467983938';
const realInterstitialId = 'ca-app-pub-7904413176110804/6793889385';

// মেনুতে About চেপে ধরলে এই ফোনে টেস্ট বিজ্ঞাপন চালু/বন্ধ হয়
bool testAdsOn = false;

String get bannerId => (useTestAds || testAdsOn) ? testBannerId : realBannerId;
String get interstitialId =>
    (useTestAds || testAdsOn) ? testInterstitialId : realInterstitialId;

// কত বার কপিতে একবার বিজ্ঞাপন আসবে (১ = প্রতিবার, ২ = প্রতি দ্বিতীয়বার)
const adEveryNCopies = 1;

class PromptItem {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final String videoUrl;
  final String prompt;

  const PromptItem({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.videoUrl,
    required this.prompt,
  });
}

const categories = ['All', 'Trending', 'Love', 'Cinematic'];

// media ফোল্ডার থেকে নিজে নিজে তালিকা বানায়।
// প্রতিটা ভিডিওর জন্য একই নামে .mp4, .jpg, .txt ফাইল লাগে।
class ItemsStore extends ChangeNotifier {
  List<PromptItem> items = [];
  bool loading = true;
  String? error;

  // ফাইলের নাম ও লিংকের তালিকা আনে
  Future<List<MapEntry<String, String>>> _listFiles() async {
    // ১) index.json (GitHub-এর সীমা নেই)
    try {
      final bust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final r = await http
          .get(Uri.parse('$rawBase/index.json?t=$bust'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final names = (jsonDecode(utf8.decode(r.bodyBytes)) as List)
            .map((e) => e.toString())
            .toList();
        return names
            .map((n) => MapEntry(n, '$rawBase/${Uri.encodeComponent(n)}'))
            .toList();
      }
    } catch (_) {}

    // ২) আগের পথ (GitHub API), index.json না পেলে
    final api = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/contents/$mediaFolder');
    final res = await http
        .get(api, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw 'GitHub error ${res.statusCode}';
    }
    final files = (jsonDecode(res.body) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final out = <MapEntry<String, String>>[];
    for (final f in files) {
      if (f['type'] != 'file') continue;
      final url = f['download_url'] as String?;
      if (url == null) continue;
      out.add(MapEntry(f['name'] as String, url));
    }
    return out;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final files = await _listFiles();

      final videos = <String, String>{};
      final images = <String, String>{};
      final texts = <String, String>{};
      for (final f in files) {
        final name = f.key;
        final url = f.value;
        final dot = name.lastIndexOf('.');
        if (dot <= 0) continue;
        final base = name.substring(0, dot);
        final ext = name.substring(dot + 1).toLowerCase();
        if (ext == 'mp4') {
          videos[base] = url;
        } else if (ext == 'jpg' ||
            ext == 'jpeg' ||
            ext == 'png' ||
            ext == 'webp') {
          images[base] = url;
        } else if (ext == 'txt') {
          texts[base] = url;
        }
      }

      final bases = videos.keys.toList()..sort((a, b) => b.compareTo(a));
      items = await Future.wait(
        bases.map((b) => _build(b, videos[b]!, images[b], texts[b])),
      );
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<PromptItem> _build(
      String base, String videoUrl, String? imageUrl, String? textUrl) async {
    var title = base
        .replaceFirst(RegExp(r'^\d+[-_]?'), '')
        .replaceAll(RegExp(r'[-_]'), ' ')
        .trim();
    if (title.isEmpty) title = base;
    var category = 'Trending';
    var prompt = '';
    if (textUrl != null) {
      try {
        final r = await http
            .get(Uri.parse(textUrl))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final text = utf8
              .decode(r.bodyBytes)
              .replaceAll('\r', '')
              .replaceFirst('\uFEFF', '');
          final lines = text.split('\n');
          if (lines.isNotEmpty && lines[0].trim().isNotEmpty) {
            title = lines[0].trim();
          }
          if (lines.length > 1) {
            final c = lines[1].trim().toLowerCase();
            for (final k in categories) {
              if (k != 'All' && k.toLowerCase() == c) category = k;
            }
          }
          if (lines.length > 2) {
            prompt = lines.sublist(2).join('\n').trim();
          }
        }
      } catch (_) {}
    }
    return PromptItem(
      id: base,
      title: title,
      category: category,
      imageUrl: imageUrl ?? '',
      videoUrl: videoUrl,
      prompt: prompt,
    );
  }
}

final itemsStore = ItemsStore();

class SavedStore extends ChangeNotifier {
  static const _key = 'saved_ids';
  final Set<String> _ids = {};

  Set<String> get ids => _ids;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? []);
    notifyListeners();
  }

  bool isSaved(String id) => _ids.contains(id);

  Future<void> toggle(String id) async {
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }
}

const kBg = Color(0xFF021A33);
const kCard = Color(0xFF0A2540);
const kAccent = Color(0xFF0D2F5E);

// পুরো পর্দার বিজ্ঞাপন। দেখানোর পর (বা বিজ্ঞাপন না থাকলে সাথে সাথে) onDone চলে।
class InterstitialHelper {
  static InterstitialAd? _ad;
  static bool _loading = false;
  static int _count = 0;

  static Future<void> load() async {
    if (_ad != null || _loading) return;
    _loading = true;
    try {
      await MobileAds.instance.initialize();
      await InterstitialAd.load(
        adUnitId: interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loading = false;
          },
          onAdFailedToLoad: (error) {
            _ad = null;
            _loading = false;
          },
        ),
      );
    } catch (_) {
      _loading = false;
    }
  }

  static void showThen(VoidCallback onDone) {
    _count++;
    if (_count % adEveryNCopies != 0) {
      onDone();
      return;
    }
    final ad = _ad;
    if (ad == null) {
      load();
      onDone();
      return;
    }
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        load();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        load();
        onDone();
      },
    );
    ad.show();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    testAdsOn = prefs.getBool('test_ads') ?? false;
  } catch (_) {}
  runApp(const EasyPromptApp());
}

class EasyPromptApp extends StatelessWidget {
  const EasyPromptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Prompt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: Colors.white),
        navigationBarTheme: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.all(
              const IconThemeData(color: Colors.white)),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ),
      home: const RootShell(),
    );
  }
}

class BannerAdBox extends StatefulWidget {
  const BannerAdBox({super.key});

  @override
  State<BannerAdBox> createState() => _BannerAdBoxState();
}

class _BannerAdBoxState extends State<BannerAdBox> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      color: kBg,
      width: double.infinity,
      height: ad.size.height.toDouble(),
      alignment: Alignment.center,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final store = SavedStore();
  int index = 0;

  @override
  void initState() {
    super.initState();
    store.load();
    itemsStore.load();
    InterstitialHelper.load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(store: store),
      SavedPage(store: store),
      const MenuPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: IndexedStack(index: index, children: pages)),
            const BannerAdBox(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kBg,
        indicatorColor: Colors.transparent,
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'Menu'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final SavedStore store;
  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String category = 'All';
  String query = '';
  bool searching = false;

  List<PromptItem> get filtered => itemsStore.items.where((p) {
        final catOk = category == 'All' || p.category == category;
        final qOk = query.isEmpty ||
            p.title.toLowerCase().contains(query.toLowerCase());
        return catOk && qOk;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: searching
                    ? TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                            hintText: 'Search prompts...',
                            border: InputBorder.none),
                        onChanged: (v) => setState(() => query = v),
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Easy Prompt',
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                          Text('Trending AI Video Prompts',
                              style: TextStyle(color: Colors.white60)),
                        ],
                      ),
              ),
              IconButton(
                icon: Icon(searching ? Icons.close : Icons.search, size: 30),
                onPressed: () => setState(() {
                  searching = !searching;
                  if (!searching) query = '';
                }),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = categories[i];
              final selected = c == category;
              return GestureDetector(
                onTap: () => setState(() => category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? kAccent : kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : Colors.white70)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: itemsStore,
            builder: (_, __) {
              if (itemsStore.loading && itemsStore.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (itemsStore.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemsStore.error == null
                            ? 'এখনো কোনো ভিডিও নেই'
                            : 'লোড করা যায়নি\n${itemsStore.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: itemsStore.load,
                        child: const Text('আবার চেষ্টা করুন'),
                      ),
                    ],
                  ),
                );
              }
              return PromptGrid(items: filtered, store: widget.store);
            },
          ),
        ),
      ],
    );
  }
}

class PromptGrid extends StatelessWidget {
  final List<PromptItem> items;
  final SavedStore store;
  const PromptGrid({super.key, required this.items, required this.store});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('কিছু পাওয়া যায়নি'));
    }
    return RefreshIndicator(
      onRefresh: itemsStore.load,
      child: AnimatedBuilder(
        animation: store,
        builder: (_, __) => GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 16,
            childAspectRatio: 0.66,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => PromptCard(item: items[i], store: store),
        ),
      ),
    );
  }
}

class PromptCard extends StatelessWidget {
  final PromptItem item;
  final SavedStore store;
  const PromptCard({super.key, required this.item, required this.store});

  @override
  Widget build(BuildContext context) {
    final saved = store.isSaved(item.id);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailPage(item: item, store: store)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: kCard,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl.isEmpty
                        ? const ColoredBox(color: Colors.black26)
                        : Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.black26),
                          ),
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0xAA0A2540),
                        child: Icon(Icons.play_arrow,
                            size: 32, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xAA0A2540),
                        child: IconButton(
                          icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border),
                          onPressed: () => store.toggle(item.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedPage extends StatelessWidget {
  final SavedStore store;
  const SavedPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, itemsStore]),
      builder: (_, __) {
        final saved =
            itemsStore.items.where((p) => store.isSaved(p.id)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text('Saved',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: saved.isEmpty
                  ? const Center(child: Text('এখনো কিছু সেভ করা হয়নি'))
                  : PromptGrid(items: saved, store: store),
            ),
          ],
        );
      },
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  Future<void> _openPrivacy(BuildContext context) async {
    try {
      final ok = await launchUrl(Uri.parse(privacyUrl),
          mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লিংক খোলা যায়নি')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Text('Menu',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        ),
        const ListTile(
            leading: Icon(Icons.star_border), title: Text('Rate app')),
        const ListTile(leading: Icon(Icons.share), title: Text('Share app')),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          onTap: () => _openPrivacy(context),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Easy Prompt',
            applicationVersion: '1.0.0',
            children: const [
              SizedBox(height: 12),
              Text('Trending AI video prompts.'),
              SizedBox(height: 8),
              Text('Contact: $contactEmail'),
            ],
          ),
          // গোপন সুইচ: চেপে ধরলে এই ফোনে টেস্ট বিজ্ঞাপন চালু/বন্ধ হয়
          onLongPress: () async {
            final prefs = await SharedPreferences.getInstance();
            final on = !(prefs.getBool('test_ads') ?? false);
            await prefs.setBool('test_ads', on);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(on
                    ? 'Test ads ON (অ্যাপ বন্ধ করে আবার খুলুন)'
                    : 'Test ads OFF (অ্যাপ বন্ধ করে আবার খুলুন)')));
          },
        ),
      ],
    );
  }
}

class DetailPage extends StatefulWidget {
  final PromptItem item;
  final SavedStore store;
  const DetailPage({super.key, required this.item, required this.store});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final VideoPlayerController controller;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.item.videoUrl));
    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      }
    }).catchError((Object e) {
      if (mounted) setState(() => failed = true);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _copyPrompt() {
    // আগে বিজ্ঞাপন, বিজ্ঞাপন শেষ হলে কপি
    InterstitialHelper.showThen(() {
      Clipboard.setData(ClipboardData(text: widget.item.prompt));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompt কপি হয়েছে')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Prompt'),
        actions: [
          AnimatedBuilder(
            animation: widget.store,
            builder: (_, __) => IconButton(
              icon: Icon(widget.store.isSaved(item.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border),
              onPressed: () => widget.store.toggle(item.id),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: controller.value.isInitialized
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: controller.value.isInitialized
                  ? GestureDetector(
                      onTap: () => setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      }),
                      child: VideoPlayer(controller),
                    )
                  : failed
                      ? const Center(child: Text('ভিডিও লোড হয়নি'))
                      : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 16),
          Text(item.title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(12)),
            child: Text(item.prompt, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
      // কপি বাটন নিচে স্থির থাকে, প্রম্পট যত লম্বাই হোক
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Prompt'),
            onPressed: _copyPrompt,
          ),
        ),
      ),
    );
  }
}
