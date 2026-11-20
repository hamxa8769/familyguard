import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class GalleryModule implements FeatureModule {
  @override
  String get id => 'gallery';
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  String get title => 'Photos';
  @override
  String get description => 'Albums on the child\'s device';
  @override
  IconData get icon => Icons.photo_library_outlined;
  @override
  Widget buildScreen(BuildContext context) => const GalleryViewScreen();
}

class _GalleryData {
  _GalleryData(this.previews, this.items);
  final bool previews;
  final List<MediaFile> items;

  List<MediaFile> get photos => items.where((i) => i.isImage).toList();

  /// Albums (folders) newest first, each with its photos newest first.
  List<(String, List<MediaFile>)> get albums {
    final map = <String, List<MediaFile>>{};
    for (final p in photos) {
      map.putIfAbsent(p.albumLabel, () => []).add(p);
    }
    final out = map.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.first.dateMillis.compareTo(a.$2.first.dateMillis));
    return out;
  }
}

class GalleryViewScreen extends StatelessWidget {
  const GalleryViewScreen({super.key});

  static Future<_GalleryData> _load(String deviceId) async {
    final res = await ParentState.instance.api.get('/api/files/$deviceId');
    final items = (res['items'] as List)
        .map((e) => MediaFile.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
    return _GalleryData(res['previews'] == true, items);
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Photos',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: ApiView<_GalleryData>(
          load: () => _load(deviceId),
          builder: (context, data, reload) =>
              _Albums(deviceId: deviceId, data: data, reload: reload),
        ),
      ),
    );
  }
}

