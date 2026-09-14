import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_state.dart';
import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Barra delle schede in stile Browser Desktop.
///
/// Permette di gestire e visualizzare contemporaneamente:
/// - La Libreria Schede (Home).
/// - Molteplici schede personaggio aperte contemporaneamente.
/// - Il tavolo Campagna del Master.
/// - Lo Spazio Cloud Firebase Spark.
/// - Il confronto schede o le Impostazioni.
///
/// Supporta inoltre il drag-and-drop di file `.cpredux` direttamente sulle tab per
/// aprire il documento in una nuova tab dedicata.
class BrowserTabBar extends StatelessWidget implements PreferredSizeWidget {
  const BrowserTabBar({super.key});

  static const double height = 36.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<AppTab> tabs = state.tabs;
    final int activeIndex = state.activeTabIndex;

    return DropTarget(
      onDragDone: (DropDoneDetails details) {
        for (final DropItem item in details.files) {
          if (item is! DropItemDirectory) {
            final String ext = p.extension(item.path).toLowerCase();
            if (ext == '.cpredux' || ext == '.cpred_sheet') {
              state.openFileInNewTab(item.path);
            }
          }
        }
      },
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: CprPalette.surfaceSunken,
          border: Border(bottom: BorderSide(color: CprPalette.hairline)),
        ),
        child: Row(
          children: <Widget>[
            // Lista scorrevole orizzontale delle tab
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 2),
                itemBuilder: (BuildContext ctx, int index) {
                  final AppTab tab = tabs[index];
                  final bool isActive = index == activeIndex;
                  return _BrowserTabItem(
                    tab: tab,
                    isActive: isActive,
                    onSelect: () => state.selectTab(index),
                    onClose: index == 0
                        ? null // La Libreria (Tab 0) è permanente e non si chiude
                        : () => state.closeTab(index),
                  );
                },
              ),
            ),

            // Pulsante "+" Nuova Tab Rapida
            Tooltip(
              message: 'Crea nuova scheda in una nuova tab',
              child: InkWell(
                onTap: () => state.createSheetInNewTab(),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CprPalette.surface,
                    border: Border.all(color: CprPalette.hairline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(Icons.add, size: 16, color: CprPalette.yellow),
                ),
              ),
            ),

            // Pulsante rapido Spazio Cloud
            Tooltip(
              message: 'Apri Spazio Cloud Firebase Spark',
              child: InkWell(
                onTap: () => state.goToCloudSpace(),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CprPalette.surface,
                    border: Border.all(color: CprPalette.hairline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.cloud_outlined, size: 14, color: CprPalette.cyan),
                      const SizedBox(width: 5),
                      Text(
                        'CLOUD',
                        style: CprType.label.copyWith(fontSize: 9.5, color: CprPalette.cyan, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserTabItem extends StatelessWidget {
  const _BrowserTabItem({
    required this.tab,
    required this.isActive,
    required this.onSelect,
    this.onClose,
  });

  final AppTab tab;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback? onClose;

  IconData _iconForKind(AppTabKind kind) {
    switch (kind) {
      case AppTabKind.home:
        return Icons.grid_view_outlined;
      case AppTabKind.sheet:
        return Icons.person_outline;
      case AppTabKind.campaign:
        return Icons.casino_outlined;
      case AppTabKind.cloud:
        return Icons.cloud_outlined;
      case AppTabKind.settings:
        return Icons.settings_outlined;
      case AppTabKind.compare:
        return Icons.compare_arrows;
    }
  }

  Color _accentForKind(AppTabKind kind) {
    switch (kind) {
      case AppTabKind.home:
        return CprPalette.yellow;
      case AppTabKind.sheet:
        return CprPalette.cyan;
      case AppTabKind.campaign:
        return CprPalette.magenta;
      case AppTabKind.cloud:
        return CprPalette.cyan;
      case AppTabKind.settings:
        return CprPalette.inkMuted;
      case AppTabKind.compare:
        return CprPalette.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentForKind(tab.kind);
    final IconData icon = _iconForKind(tab.kind);

    return InkWell(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: CprMotion.fast,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? CprPalette.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? accent : Colors.transparent,
              width: 2.2,
            ),
            left: const BorderSide(color: CprPalette.hairline, width: 0.5),
            right: const BorderSide(color: CprPalette.hairline, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: isActive ? accent : CprPalette.inkMuted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CprType.label.copyWith(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? CprPalette.ink : CprPalette.inkMuted,
                ),
              ),
            ),
            if (tab.isDirty) ...<Widget>[
              const SizedBox(width: 5),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CprPalette.yellow,
                ),
              ),
            ],
            if (onClose != null) ...<Widget>[
              const SizedBox(width: 6),
              InkResponse(
                onTap: onClose,
                radius: 10,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: isActive ? CprPalette.inkMuted : CprPalette.inkFaint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
