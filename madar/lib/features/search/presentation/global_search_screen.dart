import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/search_engine.dart';
import '../data/search_providers.dart';
import '../domain/search_doc.dart';
import '../domain/search_results.dart';
import 'search_result_tile.dart';
import 'search_visuals.dart';

/// Global search: one field over every module. Results appear as you type,
/// grouped by module with their counts; chips filter by planet, then by
/// module. With the field empty it shows the recent searches.
///
/// Keyboard: ↑ / ↓ move through the results, Enter opens the selected one
/// (the first by default), Esc clears the field (or leaves when empty).
///
/// A result opens through [onOpen], else `searchOpenerProvider`; when
/// neither handles it a short note says it can't be opened from here yet.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key, this.initialQuery = '', this.onOpen, this.autofocus = true});

  final String initialQuery;
  final SearchOpener? onOpen;
  final bool autofocus;

  /// The screen as a route (fade-through).
  static Route<void> route({String initialQuery = '', SearchOpener? onOpen}) => PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'search'),
    pageBuilder: (_, _, _) => GlobalSearchScreen(initialQuery: initialQuery, onOpen: onOpen),
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.medium,
    transitionsBuilder: MadarTransitions.fadeThroughTransitions,
  );

  /// Pushes the screen on [context]'s navigator.
  static Future<void> open(BuildContext context, {String initialQuery = '', SearchOpener? onOpen}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(route(initialQuery: initialQuery, onOpen: onOpen));
  }

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  final FocusNode _field = FocusNode(debugLabel: 'search field');
  final ScrollController _scroll = ScrollController();

  /// Delay after a keystroke before the query runs.
  static const Duration _typingDebounce = Duration(milliseconds: 90);

  SearchEngine? _engine;
  StreamSubscription<int>? _changes;
  SearchEngineStatus _status = SearchEngineStatus.idle;
  Timer? _debounce;
  int _seq = 0;
  SearchResults? _results;
  String? _planet;
  String? _group;

  /// Results in display order (keyboard selection runs over them).
  List<SearchHit> _visible = const [];
  int _selected = 0;
  bool _keyboard = false;
  final Map<String, GlobalKey> _tileKeys = {};

  /// The kind of content shown (recent searches, results …) and a serial
  /// that changes with it: the cross-fade keys its children by the serial,
  /// so a kind that comes back while its old self is still fading out
  /// (a letter, backspace, the letter again) is a new child, not a
  /// duplicate key.
  Type? _contentType;
  int _contentSerial = 0;

  @override
  void initState() {
    super.initState();
    _attach(ref.read(searchEngineProvider));
    ref.listenManual(searchEngineProvider, (_, next) => _attach(next));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_changes?.cancel());
    _detachStatus();
    _query.dispose();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _detachStatus() {
    try {
      _engine?.status.removeListener(_onStatus);
    } on Object {
      // The engine was already disposed.
    }
  }

  void _attach(SearchEngine engine) {
    if (identical(engine, _engine)) return;
    unawaited(_changes?.cancel());
    _detachStatus();
    _engine = engine;
    _status = engine.status.value;
    engine.status.addListener(_onStatus);
    _changes = engine.changes.listen((_) => _run(keepSelection: true));
    unawaited(engine.warmUp());
    if (_query.text.trim().isNotEmpty) unawaited(_run());
  }

  void _onStatus() {
    final s = _engine?.status.value;
    if (s == null || !mounted) return;
    setState(() => _status = s);
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_typingDebounce, _run);
    setState(() {}); // the clear button
  }

  Future<void> _run({bool keepSelection = false}) async {
    final engine = _engine;
    if (engine == null) return;
    final text = _query.text;
    final seq = ++_seq;
    if (text.trim().isEmpty) {
      if (_results != null && mounted) setState(() => _results = null);
      return;
    }
    final request = SearchRequest(
      text,
      planets: {?_planet},
      groups: {?_group},
      limit: _group == null ? 120 : 300,
    );
    final results = await engine.search(request);
    // Stale: a newer query ran, or the text changed (typed on, cleared).
    if (!mounted || seq != _seq || _query.text != text) return;
    setState(() {
      _results = results;
      if (!keepSelection) {
        _selected = 0;
        _keyboard = false;
      }
      final keys = {for (final h in results.hits) h.doc.indexKey};
      _tileKeys.removeWhere((k, _) => !keys.contains(k));
    });
  }

  void _setFilter(String? planet, String? group) {
    if (planet == _planet && group == _group) return;
    setState(() {
      _planet = planet;
      _group = group;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_run());
  }

  void _clear() {
    Fx.fire(Sfx.tap);
    _seq++; // a query still in flight is stale
    _query.clear();
    _setFilter(null, null);
    setState(() => _results = null);
    _field.requestFocus();
  }

  void _escape() {
    if (_query.text.isNotEmpty) {
      _clear();
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  void _move(int by) {
    if (_visible.isEmpty) return;
    setState(() {
      _keyboard = true;
      _selected = (_selected + by).clamp(0, _visible.length - 1);
    });
    final key = _tileKeys[_visible[_selected].doc.indexKey];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key?.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(Scrollable.ensureVisible(ctx, duration: MadarMotion.short, alignment: 0.3));
      }
    });
  }

  void _submit() {
    if (_visible.isEmpty) return;
    unawaited(_open(_visible[_selected.clamp(0, _visible.length - 1)]));
  }

  Future<void> _open(SearchHit hit) async {
    final text = _query.text;
    if (text.trim().isNotEmpty) unawaited(ref.read(recentSearchesStoreProvider).add(text));
    final opener = widget.onOpen ?? ref.read(searchOpenerProvider);
    var handled = false;
    if (opener != null) {
      try {
        handled = await opener(context, hit.doc);
      } on Object catch (e, st) {
        // An opener without a route for this result: say so, stay usable.
        debugPrint('Search: opening ${hit.doc.openKey}/${hit.doc.refId} failed: $e\n$st');
        handled = false;
      }
    }
    if (handled || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(L10n.of(context).searchCannotOpen)));
  }

  void _useRecent(String q) {
    _query.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    _setFilter(null, null);
    unawaited(_run());
  }

  GlobalKey _keyFor(SearchHit hit) => _tileKeys.putIfAbsent(hit.doc.indexKey, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final visuals = SearchVisuals(
      l10n: l,
      tokens: t,
      registry: ref.watch(searchRegistryProvider),
      planets: ref.watch(searchPlanetsProvider).value ?? const [],
      modules: ref.watch(searchModuleGroupsProvider).value ?? const {},
    );
    final results = _results;
    final hasQuery = _query.text.trim().isNotEmpty;

    final field = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.s),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.escape): _escape,
        },
        child: TextField(
          controller: _query,
          focusNode: _field,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          style: text.bodyLarge,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          // Enter opens a result; the field keeps focus (and the keys).
          onEditingComplete: () {},
          decoration: kitInputDecoration(context, hint: l.searchFieldHint).copyWith(
            prefixIcon: Icon(Icons.search_rounded, color: t.accent),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: t.textTertiary),
                    tooltip: l.searchClear,
                    onPressed: _clear,
                  ),
          ),
        ),
      ),
    );

    final Widget content;
    if (!hasQuery) {
      _visible = const [];
      content = _RecentSearches(onUse: _useRecent);
    } else if (results == null) {
      _visible = const [];
      content = _status == SearchEngineStatus.indexing || _status == SearchEngineStatus.idle
          ? _Preparing(label: l.searchPreparing)
          : const SizedBox.shrink();
    } else {
      content = _resultsView(context, results, visuals);
    }

    return MadarScaffold(
      title: l.searchTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          if (hasQuery && results != null && results.unfilteredTotal > 0) _filters(context, results, visuals),
          Expanded(
            child: AnimatedSwitcher(
              duration: MadarMotion.short,
              child: KeyedSubtree(key: ValueKey(_contentSerialFor(content)), child: content),
            ),
          ),
        ],
      ),
    );
  }

  int _contentSerialFor(Widget content) {
    if (content.runtimeType != _contentType) {
      _contentType = content.runtimeType;
      _contentSerial++;
    }
    return _contentSerial;
  }

  // ------------------------------------------------------------ filters

  Widget _filters(BuildContext context, SearchResults r, SearchVisuals v) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final totals = r.planetTotals;
    final planets = v.order(totals.keys.where((k) => (totals[k] ?? 0) > 0));
    // In parentheses: a middle dot next to Arabic-Indic digits reads as a
    // zero («الصحة · ٢» looks like «٢٠»).
    String withCount(String label, int n) => '$label (${fmt.formatInt(n)})';

    final planetRow = _ChipRow(
      semanticLabel: l.searchFilterPlanets,
      children: [
        MadarChip(
          label: withCount(l.searchAll, r.unfilteredTotal),
          selected: _planet == null && _group == null,
          onSelected: (_) => _setFilter(null, null),
        ),
        for (final p in planets)
          () {
            final vis = v.planet(p);
            return MadarChip(
              label: withCount(vis.label, totals[p]!),
              icon: vis.icon,
              color: vis.color,
              selected: _planet == p,
              onSelected: (_) => _setFilter(_planet == p ? null : p, null),
            );
          }(),
      ],
    );

    final groups = r.groupTotals({?_planet}).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final showGroups = (_planet != null && groups.length > 1) || _group != null;
    SearchDoc? sampleOf(String key) {
      for (final h in r.hits) {
        if (h.doc.groupKey == key) return h.doc;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        planetRow,
        if (showGroups)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: _ChipRow(
              semanticLabel: l.searchFilterModules,
              children: [
                for (final g in groups)
                  () {
                    final vis = v.group(g.key, sample: sampleOf(g.key));
                    return MadarChip(
                      label: withCount(vis.label, g.value),
                      icon: vis.icon,
                      color: vis.color,
                      dense: true,
                      selected: _group == g.key,
                      onSelected: (_) => _setFilter(_planet, _group == g.key ? null : g.key),
                    );
                  }(),
              ],
            ),
          ),
        const SizedBox(height: Space.s),
      ],
    );
  }

  // ------------------------------------------------------------ results

  Widget _resultsView(BuildContext context, SearchResults r, SearchVisuals v) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(searchClockProvider)();

    if (r.hits.isEmpty) {
      _visible = const [];
      final filtered = _planet != null || _group != null;
      return ListView(
        key: const ValueKey('search-empty'),
        padding: const EdgeInsets.only(top: Space.xl),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.noResults,
            title: l.searchNoResultsTitle(_query.text.trim()),
            body: filtered && r.unfilteredTotal > 0 ? l.searchNoResultsFiltered : l.searchNoResultsBody,
            actionLabel: filtered ? l.searchClearFilters : null,
            actionIcon: filtered ? Icons.filter_alt_off_rounded : null,
            onAction: filtered ? () => _setFilter(null, null) : null,
          ),
        ],
      );
    }

    final visible = <SearchHit>[];
    Widget tile(SearchHit hit, {bool showModule = false}) {
      final index = visible.length;
      visible.add(hit);
      final group = v.group(hit.doc.groupKey, sample: hit.doc);
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: SearchResultTile(
          key: _keyFor(hit),
          hit: hit,
          icon: group.icon,
          color: v.planet(hit.doc.planetKey).color,
          moduleLabel: showModule ? group.label : null,
          selected: _keyboard && index == _selected,
          now: now,
          onTap: () => _open(hit),
        ),
      );
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  fmt.localizeDigits(l.searchResultsCount(r.total)),
                  style: text.labelMedium!.copyWith(color: t.gold),
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 600)
              Text(l.searchKeyboardHint, style: text.labelSmall!.copyWith(color: t.textTertiary)),
          ],
        ),
      ),
      if (r.partial)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: t.info),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.searchPartial, style: text.bodySmall!.copyWith(color: t.textSecondary))),
            ],
          ),
        ),
    ];

    if (_group != null) {
      for (final h in r.hits) {
        children.add(tile(h));
      }
    } else {
      final groups = r.groups;
      for (var i = 0; i < groups.length; i++) {
        final g = groups[i];
        final shown = g.hits.take(i == 0 ? 5 : 3).toList();
        final vis = v.group(g.key, sample: g.first);
        children.add(
          _GroupHeader(
            visual: vis,
            count: g.count,
            onShowAll: g.count > shown.length ? () => _setFilter(_planet, g.key) : null,
          ),
        );
        for (final h in shown) {
          children.add(tile(h));
        }
      }
    }
    _visible = visible;
    if (_selected >= visible.length) _selected = visible.isEmpty ? 0 : visible.length - 1;

    return ListView(
      key: const ValueKey('search-results'),
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.xxxl),
      children: children,
    );
  }
}

