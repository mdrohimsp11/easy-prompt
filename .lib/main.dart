import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

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

const _sampleVideo =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

const allItems = <PromptItem>[
  PromptItem(
    id: '1',
    title: 'Trending AI Walk Couple Video Editing',
    category: 'Trending',
    imageUrl: 'https://picsum.photos/seed/walk/400/600',
    videoUrl: _sampleVideo,
    prompt: 'A couple walking on a lit-up street at night, cinematic, 4k...',
  ),
  PromptItem(
    id: '2',
    title: 'Miniature food making video prompt',
    category: 'Cinematic',
    imageUrl: 'https://picsum.photos/seed/food/400/600',
    videoUrl: _sampleVideo,
    prompt: 'Tiny chefs cooking a giant dosa on a pan, macro shot...',
  ),
  PromptItem(
    id: '3',
    title: 'Family dinner nostalgic scene',
    category: 'Love',
    imageUrl: 'https://picsum.photos/seed/family/400/600',
    videoUrl: _sampleVideo,
    prompt: 'A warm family dinner in a traditional kitchen, soft light...',
  ),
  PromptItem(
    id: '4',
    title: 'Tiny chefs and the giant dosa',
    category: 'Trending',
    imageUrl: 'https://picsum.photos/seed/chefs/400/600',
    videoUrl: _sampleVideo,
    prompt: 'Miniature chefs around a huge dosa, steam rising, 3D style...',
  ),
];

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      ),
      home: const RootShell(),
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
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(store: store),
      SavedPage(store: store),
      const MenuPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
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

  List<PromptItem> get filtered => allItems.where((p) {
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
        Expanded(child: PromptGrid(items: filtered, store: widget.store)),
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
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.66,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => PromptCard(item: items[i], store: store),
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
                    Image.network(
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
      animation: store,
      builder: (_, __) {
        final saved = allItems.where((p) => store.isSaved(p.id)).toList();
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Text('Menu',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        ),
        ListTile(leading: Icon(Icons.star_border), title: Text('Rate app')),
        ListTile(leading: Icon(Icons.share), title: Text('Share app')),
        ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy Policy')),
        ListTile(leading: Icon(Icons.info_outline), title: Text('About')),
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

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller
            ..setLooping(true)
            ..play();
        }
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Prompt'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.prompt));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prompt কপি হয়েছে')));
            },
          ),
        ],
      ),
    );
  }
}
