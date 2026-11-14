import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/library_providers.dart';
import '../../library/ui/track_actions.dart';

/// "Browse Music": debounced track search plus album/artist browsing.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _tab = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = QodiColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Browse Music',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: c.text)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search songs, artists, albums',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _Chip('Albums', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                const SizedBox(width: 8),
                _Chip('Artists', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
              ],
            ),
          ),
        Expanded(
          child: _query.isNotEmpty
              ? _SearchResults(query: _query)
              : _tab == 0
                  ? const _AlbumsGrid()
                  : const _ArtistsList(),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Material(
      color: selected ? QodiTokens.orange : c.card,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: selected ? Colors.white : c.text)),
        ),
      ),
    );
  }
}

Widget _error(Object e) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Something went wrong.\n$e', textAlign: TextAlign.center),
      ),
    );

const _loading = Center(child: CircularProgressIndicator(color: QodiTokens.orange));

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(searchTracksProvider(query)).when(
          data: (tracks) => tracks.isEmpty
              ? const Center(child: Text('No songs found'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: tracks.length,
                  itemBuilder: (_, i) => ConnectedTrackTile(track: tracks[i], queue: tracks, index: i),
                ),
          loading: () => _loading,
          error: (e, _) => _error(e),
        );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(albumsProvider).when(
          data: (albums) => albums.isEmpty
              ? const Center(child: Text('Your library is empty'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (_, i) => AlbumCard(albums[i]),
                ),
          loading: () => _loading,
          error: (e, _) => _error(e),
        );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard(this.album, {super.key});
  final Album album;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return GestureDetector(
      onTap: () => context.go('/explore/album/${album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArt(seed: album.id, trackId: album.coverTrackId, radius: QodiTokens.radiusL),
          ),
          const SizedBox(height: 8),
          Text(album.title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(album.artist,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ArtistsList extends ConsumerWidget {
  const _ArtistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    return ref.watch(artistsProvider).when(
          data: (artists) => ListView.builder(
            padding: const EdgeInsets.only(bottom: 24, top: 4),
            itemCount: artists.length,
            itemBuilder: (_, i) {
              final a = artists[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: CoverArt(seed: a.id, size: 48, circle: true, icon: Icons.person_rounded),
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${a.albumCount} albums • ${a.trackCount} songs',
                    style: TextStyle(color: c.textMuted)),
                onTap: () => context.go('/explore/artist/${a.id}'),
              );
            },
          ),
          loading: () => _loading,
          error: (e, _) => _error(e),
        );
  }
}
