import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/net_architecture.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/cyber_help_tooltip.dart';
import '../../widgets/tech_button.dart';

/// Editor e Visualizzatore interattivo di architetture NET (Cyberpunk RED pag. 206-221).
///
/// Permette al Master di:
/// - Costruire e modificare le architetture a piani (Password, Nodi di controllo, Black ICE, File, Root Virus).
/// - Attivare/disattivare la nebbia di guerra piano per piano (Rivelato al Netrunner).
/// - Simulare o tracciare le azioni del Netrunner durante le incursioni in rete.
class NetArchitectureEditor extends StatefulWidget {
  const NetArchitectureEditor({
    super.key,
    required this.architecture,
    this.isMaster = true,
    this.onChanged,
  });

  final NetArchitecture architecture;
  final bool isMaster;
  final VoidCallback? onChanged;

  @override
  State<NetArchitectureEditor> createState() => _NetArchitectureEditorState();
}

class _NetArchitectureEditorState extends State<NetArchitectureEditor> {
  late NetArchitecture _arch;

  @override
  void initState() {
    super.initState();
    _arch = widget.architecture;
  }

  void _notify() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context),
          const Divider(height: 1, color: CprPalette.hairline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: <Widget>[
                for (int i = 0; i < _arch.floors.length; i++) ...<Widget>[
                  _buildFloorCard(context, _arch.floors[i], i),
                  if (i < _arch.floors.length - 1) _buildElevatorConduit(),
                ],
                const SizedBox(height: 20),
                if (widget.isMaster)
                  Center(
                    child: TechButton(
                      label: '+ AGGIUNGI PIANO ALLA RETE',
                      icon: Icons.add,
                      variant: TechButtonVariant.primary,
                      compact: true,
                      onPressed: _addFloor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: CprPalette.surfaceRaised,
      child: Row(
        children: <Widget>[
          const Icon(Icons.hub_outlined, color: CprPalette.cyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      _arch.name.toUpperCase(),
                      style: CprType.body.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 14,
                        color: CprPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: CprPalette.cyan.withValues(alpha: 0.15),
                        border: Border.all(color: CprPalette.cyan, width: 0.8),
                      ),
                      child: Text(
                        _arch.difficultyRating,
                        style: CprType.caption.copyWith(
                          fontSize: 9,
                          color: CprPalette.cyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _arch.description.isNotEmpty ? _arch.description : 'Architettura NET per Netrunner',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const CyberHelpTooltip(
            title: 'NET Architecture (Cyberpunk RED)',
            message: 'Le architetture di rete sono organizzate a piani verticali (da cima a fondo). I Netrunner usano l\'azione Incursione per scendere di piano in piano affrontando Password (DV), Black ICE e prendendo il controllo di torrette o telecamere fisiche.',
            tag: 'Regole Rete',
            accent: CprPalette.cyan,
          ),
          if (widget.isMaster) ...<Widget>[
            const SizedBox(width: 12),
            TechButton(
              label: 'Carica Preset',
              icon: Icons.auto_awesome,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: _showPresetsMenu,
            ),
            const SizedBox(width: 8),
            TechButton(
              label: 'Rinomina',
              icon: Icons.edit_outlined,
              variant: TechButtonVariant.secondary,
              compact: true,
              onPressed: _editArchDetails,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildElevatorConduit() {
    return Center(
      child: Container(
        width: 2,
        height: 24,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: CprPalette.cyan.withValues(alpha: 0.4),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: CprPalette.cyan.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorCard(BuildContext context, NetFloor floor, int index) {
    final bool isRevealed = floor.isRevealed;
    final bool canView = widget.isMaster || isRevealed;

    return ChamferPanel(
      accent: isRevealed ? CprPalette.cyan : CprPalette.inkFaint,
      cut: 8,
      title: 'PIANO ${floor.floorNumber}: ${floor.name.isNotEmpty ? floor.name : "Livello di Rete"}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.isMaster) ...<Widget>[
            // Interruttore Rivelato / Nebbia di guerra
            InkWell(
              onTap: () {
                floor.isRevealed = !floor.isRevealed;
                _notify();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRevealed
                      ? CprPalette.cyan.withValues(alpha: 0.15)
                      : CprPalette.surfaceSunken,
                  border: Border.all(
                    color: isRevealed ? CprPalette.cyan : CprPalette.hairline,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isRevealed ? Icons.visibility : Icons.visibility_off,
                      size: 13,
                      color: isRevealed ? CprPalette.cyan : CprPalette.inkMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isRevealed ? 'RIVELATO AI GIOCATORI' : 'NASCOSTO (NEBBIA)',
                      style: CprType.label.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isRevealed ? CprPalette.cyan : CprPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 16, color: CprPalette.cyan),
              tooltip: 'Aggiungi nodo a questo piano',
              onPressed: () => _showAddNodeDialog(floor),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: CprPalette.danger),
              tooltip: 'Elimina questo piano',
              onPressed: () {
                _arch.floors.removeAt(index);
                // Rinumera
                for (int f = 0; f < _arch.floors.length; f++) {
                  // Keep floor numbering aligned
                }
                _notify();
              },
            ),
          ] else ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: isRevealed ? CprPalette.cyan.withValues(alpha: 0.15) : CprPalette.surfaceSunken,
              child: Text(
                isRevealed ? 'ESPLORATO' : 'CRITTOGRAFATO',
                style: CprType.label.copyWith(
                  fontSize: 9,
                  color: isRevealed ? CprPalette.cyan : CprPalette.inkFaint,
                ),
              ),
            ),
          ],
        ],
      ),
      child: !canView
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.lock, size: 16, color: CprPalette.inkFaint),
                  const SizedBox(width: 8),
                  Text(
                    'PIANO BLOCCATO DA CRITTOGRAFIA DI RETE (Richiede Incursione del Netrunner)',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                  ),
                ],
              ),
            )
          : floor.nodes.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Text(
                    'Nessun nodo configurato su questo piano. Aggiungi Password, Black ICE o Nodi di Controllo.',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: floor.nodes.map((NetNode node) => _buildNodeChip(context, floor, node)).toList(),
                ),
    );
  }

  Widget _buildNodeChip(BuildContext context, NetFloor floor, NetNode node) {
    Color accentColor;
    IconData icon;

    switch (node.type) {
      case NetNodeType.password:
        accentColor = CprPalette.yellow;
        icon = Icons.key;
        break;
      case NetNodeType.file:
        accentColor = CprPalette.cyan;
        icon = Icons.insert_drive_file_outlined;
        break;
      case NetNodeType.controlNode:
        accentColor = CprPalette.magenta;
        icon = Icons.settings_remote;
        break;
      case NetNodeType.blackIce:
        accentColor = CprPalette.danger;
        icon = Icons.security;
        break;
      case NetNodeType.rootVirus:
        accentColor = CprPalette.yellow;
        icon = Icons.terminal;
        break;
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(
          color: node.isCompleted ? CprPalette.inkFaint : accentColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.type.label.toUpperCase(),
                  style: CprType.label.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: accentColor.withValues(alpha: 0.15),
                child: Text(
                  'DV ${node.dv}',
                  style: CprType.label.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              if (widget.isMaster) ...<Widget>[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    floor.nodes.removeWhere((NetNode n) => n.id == node.id);
                    _notify();
                  },
                  child: const Icon(Icons.close, size: 13, color: CprPalette.inkMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node.name.isNotEmpty ? node.name : node.type.label,
            style: CprType.body.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: node.isCompleted ? CprPalette.inkMuted : CprPalette.ink,
              decoration: node.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (node.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              node.description,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10.5),
            ),
          ],
          if (node.devices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: node.devices
                  .map((NetDeviceType d) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        color: CprPalette.surfaceRaised,
                        child: Text(
                          d.label,
                          style: CprType.caption.copyWith(fontSize: 8.5, color: CprPalette.magenta),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (node.ice != null) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CprPalette.danger.withValues(alpha: 0.08),
                border: Border.all(color: CprPalette.danger.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${node.ice!.name} (${node.ice!.category})',
                    style: CprType.label.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: CprPalette.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'VEL ${node.ice!.speed} · ATT ${node.ice!.attack} · DIF ${node.ice!.defense} · REZ ${node.ice!.rez}',
                    style: CprType.caption.copyWith(fontSize: 8.5, color: CprPalette.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    node.ice!.effect,
                    style: CprType.caption.copyWith(fontSize: 8.5, color: CprPalette.ink),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Pulsante di completamento / Hack
          InkWell(
            onTap: () {
              node.isCompleted = !node.isCompleted;
              _notify();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Icon(
                  node.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 13,
                  color: node.isCompleted ? CprPalette.cyan : CprPalette.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  node.isCompleted ? 'VIOLATO' : 'DA VIOLARE',
                  style: CprType.label.copyWith(
                    fontSize: 8.5,
                    color: node.isCompleted ? CprPalette.cyan : CprPalette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addFloor() {
    final int nextNum = _arch.floors.isEmpty ? 1 : (_arch.floors.last.floorNumber + 1);
    _arch.floors.add(
      NetFloor(
        floorNumber: nextNum,
        name: 'Piano $nextNum: Sottorete',
        isRevealed: false,
      ),
    );
    _notify();
  }

  Future<void> _editArchDetails() async {
    final TextEditingController nameCtrl = TextEditingController(text: _arch.name);
    final TextEditingController descCtrl = TextEditingController(text: _arch.description);
    final TextEditingController diffCtrl = TextEditingController(text: _arch.difficultyRating);

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text('Modifica Dettagli Rete', style: CprType.body.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome Rete')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrizione / Obiettivo')),
            const SizedBox(height: 10),
            TextField(controller: diffCtrl, decoration: const InputDecoration(labelText: 'Grado Difficoltà (es. DV 8)')),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          TechButton(
            label: 'Salva',
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (ok == true) {
      _arch.name = nameCtrl.text.trim();
      _arch.description = descCtrl.text.trim();
      _arch.difficultyRating = diffCtrl.text.trim();
      _notify();
    }
  }

  Future<void> _showAddNodeDialog(NetFloor floor) async {
    NetNodeType selectedType = NetNodeType.password;
    final TextEditingController nameCtrl = TextEditingController(text: 'Firewall');
    final TextEditingController descCtrl = TextEditingController();
    int dv = 8;
    NetIceProgram? selectedIce = NetIceProgram.presets[0];
    final List<NetDeviceType> selectedDevs = <NetDeviceType>[NetDeviceType.camera];

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return AlertDialog(
            backgroundColor: CprPalette.surface,
            title: Text(
              'Aggiungi Nodo al Piano ${floor.floorNumber}',
              style: CprType.body.copyWith(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<NetNodeType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo di Nodo'),
                      items: NetNodeType.values.map((NetNodeType t) {
                        return DropdownMenuItem<NetNodeType>(
                          value: t,
                          child: Text(t.label),
                        );
                      }).toList(),
                      onChanged: (NetNodeType? val) {
                        if (val != null) {
                          setModalState(() {
                            selectedType = val;
                            if (val == NetNodeType.blackIce) {
                              nameCtrl.text = selectedIce?.name ?? 'Black ICE';
                            } else if (val == NetNodeType.controlNode) {
                              nameCtrl.text = 'Nodo di Controllo Sistemi';
                            } else if (val == NetNodeType.file) {
                              nameCtrl.text = 'Archivio Dati Riservato';
                            } else if (val == NetNodeType.rootVirus) {
                              nameCtrl.text = 'Root Server';
                              dv = 10;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome Nodo')),
                    const SizedBox(height: 10),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrizione / Dettagli')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: dv,
                      decoration: const InputDecoration(labelText: 'Difficoltà (DV Interfaccia)'),
                      items: const <int>[6, 8, 10, 12, 14].map((int val) {
                        return DropdownMenuItem<int>(
                          value: val,
                          child: Text('DV $val ${val == 6 ? "(Facile)" : val == 8 ? "(Medio)" : val == 10 ? "(Difficile)" : "(Estremo)"}'),
                        );
                      }).toList(),
                      onChanged: (int? val) {
                        if (val != null) setModalState(() => dv = val);
                      },
                    ),
                    if (selectedType == NetNodeType.blackIce) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<NetIceProgram>(
                        initialValue: selectedIce,
                        decoration: const InputDecoration(labelText: 'Programma Black ICE'),
                        items: NetIceProgram.presets.map((NetIceProgram ice) {
                          return DropdownMenuItem<NetIceProgram>(
                            value: ice,
                            child: Text('${ice.name} (${ice.category})'),
                          );
                        }).toList(),
                        onChanged: (NetIceProgram? val) {
                          if (val != null) {
                            setModalState(() {
                              selectedIce = val;
                              nameCtrl.text = val.name;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
              TechButton(
                label: 'Aggiungi',
                variant: TechButtonVariant.primary,
                compact: true,
                onPressed: () {
                  final NetNode newNode = NetNode(
                    id: 'node_${DateTime.now().millisecondsSinceEpoch}',
                    type: selectedType,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    dv: dv,
                    ice: selectedType == NetNodeType.blackIce ? selectedIce : null,
                    devices: selectedType == NetNodeType.controlNode ? selectedDevs : const <NetDeviceType>[],
                  );
                  floor.nodes.add(newNode);
                  Navigator.of(ctx).pop();
                  _notify();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPresetsMenu() {
    _arch = NetArchitecture.defaultArchitecture();
    _notify();
  }
}
