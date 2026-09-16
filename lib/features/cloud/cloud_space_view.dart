import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/enums.dart';
import '../../domain/sheet.dart';
import '../../net/cloud_sync_service.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/entrance.dart';
import '../../widgets/tech_button.dart';

/// Schermata dello Spazio Cloud Google Firebase Spark.
///
/// Fornisce la visualizzazione immersiva dello spazio di archiviazione remoto gratuito (1 GB):
/// - Gestione account Google.
/// - Indicatore grafico della quota utilizzata su 1 GB.
/// - Elenco e ripristino di Schede e Campagne archiviate in cloud.
class CloudSpaceView extends StatefulWidget {
  const CloudSpaceView({super.key});

  @override
  State<CloudSpaceView> createState() => _CloudSpaceViewState();
}

class _CloudSpaceViewState extends State<CloudSpaceView> {
  int _selectedFilter = 0; // 0: Tutti, 1: Schede, 2: Campagne

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final CloudSyncService cloud = CloudSyncService.instance;

    return ListenableBuilder(
      listenable: cloud,
      builder: (BuildContext context, _) {
        final List<CloudDocumentItem> items = _selectedFilter == 1
            ? cloud.cloudSheets
            : _selectedFilter == 2
                ? cloud.cloudCampaigns
                : cloud.documents;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Entrance(
                    delay: const Duration(milliseconds: 30),
                    child: _buildAccountHeader(context, state, cloud),
                  ),
                  const SizedBox(height: 18),
                  Entrance(
                    delay: const Duration(milliseconds: 70),
                    child: _buildQuotaCard(cloud),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    delay: const Duration(milliseconds: 110),
                    child: _buildControlsRow(context, state, cloud),
                  ),
                  const SizedBox(height: 16),
                  Entrance(
                    delay: const Duration(milliseconds: 150),
                    child: _buildDocumentsList(context, state, cloud, items),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountHeader(BuildContext context, AppState state, CloudSyncService cloud) {
    final bool isAuth = cloud.isAuthenticated;
    final CloudUser? user = cloud.currentUser;

    return ChamferPanel(
      accent: isAuth ? CprPalette.cyan : CprPalette.yellow,
      cut: 12,
      title: 'ACCOUNT GOOGLE & FIREBASE SPARK',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isAuth ? CprPalette.cyan : CprPalette.yellow).withValues(alpha: 0.15),
          border: Border.all(color: isAuth ? CprPalette.cyan : CprPalette.yellow, width: 1),
        ),
        child: Text(
          isAuth ? 'PIANO SPARK ATTIVO' : 'CLOUD NON COLLEGATO',
          style: CprType.label.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isAuth ? CprPalette.cyan : CprPalette.yellow,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CprPalette.surfaceSunken,
              border: Border.all(color: isAuth ? CprPalette.cyan : CprPalette.hairline, width: 1.5),
            ),
            child: Icon(
              isAuth ? Icons.cloud_done : Icons.cloud_queue,
              color: isAuth ? CprPalette.cyan : CprPalette.inkMuted,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isAuth ? (user?.displayName ?? 'Utente Cyberpunk') : 'Accesso Cloud Google Gratuito',
                  style: CprType.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CprPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAuth
                      ? (user?.email ?? '')
                      : 'Accedi per sincronizzare e salvare le tue schede e campagne su Google Cloud Firestore senza costi.',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isAuth)
            TechButton(
              label: 'Disconnetti',
              icon: Icons.logout,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: () => cloud.signOut(),
            )
          else
            TechButton(
              label: 'Accedi con Google',
              icon: Icons.login,
              variant: TechButtonVariant.primary,
              compact: true,
              onPressed: () => _promptGoogleLogin(context, cloud),
            ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(CloudSyncService cloud) {
    final double ratio = cloud.quotaUsedRatio;
    final int count = cloud.documents.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.storage, size: 16, color: CprPalette.yellow),
                  const SizedBox(width: 8),
                  Text(
                    'SPAZIO CLOUD UTILIZZATO',
                    style: CprType.label.copyWith(fontSize: 11, letterSpacing: 1.2, color: CprPalette.yellow),
                  ),
                ],
              ),
              Text(
                cloud.quotaFormatted,
                style: CprType.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: CprPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra di quota
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: CprPalette.surfaceSunken,
              border: Border.all(color: CprPalette.hairline),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.005, 1.0),
              child: Container(
                color: CprPalette.yellow,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Quota gratuita permanente Firebase Spark (Google Cloud Firestore): 1.0 GB.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
              ),
              Text(
                '$count elementi archiviati',
                style: CprType.caption.copyWith(color: CprPalette.cyan, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(BuildContext context, AppState state, CloudSyncService cloud) {
    return Row(
      children: <Widget>[
        // Filtri
        _filterChip(label: 'Tutti (${cloud.documents.length})', index: 0),
        const SizedBox(width: 8),
        _filterChip(label: 'Schede (${cloud.cloudSheets.length})', index: 1),
        const SizedBox(width: 8),
        _filterChip(label: 'Campagne (${cloud.cloudCampaigns.length})', index: 2),
        const Spacer(),

        // Azioni di caricamento
        if (state.sheet != null)
          TechButton(
            label: 'Salva Scheda Attiva nel Cloud',
            icon: Icons.cloud_upload_outlined,
            variant: TechButtonVariant.secondary,
            compact: true,
            onPressed: cloud.isAuthenticated
                ? () async {
                    final bool ok = await cloud.saveSheetToCloud(state.sheet!);
                    if (context.mounted && ok) {
                      showTechMessage(
                        context,
                        title: 'Scheda Salvata nel Cloud',
                        message: 'La scheda "${state.sheet!.meta.name}" e\' stata caricata con successo su Firebase Spark.',
                      );
                    }
                  }
                : null,
          ),
        if (state.campaign != null) ...<Widget>[
          const SizedBox(width: 8),
          TechButton(
            label: 'Salva Campagna Attiva nel Cloud',
            icon: Icons.cloud_upload_outlined,
            variant: TechButtonVariant.secondary,
            compact: true,
            onPressed: cloud.isAuthenticated
                ? () async {
                    final bool ok = await cloud.saveCampaignToCloud(state.campaign!);
                    if (context.mounted && ok) {
                      showTechMessage(
                        context,
                        title: 'Campagna Salvata nel Cloud',
                        message: 'La campagna "${state.campaign!.meta.name}" e\' stata caricata con successo su Firebase Spark.',
                      );
                    }
                  }
                : null,
          ),
        ],
      ],
    );
  }

  Widget _filterChip({required String label, required int index}) {
    final bool active = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? CprPalette.yellow.withValues(alpha: 0.18) : CprPalette.surfaceSunken,
          border: Border.all(color: active ? CprPalette.yellow : CprPalette.hairline),
        ),
        child: Text(
          label,
          style: CprType.label.copyWith(
            fontSize: 10.5,
            color: active ? CprPalette.yellow : CprPalette.inkMuted,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsList(
    BuildContext context,
    AppState state,
    CloudSyncService cloud,
    List<CloudDocumentItem> items,
  ) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.hairline),
        ),
        child: Column(
          children: <Widget>[
            Icon(Icons.cloud_off, size: 38, color: CprPalette.inkFaint),
            const SizedBox(height: 12),
            Text(
              'Nessun documento presente in questa sezione cloud.',
              style: CprType.body.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Puoi caricare le tue schede personaggio o campagne per accedervi ovunque.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items
          .map((CloudDocumentItem doc) => _buildDocumentTile(context, state, cloud, doc))
          .toList(),
    );
  }

  Widget _buildDocumentTile(
    BuildContext context,
    AppState state,
    CloudSyncService cloud,
    CloudDocumentItem doc,
  ) {
    final bool isSheet = doc.kind == DocumentKind.sheet;
    final IconData icon = isSheet ? Icons.person_outline : Icons.casino_outlined;
    final Color accent = isSheet ? CprPalette.cyan : CprPalette.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      doc.name,
                      style: CprType.body.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CprPalette.surfaceSunken,
                        border: Border.all(color: CprPalette.hairline),
                      ),
                      child: Text(
                        isSheet ? 'SCHEDA' : 'CAMPAGNA',
                        style: CprType.caption.copyWith(fontSize: 8.5, color: accent, letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${doc.roleOrDetails.isNotEmpty ? "${doc.roleOrDetails} · " : ""}Dimensione: ${doc.sizeFormatted}',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TechButton(
            label: 'Apri in nuova Tab',
            icon: Icons.open_in_new,
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () => _openDocumentFromCloud(context, state, doc),
          ),
          const SizedBox(width: 8),
          TechButton(
            label: 'Salva in Locale',
            icon: Icons.download_outlined,
            variant: TechButtonVariant.secondary,
            compact: true,
            tooltip: 'Salva una copia nella Libreria Schede locale dell\'app',
            onPressed: () => _downloadToLocalLibrary(context, state, doc),
          ),
          const SizedBox(width: 8),
          TechButton(
            label: '',
            icon: Icons.delete_outline,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Elimina dal Cloud',
            onPressed: () => _confirmDeleteCloud(context, cloud, doc),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocumentFromCloud(
    BuildContext context,
    AppState state,
    CloudDocumentItem doc,
  ) async {
    try {
      final Object? json = jsonDecode(doc.jsonPayload);
      if (json is! Map) return;
      final Map<String, Object?> map = json.map((Object? k, Object? v) => MapEntry(k.toString(), v));

      if (doc.kind == DocumentKind.sheet) {
        final CharacterSheet sheet = CharacterSheet.fromJson(map);
        state.openSheetInNewTab(sheet);
      } else {
        final Campaign campaign = Campaign.fromJson(map);
        state.openCampaignInNewTab(campaign);
      }
    } catch (e) {
      if (context.mounted) {
        showTechMessage(context, title: 'Errore Apertura', message: 'Impossibile aprire il documento cloud: $e');
      }
    }
  }

  Future<void> _downloadToLocalLibrary(
    BuildContext context,
    AppState state,
    CloudDocumentItem doc,
  ) async {
    try {
      final Directory dir = AppPaths.sheetsDir();
      final String safeName = doc.name.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final String path = p.join(dir.path, '$safeName.${CpreduxFile.extension}');

      final Object? json = jsonDecode(doc.jsonPayload);
      if (json is! Map) return;
      final Map<String, Object?> map = json.map((Object? k, Object? v) => MapEntry(k.toString(), v));

      final CpreduxFile file = CpreduxFile.open(path);
      try {
        if (doc.kind == DocumentKind.sheet) {
          final CharacterSheet sheet = CharacterSheet.fromJson(map);
          file.writeSheet(sheet);
        } else {
          final Campaign campaign = Campaign.fromJson(map);
          file.writeCampaign(campaign);
        }
      } finally {
        file.close();
      }

      state.refreshDocumentLibrary();
      if (context.mounted) {
        showTechMessage(
          context,
          title: 'Salvato in Locale',
          message: 'Il documento "${doc.name}" e\' stato archiviato nella tua Libreria Schede:\n$path',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showTechMessage(context, title: 'Errore Salvataggio', message: 'Impossibile salvare in locale: $e');
      }
    }
  }

  Future<void> _confirmDeleteCloud(
    BuildContext context,
    CloudSyncService cloud,
    CloudDocumentItem doc,
  ) async {
    final bool confirm = await showTechConfirm(
      context,
      title: 'Elimina dal Cloud',
      message: 'Sei sicuro di voler eliminare permanentemente "${doc.name}" dal tuo spazio cloud Firebase Spark?',
      confirmLabel: 'Elimina',
      danger: true,
    );
    if (confirm) {
      await cloud.deleteDocumentFromCloud(doc.id);
    }
  }

  Future<void> _promptGoogleLogin(BuildContext context, CloudSyncService cloud) async {
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    String? errorText;

    final bool? doLogin = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return AlertDialog(
            backgroundColor: CprPalette.surface,
            title: Text(
              'ACCESSO GOOGLE FIREBASE SPARK',
              style: CprType.body.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Inserisci la tua email Google reale per collegare il tuo spazio cloud Firestore gratuito (1 GB):',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome Visualizzato (es. tuo nome o alias)',
                    hintText: 'Johnny',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Google',
                    hintText: 'utente@gmail.com',
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              TechButton(
                label: 'Accedi al Cloud',
                icon: Icons.cloud_done,
                variant: TechButtonVariant.primary,
                compact: true,
                onPressed: () {
                  final String email = emailCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    setModalState(() {
                      errorText = 'Inserisci un indirizzo email valido';
                    });
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
              ),
            ],
          );
        },
      ),
    );

    if (doLogin == true) {
      await cloud.signInWithGoogle(
        email: emailCtrl.text.trim(),
        customName: nameCtrl.text.trim(),
      );
    }
  }
}
