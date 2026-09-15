/// Tipo di nodo all'interno di una architettura NET (Cyberpunk RED pag. 206-221).
enum NetNodeType {
  password,
  file,
  controlNode,
  blackIce,
  rootVirus;

  String get label {
    switch (this) {
      case NetNodeType.password:
        return 'Password / Firewall';
      case NetNodeType.file:
        return 'File di Dati';
      case NetNodeType.controlNode:
        return 'Nodo di Controllo';
      case NetNodeType.blackIce:
        return 'Black ICE';
      case NetNodeType.rootVirus:
        return 'Root / Virus Radice';
    }
  }
}

/// Dispositivo controllabile tramite un Nodo di Controllo nel mondo fisico.
enum NetDeviceType {
  camera('Telecamere di Sicurezza'),
  turret('Torretta Automatica Cal. .50'),
  door('Porta Blindata / Paratia MagLock'),
  elevator('Ascensori dell\'Edificio'),
  sprinklers('Impianto Antincendio / Gas Halon'),
  alarm('Sirene e Allarmi della Rete');

  const NetDeviceType(this.label);
  final String label;
}

/// Programma Black ICE installato come difesa attiva dell'architettura.
class NetIceProgram {
  const NetIceProgram({
    required this.name,
    required this.isAntiPersonnel,
    required this.speed,
    required this.attack,
    required this.defense,
    required this.rez,
    required this.effect,
  });

  final String name;
  final bool isAntiPersonnel;
  final int speed;
  final int attack;
  final int defense;
  final int rez;
  final String effect;

  String get category => isAntiPersonnel ? 'Anti-Personale' : 'Anti-Programma';

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'isAntiPersonnel': isAntiPersonnel,
        'speed': speed,
        'attack': attack,
        'defense': defense,
        'rez': rez,
        'effect': effect,
      };

  static NetIceProgram fromJson(Map<String, Object?> json) => NetIceProgram(
        name: '${json['name'] ?? ''}',
        isAntiPersonnel: json['isAntiPersonnel'] == true,
        speed: (json['speed'] as num?)?.toInt() ?? 4,
        attack: (json['attack'] as num?)?.toInt() ?? 4,
        defense: (json['defense'] as num?)?.toInt() ?? 2,
        rez: (json['rez'] as num?)?.toInt() ?? 15,
        effect: '${json['effect'] ?? ''}',
      );

  static const List<NetIceProgram> presets = <NetIceProgram>[
    NetIceProgram(
      name: 'Hellhound',
      isAntiPersonnel: true,
      speed: 6,
      attack: 6,
      defense: 2,
      rez: 15,
      effect: 'Brucia il cervello del Netrunner: 2d6 danni diretti e cervello in fiamme.',
    ),
    NetIceProgram(
      name: 'Raven',
      isAntiPersonnel: false,
      speed: 4,
      attack: 4,
      defense: 2,
      rez: 15,
      effect: 'Anti-programma rapido: de-rezza istantaneamente i programmi difensivi del cyberdeck.',
    ),
    NetIceProgram(
      name: 'Killer',
      isAntiPersonnel: false,
      speed: 6,
      attack: 6,
      defense: 2,
      rez: 20,
      effect: 'Distrugge permanentemente i programmi del Netrunner fino alla riparazione.',
    ),
    NetIceProgram(
      name: 'Skunk',
      isAntiPersonnel: true,
      speed: 2,
      attack: 4,
      defense: 2,
      rez: 10,
      effect: 'Disorienta il Netrunner infliggendo -2 a tutte le azioni finché non si disconnette.',
    ),
    NetIceProgram(
      name: 'Scorpion',
      isAntiPersonnel: true,
      speed: 2,
      attack: 2,
      defense: 2,
      rez: 15,
      effect: 'Inietta veleno neurale: riduce il Movimento fisico (MOV) nel mondo reale di 2 punti.',
    ),
    NetIceProgram(
      name: 'Giant',
      isAntiPersonnel: true,
      speed: 2,
      attack: 8,
      defense: 4,
      rez: 25,
      effect: 'Schiaffeggia la mente del Netrunner: 3d6 danni diretti e stordimento.',
    ),
    NetIceProgram(
      name: 'Dragon',
      isAntiPersonnel: false,
      speed: 6,
      attack: 6,
      defense: 6,
      rez: 30,
      effect: 'ICE pesante di classe militare Arasaka: incenerisce i programmi con attacco distruttivo.',
    ),
  ];
}

/// Singolo nodo interattivo su un piano della rete.
class NetNode {
  NetNode({
    required this.id,
    required this.type,
    this.name = '',
    this.description = '',
    this.dv = 8,
    this.ice,
    this.devices = const <NetDeviceType>[],
    this.isCompleted = false,
  });

  final String id;
  NetNodeType type;
  String name;
  String description;
  int dv;
  NetIceProgram? ice;
  List<NetDeviceType> devices;
  bool isCompleted;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'dv': dv,
        if (ice != null) 'ice': ice!.toJson(),
        'devices': devices.map((NetDeviceType d) => d.name).toList(),
        'isCompleted': isCompleted,
      };

  static NetNode fromJson(Map<String, Object?> json) {
    final String typeStr = '${json['type'] ?? ''}';
    final NetNodeType type = NetNodeType.values.firstWhere(
      (NetNodeType t) => t.name == typeStr,
      orElse: () => NetNodeType.password,
    );

    final List<dynamic> devList = json['devices'] is List ? (json['devices']! as List<dynamic>) : <dynamic>[];
    final List<NetDeviceType> devs = devList
        .map((dynamic d) => NetDeviceType.values.firstWhere(
              (NetDeviceType t) => t.name == '$d',
              orElse: () => NetDeviceType.camera,
            ))
        .toList();

    return NetNode(
      id: '${json['id'] ?? ''}',
      type: type,
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      dv: (json['dv'] as num?)?.toInt() ?? 8,
      ice: json['ice'] is Map
          ? NetIceProgram.fromJson(
              (json['ice']! as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v)),
            )
          : null,
      devices: devs,
      isCompleted: json['isCompleted'] == true,
    );
  }
}

