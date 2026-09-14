import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import '../features/update/custom_update_dialog.dart';
import '../net/updater.dart';
import '../version.dart';

/// Barra del titolo personalizzata, integrata e immersa nell'interfaccia.
///
/// Su macOS la barra nativa e' resa trasparente con `.fullSizeContentView`:
/// i pulsanti di controllo (semaforo rosso/giallo/verde) fluttuano a sinistra
/// dentro questo spazio dedicato (78 px), mentre il titolo della finestra e'
/// esattamente centrato orizzontalmente come in VS Code / Antigravity IDE.
///
/// Su Windows e altre piattaforme, la barra si fonde senza stacchi con la
/// finestra (`DWMWA_USE_IMMERSIVE_DARK_MODE` e `DWMWA_CAPTION_COLOR`) e
/// mantiene il titolo centrato e lo stile Cyberpunk scuro.
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const WindowTitleBar({super.key});

  static const double height = 38.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  bool get _isMac {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  String _screenTitle(AppState state) {
    switch (state.screen) {
      case AppScreen.home:
        return 'Cyberpunk RED Visualizer';
      case AppScreen.sheet:
        final sheet = state.sheet;
        if (sheet == null) return 'Scheda Personaggio';
        final String name = sheet.meta.name.trim();
        final String role = sheet.identity.role.trim();
        if (name.isNotEmpty && role.isNotEmpty) {
          return '$name · $role';
        } else if (name.isNotEmpty) {
          return name;
        } else {
          return 'Nuova Scheda';
        }
      case AppScreen.campaign:
        return 'Tavolo Campagna (Game Master)';
      case AppScreen.compare:
        return 'Confronto Schede';
      case AppScreen.settings:
        return 'Impostazioni';
      case AppScreen.cloud:
        return 'Spazio Cloud Firebase Spark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String activeTitle = _screenTitle(state);
    final bool isMac = _isMac;

    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Stack(
        children: <Widget>[
          // Titolo perfettamente centrato nella finestra
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 90),
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: CprType.label.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                  children: <TextSpan>[
                    const TextSpan(
                      text: 'CPRedux Desktop',
                      style: TextStyle(
                        color: CprPalette.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(
                      text: ' — ',
                      style: TextStyle(
                        color: CprPalette.inkMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: activeTitle,
                      style: const TextStyle(
                        color: CprPalette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Elementi a sinistra
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: isMac
                // Su macOS riserviamo 78 px per i tasti del semaforo nativo
                ? const SizedBox(width: 78)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(width: 14),
                      Container(
                        width: 3,
                        height: 14,
                        color: CprPalette.yellow,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CPRED',
                        style: CprType.label.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: CprPalette.yellow,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),

          // Elementi a destra (indicatore di stato discreto)
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildRightStatus(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightStatus(BuildContext context, AppState state) {
    final bool isChecking = state.updateStage == UpdateStage.checking;
    final bool updateAvailable = state.updateStage == UpdateStage.available;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.screen == AppScreen.sheet && state.sheet != null) ...<Widget>[
          _buildSheetSaveStatus(state),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: CprPalette.hairline),
          const SizedBox(width: 8),
        ],
        if (updateAvailable && state.settings.showUpdateNotifications) ...<Widget>[
          InkWell(
            onTap: () => showCustomUpdateDownloadDialog(context),
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CprPalette.yellow,
                borderRadius: BorderRadius.circular(2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: CprPalette.yellow.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.arrow_upward, size: 11, color: Colors.black),
                  const SizedBox(width: 4),
                  Text(
                    'AGGIORNA ORA',
                    style: CprType.label.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: CprPalette.hairline),
          const SizedBox(width: 8),
        ],
        Text(
          'v$appVersion',
          style: CprType.caption.copyWith(
            fontSize: 9.5,
            color: CprPalette.veil(CprPalette.inkMuted, 0.75),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: updateAvailable
              ? 'Aggiornamento disponibile!'
              : isChecking
                  ? 'Verifica in corso…'
                  : 'Verifica aggiornamenti',
          child: InkResponse(
            onTap: isChecking
                ? null
                : () {
                    if (updateAvailable) {
                      state.goToSettings();
                    } else {
                      state.checkForUpdates(silent: false);
                    }
                  },
            radius: 12,
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: isChecking
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: CprPalette.yellow,
                      ),
                    )
                  : Icon(
                      updateAvailable ? Icons.system_update_alt : Icons.sync,
                      size: 13,
                      color: updateAvailable
                          ? CprPalette.yellow
                          : CprPalette.veil(CprPalette.inkMuted, 0.75),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetSaveStatus(AppState state) {
    final bool saved = !state.isDirty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: saved ? CprPalette.humanityIntact : CprPalette.yellow,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          saved ? 'SALVATO' : 'MODIFICATO',
          style: CprType.caption.copyWith(
            fontSize: 9,
            letterSpacing: 0.5,
            color: saved ? CprPalette.humanityIntact : CprPalette.yellow,
          ),
        ),
      ],
    );
  }
}