class _Albums extends StatelessWidget {
  const _Albums(
      {required this.deviceId, required this.data, required this.reload});
  final String deviceId;
  final _GalleryData data;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final albums = data.albums;
    final ready = data.photos.where((p) => p.hasThumb).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(FgSpace.lg),
          sliver: SliverToBoxAdapter(
            child: _PreviewsCard(
              deviceId: deviceId,
              on: data.previews,
              ready: ready,
              total: data.photos.length,
              onChanged: reload,
            ),
          ),
        ),
        if (data.photos.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(FgSpace.xl),
              child: Text('No photos shared yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted)),
            ),
          )
        else ...[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: FgSpace.lg),
            sliver: SliverToBoxAdapter(child: SectionLabel('Albums')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                FgSpace.lg, 0, FgSpace.lg, FgSpace.xl),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: FgSpace.md,
                crossAxisSpacing: FgSpace.md,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildListDelegate([
                _AlbumTile(
                  deviceId: deviceId,
                  name: 'All photos',
                  photos: data.photos,
                ),
                for (final (name, photos) in albums)
                  _AlbumTile(deviceId: deviceId, name: name, photos: photos),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Parent's opt-in for photo previews, with what it means for the child.
class _PreviewsCard extends StatefulWidget {
  const _PreviewsCard({
    required this.deviceId,
    required this.on,
    required this.ready,
    required this.total,
    required this.onChanged,
  });

  final String deviceId;
  final bool on;
  final int ready;
  final int total;
  final VoidCallback onChanged;

  @override
  State<_PreviewsCard> createState() => _PreviewsCardState();
}

class _PreviewsCardState extends State<_PreviewsCard> {
  bool _busy = false;

  Future<void> _set(bool value) async {
    if (!value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn off photo previews?'),
          content: const Text(
              'All previews stored for this device will be deleted.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Turn off')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final saved = await saveWithFeedback(
      context,
      () => ParentState.instance.api.put(
          '/api/files/${widget.deviceId}/settings', {'previews': value}),
      value
          ? 'Previews on — they appear after the child\'s next sync'
          : 'Previews off and deleted',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return FgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(Icons.image_search_rounded,
                  color: widget.on ? c.accent : c.textMuted),
              const SizedBox(width: FgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Photo previews',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      widget.on
                          ? '${widget.ready} of ${widget.total < 100 ? widget.total : 100} previews ready'
                          : 'Off — only names, dates and albums are shared',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.on,
                onChanged: _busy ? null : _set,
              ),
            ],
          ),
          const SizedBox(height: FgSpace.sm),
          Text(
            'Small previews of the newest 100 photos. Your child is told this '
            'in the app and can see it in "What my parent sees". Turning it '
            'off deletes all previews.',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile(
      {required this.deviceId, required this.name, required this.photos});
  final String deviceId;
  final String name;
  final List<MediaFile> photos;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final covers = photos.where((p) => p.hasThumb).take(4).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(FgSpace.radius),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            _AlbumScreen(deviceId: deviceId, name: name, photos: photos),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FgSpace.radius),
              child: Container(
                color: c.surfaceHigh,
                child: covers.isEmpty
                    ? Center(
                        child: Icon(Icons.photo_library_outlined,
                            size: 40, color: c.textMuted))
                    : covers.length < 4
                        ? ThumbImage(deviceId: deviceId, file: covers.first)
                        : GridView.count(
                            crossAxisCount: 2,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            children: [
                              for (final p in covers)
                                ThumbImage(deviceId: deviceId, file: p),
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${photos.length} photo${photos.length == 1 ? '' : 's'}',
              style: TextStyle(color: c.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AlbumScreen extends StatelessWidget {
  const _AlbumScreen(
      {required this.deviceId, required this.name, required this.photos});
  final String deviceId;
  final String name;
  final List<MediaFile> photos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                _PhotoViewer(deviceId: deviceId, photos: photos, index: i),
          )),
          child: ThumbImage(deviceId: deviceId, file: photos[i]),
        ),
      ),
    );
  }
}

/// Swipe through previews with name, album, size and date.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer(
      {required this.deviceId, required this.photos, required this.index});
  final String deviceId;
  final List<MediaFile> photos;
  final int index;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _page = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.photos[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(f.name, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => InteractiveViewer(
                child: Center(
                  child: ThumbImage(
                    deviceId: widget.deviceId,
                    file: widget.photos[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(FgSpace.lg),
            child: Text(
              '${f.albumLabel} · ${f.sizeLabel} · ${timeAgo(f.date)}\n'
              'Preview only — the original photo stays on the device.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads a preview through the authenticated API (cached in memory).
class ThumbImage extends StatefulWidget {
  const ThumbImage({
    super.key,
    required this.deviceId,
    required this.file,
    this.fit = BoxFit.cover,
  });

  final String deviceId;
  final MediaFile file;
  final BoxFit fit;

  static final Map<String, Uint8List> _cache = {};

  @override
  State<ThumbImage> createState() => _ThumbImageState();
}

class _ThumbImageState extends State<ThumbImage> {
  Uint8List? _bytes;
  bool _failed = false;

  String get _id => '${widget.deviceId}/${widget.file.key}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ThumbImage old) {
    super.didUpdateWidget(old);
    if (old.file.key != widget.file.key) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.file.hasThumb) return;
    final cached = ThumbImage._cache[_id];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final b = await ParentState.instance.api.getBytes(
          '/api/files/${widget.deviceId}/thumb/${Uri.encodeComponent(widget.file.key)}');
      if (ThumbImage._cache.length > 300) ThumbImage._cache.clear();
      ThumbImage._cache[_id] = b;
      if (mounted) setState(() => _bytes = b);
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    if (_bytes != null) {
      return Image.memory(_bytes!,
          fit: widget.fit, gaplessPlayback: true, width: double.infinity,
          height: double.infinity);
    }
    if (widget.file.hasThumb && !_failed) {
      return const Skeleton(height: double.infinity, radius: 0);
    }
    return Container(
      color: c.surfaceHigh,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: c.textMuted),
          const SizedBox(height: 4),
          Text(widget.file.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: c.textMuted)),
        ],
      ),
    );
  }
}