/// Un piano (livello) dell'architettura NET.
class NetFloor {
  NetFloor({
    required this.floorNumber,
    this.name = '',
    this.isRevealed = false,
    List<NetNode>? nodes,
  }) : nodes = nodes ?? <NetNode>[];

  final int floorNumber;
  String name;

  /// Se true, il piano e i suoi nodi sono visibili al Netrunner (Fog of War disattivata per questo piano).
  bool isRevealed;

  final List<NetNode> nodes;

  Map<String, Object?> toJson() => <String, Object?>{
        'floorNumber': floorNumber,
        'name': name,
        'isRevealed': isRevealed,
        'nodes': nodes.map((NetNode n) => n.toJson()).toList(),
      };

  static NetFloor fromJson(Map<String, Object?> json) {
    final List<dynamic> rawNodes = json['nodes'] is List ? (json['nodes']! as List<dynamic>) : <dynamic>[];
    final List<NetNode> parsedNodes = rawNodes
        .whereType<Map>()
        .map((Map m) => NetNode.fromJson(m.map((Object? k, Object? v) => MapEntry(k.toString(), v))))
        .toList();

    return NetFloor(
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 1,
      name: '${json['name'] ?? ''}',
      isRevealed: json['isRevealed'] == true,
      nodes: parsedNodes,
    );
  }
}

/// Una intera architettura di rete NET pronta per essere giocata o creata dal Master.
class NetArchitecture {
  NetArchitecture({
    required this.id,
    required this.name,
    this.description = '',
    this.difficultyRating = 'Standard (DV 8)',
    List<NetFloor>? floors,
  }) : floors = floors ?? <NetFloor>[];

  final String id;
  String name;
  String description;
  String difficultyRating;
  final List<NetFloor> floors;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'description': description,
        'difficultyRating': difficultyRating,
        'floors': floors.map((NetFloor f) => f.toJson()).toList(),
      };

  static NetArchitecture fromJson(Map<String, Object?> json) {
    final List<dynamic> rawFloors = json['floors'] is List ? (json['floors']! as List<dynamic>) : <dynamic>[];
    final List<NetFloor> parsedFloors = rawFloors
        .whereType<Map>()
        .map((Map m) => NetFloor.fromJson(m.map((Object? k, Object? v) => MapEntry(k.toString(), v))))
        .toList();

    return NetArchitecture(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      difficultyRating: '${json['difficultyRating'] ?? 'Standard'}',
      floors: parsedFloors,
    );
  }

  /// Preset iniziale di esempio pronto all'uso per il Master.
  static NetArchitecture defaultArchitecture() {
    return NetArchitecture(
      id: 'arch_subnet_night_city_01',
      name: 'Subnet Uffici Biotechnica (Level 1)',
      description: 'Architettura privata di un laboratorio di ricerca secondario.',
      difficultyRating: 'Medio (DV 8)',
      floors: <NetFloor>[
        NetFloor(
          floorNumber: 1,
          name: 'Piano 1: Portale di Accesso DMZ',
          isRevealed: true,
          nodes: <NetNode>[
            NetNode(
              id: 'node_f1_pass',
              type: NetNodeType.password,
              name: 'Firewall d\'Ingresso',
              description: 'Password base del personale di portineria.',
              dv: 6,
            ),
          ],
        ),
        NetFloor(
          floorNumber: 2,
          name: 'Piano 2: Sorveglianza Perimetrale',
          isRevealed: false,
          nodes: <NetNode>[
            NetNode(
              id: 'node_f2_ctrl',
              type: NetNodeType.controlNode,
              name: 'Controllo Sistemi Fisici',
              description: 'Gestisce telecamere e serrature elettroniche.',
              dv: 8,
              devices: <NetDeviceType>[NetDeviceType.camera, NetDeviceType.door],
            ),
            NetNode(
              id: 'node_f2_ice',
              type: NetNodeType.blackIce,
              name: 'Sentinella Black ICE',
              dv: 8,
              ice: NetIceProgram.presets[1], // Raven
            ),
          ],
        ),
        NetFloor(
          floorNumber: 3,
          name: 'Piano 3: Server Dati & Ricerca',
          isRevealed: false,
          nodes: <NetNode>[
            NetNode(
              id: 'node_f3_file',
              type: NetNodeType.file,
              name: 'Progetto "Verde Notturno"',
              description: 'Documenti riservati sui nuovi innesti bio-sintetici.',
              dv: 8,
            ),
            NetNode(
              id: 'node_f3_ice',
              type: NetNodeType.blackIce,
              name: 'Segugio Infernale (Hellhound)',
              dv: 8,
              ice: NetIceProgram.presets[0], // Hellhound
            ),
          ],
        ),
        NetFloor(
          floorNumber: 4,
          name: 'Piano 4: Nodo Radice Centrale',
          isRevealed: false,
          nodes: <NetNode>[
            NetNode(
              id: 'node_f4_root',
              type: NetNodeType.rootVirus,
              name: 'Root Server & Mainframe',
              description: 'Permette di impiantare un Virus permanente o cancellare i log.',
              dv: 10,
            ),
          ],
        ),
      ],
    );
  }
}
