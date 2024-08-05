import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/game/game_filter.dart';
import 'package:lichess_mobile/src/model/game/game_history.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/model/user/user_repository_providers.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/game/game_list_tile.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';

class GameHistoryScreen extends ConsumerWidget {
  const GameHistoryScreen({
    required this.user,
    required this.isOnline,
    this.gameFilter = const GameFilterState(),
    super.key,
  });
  final LightUser? user;
  final bool isOnline;
  final GameFilterState gameFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtersInUse = ref.watch(gameFilterProvider(filter: gameFilter));
    final nbGamesAsync = ref.watch(
      userNumberOfGamesProvider(user, isOnline: isOnline),
    );
    final title = filtersInUse.count == 0
        ? nbGamesAsync.when(
            data: (nbGames) => Text(context.l10n.nbGames(nbGames)),
            loading: () => const ButtonLoadingIndicator(),
            error: (e, s) => Text(context.l10n.mobileAllGames),
          )
        : Text(filtersInUse.selectionLabel(context));
    final filterBtn = Stack(
      alignment: Alignment.center,
      children: [
        AppBarIconButton(
          icon: const Icon(Icons.tune),
          semanticsLabel: context.l10n.filterGames,
          onPressed: () => showAdaptiveBottomSheet<GameFilterState>(
            context: context,
            builder: (_) => _FilterGames(
              filter: ref.read(gameFilterProvider(filter: gameFilter)),
              user: user,
            ),
          ).then((value) {
            if (value != null) {
              ref
                  .read(gameFilterProvider(filter: gameFilter).notifier)
                  .setFilter(value);
            }
          }),
        ),
        if (filtersInUse.count > 0)
          Positioned(
            top: 2.0,
            right: 2.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.brightness_1,
                  size: 20.0,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                FittedBox(
                  fit: BoxFit.contain,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    child: Text(filtersInUse.count.toString()),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
        return _buildAndroid(context, ref, title: title, filterBtn: filterBtn);
      case TargetPlatform.iOS:
        return _buildIos(context, ref, title: title, filterBtn: filterBtn);
      default:
        assert(false, 'Unexpected platform ${Theme.of(context).platform}');
        return const SizedBox.shrink();
    }
  }

  Widget _buildIos(
    BuildContext context,
    WidgetRef ref, {
    required Widget title,
    required Widget filterBtn,
  }) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: const EdgeInsetsDirectional.only(
          start: 16.0,
          end: 8.0,
        ),
        middle: title,
        trailing: filterBtn,
      ),
      child: _Body(user: user, isOnline: isOnline, gameFilter: gameFilter),
    );
  }

  Widget _buildAndroid(
    BuildContext context,
    WidgetRef ref, {
    required Widget title,
    required Widget filterBtn,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [filterBtn],
      ),
      body: _Body(user: user, isOnline: isOnline, gameFilter: gameFilter),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.user,
    required this.isOnline,
    required this.gameFilter,
  });

  final LightUser? user;
  final bool isOnline;
  final GameFilterState gameFilter;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final state = ref.read(
        userGameHistoryProvider(
          widget.user?.id,
          isOnline: widget.isOnline,
          filter: ref.read(gameFilterProvider(filter: widget.gameFilter)),
        ),
      );

      if (!state.hasValue) {
        return;
      }

      final hasMore = state.requireValue.hasMore;
      final isLoading = state.requireValue.isLoading;

      if (hasMore && !isLoading) {
        ref
            .read(
              userGameHistoryProvider(
                widget.user?.id,
                isOnline: widget.isOnline,
                filter: ref.read(gameFilterProvider(filter: widget.gameFilter)),
              ).notifier,
            )
            .getNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameFilterState =
        ref.watch(gameFilterProvider(filter: widget.gameFilter));
    final gameListState = ref.watch(
      userGameHistoryProvider(
        widget.user?.id,
        isOnline: widget.isOnline,
        filter: gameFilterState,
      ),
    );

    return gameListState.when(
      data: (state) {
        final list = state.gameList;

        return SafeArea(
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No games found',
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  separatorBuilder: (context, index) =>
                      Theme.of(context).platform == TargetPlatform.iOS
                          ? const PlatformDivider(
                              height: 1,
                              cupertinoHasLeading: true,
                            )
                          : const PlatformDivider(
                              height: 1,
                              color: Colors.transparent,
                            ),
                  itemCount: list.length + (state.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.isLoading && index == list.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: CenterLoadingIndicator(),
                      );
                    } else if (state.hasError &&
                        state.hasMore &&
                        index == list.length) {
                      // TODO: add a retry button
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'Could not load more games',
                          ),
                        ),
                      );
                    }

                    return ExtendedGameListTile(
                      item: list[index],
                      userId: widget.user?.id,
                      // see: https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/cupertino/list_tile.dart#L30 for horizontal padding value
                      padding: Theme.of(context).platform == TargetPlatform.iOS
                          ? const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 12.0,
                            )
                          : null,
                    );
                  },
                ),
        );
      },
      error: (e, s) {
        debugPrint(
          'SEVERE: [GameHistoryScreen] could not load game list',
        );
        return const Center(child: Text('Could not load Game History'));
      },
      loading: () => const CenterLoadingIndicator(),
    );
  }
}

