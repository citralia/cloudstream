import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_service.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'vod_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focusNode.requestFocus();
  }

  void _openStream(SearchResult result) {
    final stream = result.stream;
    switch (result.type) {
      case 'vod':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VodDetailScreen(stream: stream),
          ),
        );
        break;
      case 'series':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(stream: stream),
          ),
        );
        break;
      case 'live':
      default:
        // Live channel — play directly.
        ref.read(selectedStreamProvider.notifier).state = stream;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final indexBuilt = ref.watch(searchIndexRebuilderProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onQueryChanged,
                style: AppTypography.body,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search channels and VOD…',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: _clear,
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),

            // Results.
            Expanded(
              child: _buildBody(query, results, indexBuilt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String query, List<SearchResult> results, AsyncValue<void> indexState) {
    // Index not yet built (streams not loaded).
    if (query.isEmpty) {
      return const _EmptyState(
        icon: Icons.search,
        title: 'Search for something',
        subtitle: 'Channels and VOD will appear here',
      );
    }

    // Still building index.
    if (indexState.isLoading || indexState.hasError) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing matches "$query"',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          onTap: () => _openStream(result),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = result.stream;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Type badge.
                _TypeBadge(type: result.type),
                const SizedBox(width: AppSpacing.md),
                // Channel logo or initial.
                Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: stream.logo != null && stream.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            stream.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _initial(stream.name),
                          ),
                        )
                      : _initial(stream.name),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.type == 'live'
                            ? 'Live TV'
                            : result.type == 'series'
                                ? 'Series'
                                : 'VOD',
                        style: AppTypography.micro,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _initial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// Type-tinted badge shown next to each search result.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  ({Color bg, Color fg, IconData icon}) get _style {
    switch (type) {
      case 'series':
        return (
          bg: AppColors.primary.withOpacity(0.2),
          fg: AppColors.primary,
          icon: Icons.tv,
        );
      case 'vod':
        return (
          bg: AppColors.accent.withOpacity(0.2),
          fg: AppColors.accent,
          icon: Icons.movie,
        );
      case 'live':
      default:
        return (
          bg: AppColors.primary.withOpacity(0.2),
          fg: AppColors.primary,
          icon: Icons.live_tv,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(style.icon, color: style.fg, size: 18),
    );
  }
}
