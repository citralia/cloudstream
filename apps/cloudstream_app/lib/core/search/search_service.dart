import '../network/xtream_client.dart';

/// A searchable stream result with type tag.
class SearchResult {
  final XtreamStream stream;
  final String type; // 'live' or 'vod'

  const SearchResult({required this.stream, required this.type});
}

/// In-memory search index over live + VOD streams.
/// Build time is O(n) where n = total streams; search is O(n) substring match.
/// Suitable for Firestick (<300ms for typical Xtream library sizes).
class SearchService {
  final List<XtreamStream> _live = [];
  final List<XtreamStream> _vod = [];
  bool _built = false;

  /// Rebuild the index from scratch. Call when streams change.
  void rebuild({
    required List<XtreamStream> live,
    required List<XtreamStream> vod,
  }) {
    _live.clear();
    _vod.clear();
    _live.addAll(live);
    _vod.addAll(vod.where((s) => s.streamType == 'movie'));
    _built = true;
  }

  /// Returns all matching streams whose name contains `query` (case-insensitive).
  /// Returns empty list if query is empty or index not yet built.
  List<SearchResult> search(String query) {
    if (!_built || query.isEmpty) return [];
    final q = query.toLowerCase();
    final results = <SearchResult>[];

    for (final s in _live) {
      if (s.name.toLowerCase().contains(q)) {
        results.add(SearchResult(stream: s, type: 'live'));
      }
    }
    for (final s in _vod) {
      if (s.name.toLowerCase().contains(q)) {
        results.add(SearchResult(stream: s, type: 'vod'));
      }
    }
    return results;
  }

  bool get isBuilt => _built;
  int get liveCount => _live.length;
  int get vodCount => _vod.length;
}