/// A horizontally scrolling row of chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children, required this.semanticLabel});

  final List<Widget> children;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: Space.s),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A module's heading: its icon, name and number of matches, and "show
/// all" when only the best few are listed.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.visual, required this.count, this.onShowAll});

  final SearchVisual visual;
  final int count;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.m, bottom: Space.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: l.searchGroupSemantics(visual.label, fmt.localizeDigits(l.searchResultsCount(count))),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(visual.icon, size: 18, color: visual.color),
                    const SizedBox(width: Space.s),
                    Flexible(
                      child: Text(
                        visual.label,
                        style: text.titleSmall!.copyWith(color: t.gold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 1),
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: t.isDark ? 0.22 : 0.16),
                        borderRadius: BorderRadius.circular(t.radiusS),
                      ),
                      child: Text(fmt.formatInt(count), style: text.labelSmall!.copyWith(color: t.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onShowAll != null)
            MadarButton(
              label: l.searchShowAll(fmt.formatInt(count)),
              onPressed: onShowAll,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
            ),
        ],
      ),
    );
  }
}

/// "Preparing the search index…" while the first index is built.
class _Preparing extends StatelessWidget {
  const _Preparing({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xl, Space.gutter, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OrbitLoader(size: 22),
          const SizedBox(width: Space.m),
          Flexible(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// The recent searches (tap to search again, × to forget one, "clear
/// history"), or an introduction when there are none.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onUse});

  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final recent = ref.watch(recentSearchesProvider).value ?? const <String>[];
    final store = ref.watch(recentSearchesStoreProvider);
    if (recent.isEmpty) {
      return ListView(
        key: const ValueKey('search-intro'),
        padding: const EdgeInsets.only(top: Space.xl),
        children: [
          AnimatedEmptyState(kind: EmptyStateKind.emptyList, title: l.searchIntroTitle, body: l.searchIntroBody),
        ],
      );
    }
    return ListView(
      key: const ValueKey('search-recent'),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, Space.xxxl),
      children: [
        SectionHeader(
          title: l.searchRecentTitle,
          actionLabel: l.searchRecentClear,
          onAction: () {
            Fx.fire(Sfx.delete);
            unawaited(store.clear());
          },
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, Space.s),
        ),
        for (final q in recent)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
            child: GlassCard(
              onTap: () => onUse(q),
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.xs, Space.xs),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: t.textTertiary),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Text(q, style: text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: t.textTertiary),
                    tooltip: l.searchRecentRemove(q),
                    onPressed: () {
                      Fx.fire(Sfx.tap);
                      unawaited(store.remove(q));
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
