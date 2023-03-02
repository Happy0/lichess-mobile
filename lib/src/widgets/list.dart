import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:lichess_mobile/src/common/styles.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

/// A platform agnostic list section.
///
/// Use to show a limited number of items.
class ListSection extends StatelessWidget {
  const ListSection({
    super.key,
    required this.children,
    this.header,
    this.onHeaderTap,
    this.margin,
    this.hasLeading = false,
    this.showDivider = false,
    this.showDividerBetweenTiles = false,
    this.dense = false,
  });

  /// Usually a list of [PlatformListTile] widgets
  final List<Widget> children;

  /// Whether the iOS tiles have a leading widget.
  final bool hasLeading;

  /// Show a header above the children rows. Typically a [Text] widget.
  final Widget? header;
  final GestureTapCallback? onHeaderTap;

  final EdgeInsetsGeometry? margin;

  /// Only on android.
  final bool showDividerBetweenTiles;

  /// Show a [Divider] at the bottom of the section. Only on android.
  final bool showDivider;

  /// Use it to set [ListTileTheme.dense] property. Only on Android.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Padding(
          padding: margin ?? EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null)
                ListTile(
                  title: DefaultTextStyle.merge(
                    style: Styles.sectionTitle,
                    child: header!,
                  ),
                  trailing: (onHeaderTap != null)
                      ? GestureDetector(
                          onTap: onHeaderTap,
                          child: const Icon(Icons.more_horiz),
                        )
                      : null,
                ),
              if (showDividerBetweenTiles)
                ...ListTile.divideTiles(
                  context: context,
                  tiles: children,
                )
              else
                ...children,
              if (showDivider)
                const Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Divider(thickness: 0),
                ),
            ],
          ),
        );
      case TargetPlatform.iOS:
        return Padding(
          padding: margin ?? Styles.bodySectionPadding,
          child: Column(
            children: [
              if (header != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DefaultTextStyle(
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .merge(Styles.sectionTitle),
                        child: header!,
                      ),
                      if (onHeaderTap != null)
                        GestureDetector(
                          onTap: onHeaderTap,
                          child: const Icon(CupertinoIcons.ellipsis),
                        ),
                    ],
                  ),
                ),
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                hasLeading: hasLeading,
                children: children,
              ),
            ],
          ),
        );
      default:
        assert(false, 'Unexpected platform $defaultTargetPlatform');
        return const SizedBox.shrink();
    }
  }
}

/// A list tile that shows game info.
class GameListTile extends StatelessWidget {
  const GameListTile({
    required this.icon,
    required this.playerTitle,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Widget playerTitle;
  final Widget? subtitle;
  final Widget? trailing;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        size: defaultTargetPlatform == TargetPlatform.iOS ? 26.0 : 36.0,
      ),
      title: playerTitle,
      subtitle: subtitle != null
          ? DefaultTextStyle.merge(
              child: subtitle!,
              style: TextStyle(
                color: textShade(context, Styles.subtitleOpacity),
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