class _FilterGames extends ConsumerStatefulWidget {
  const _FilterGames({
    required this.filter,
    required this.user,
  });

  final GameFilterState filter;
  final LightUser? user;

  @override
  ConsumerState<_FilterGames> createState() => _FilterGamesState();
}

class _FilterGamesState extends ConsumerState<_FilterGames> {
  late GameFilterState filter;

  @override
  void initState() {
    super.initState();
    filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    const gamePerfs = [
      Perf.ultraBullet,
      Perf.bullet,
      Perf.blitz,
      Perf.rapid,
      Perf.classical,
      Perf.correspondence,
      Perf.chess960,
      Perf.antichess,
      Perf.kingOfTheHill,
      Perf.threeCheck,
      Perf.atomic,
      Perf.horde,
      Perf.racingKings,
      Perf.crazyhouse,
    ];
    const filterGroupSpace = SizedBox(height: 10.0);

    final session = ref.read(authSessionProvider);
    final userId = widget.user?.id ?? session?.user.id;

    List<Perf> availablePerfs(User user) {
      final perfs = gamePerfs.where((perf) {
        final p = user.perfs[perf];
        return p != null && p.numberOfGamesOrRuns > 0;
      }).toList(growable: false);
      perfs.sort(
        (p1, p2) => user.perfs[p2]!.numberOfGamesOrRuns
            .compareTo(user.perfs[p1]!.numberOfGamesOrRuns),
      );
      return perfs;
    }

    Widget perfFilter(List<Perf> choices) => _Filter<Perf>(
          filterName: context.l10n.variant,
          filterType: FilterType.multipleChoice,
          choices: choices,
          choiceSelected: (choice) => filter.perfs.contains(choice),
          choiceLabel: (t) => t.shortTitle,
          onSelected: (value, selected) => setState(
            () {
              filter = filter.copyWith(
                perfs: selected
                    ? filter.perfs.add(value)
                    : filter.perfs.remove(value),
              );
            },
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12.0),
            if (userId != null)
              ref.watch(userProvider(id: userId)).when(
                    data: (user) => perfFilter(availablePerfs(user)),
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                    error: (_, __) => perfFilter(gamePerfs),
                  )
            else
              perfFilter(gamePerfs),
            const PlatformDivider(thickness: 1, indent: 0),
            filterGroupSpace,
            _Filter<Side>(
              filterName: context.l10n.side,
              filterType: FilterType.singleChoice,
              choices: Side.values,
              choiceSelected: (choice) => filter.side == choice,
              choiceLabel: (t) => switch (t) {
                Side.white => context.l10n.white,
                Side.black => context.l10n.black,
              },
              onSelected: (value, selected) => setState(
                () {
                  filter = filter.copyWith(side: selected ? value : null);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () =>
                      setState(() => filter = const GameFilterState()),
                  child: Text(context.l10n.reset),
                ),
                AdaptiveTextButton(
                  onPressed: () => Navigator.of(context).pop(filter),
                  child: Text(context.l10n.apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum FilterType {
  singleChoice,
  multipleChoice,
}

class _Filter<T extends Enum> extends StatelessWidget {
  const _Filter({
    required this.filterName,
    required this.filterType,
    required this.choices,
    required this.choiceSelected,
    required this.choiceLabel,
    required this.onSelected,
  });

  final String filterName;
  final FilterType filterType;
  final Iterable<T> choices;
  final bool Function(T choice) choiceSelected;
  final String Function(T choice) choiceLabel;
  final void Function(T value, bool selected) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(filterName, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8.0,
            children: choices
                .map(
                  (choice) => switch (filterType) {
                    FilterType.singleChoice => ChoiceChip(
                        label: Text(choiceLabel(choice)),
                        selected: choiceSelected(choice),
                        onSelected: (value) => onSelected(choice, value),
                      ),
                    FilterType.multipleChoice => FilterChip(
                        label: Text(choiceLabel(choice)),
                        selected: choiceSelected(choice),
                        onSelected: (value) => onSelected(choice, value),
                      ),
                  },
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
