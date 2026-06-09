import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
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
      backgroundColor: context.appColors.background,
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
                style: context.appTypography.body,
                cursorColor: context.appColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search channels and VOD…',
                  prefixIcon: Icon(Icons.search, color: context.appColors.textMuted),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: context.appColors.textMuted),
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
      return Center(
        child: CircularProgressIndicator(color: context.appColors.primary),
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
        color: context.appColors.surface,
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
                    color: context.appColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: stream.logo != null && stream.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            stream.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _initial(context, stream.name),
                          ),
                        )
                      : _initial(context, stream.name),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name,
                        style: context.appTypography.body.copyWith(
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
                        style: context.appTypography.micro,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.appColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _initial(BuildContext context, String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.appColors.textMuted,
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
          Icon(icon, color: context.appColors.textMuted, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: context.appTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: context.appTypography.caption),
        ],
      ),
    );
  }
}

/// Type-tinted badge shown next to each search result.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    switch (type) {
      case 'series':
        bg = context.appColors.primary.withOpacity(0.2);
        fg = context.appColors.primary;
        icon = Icons.tv;
        break;
      case 'vod':
        bg = context.appColors.accent.withOpacity(0.2);
        fg = context.appColors.accent;
        icon = Icons.movie;
        break;
      case 'live':
      default:
        bg = context.appColors.primary.withOpacity(0.2);
        fg = context.appColors.primary;
        icon = Icons.live_tv;
        break;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: fg, size: 18),
    );
  }
}
