import 'json_support.dart';

/// Un bot IA programmabile dal Master per la campagna (Delamain, Broker, Netwatch, ecc.).
class CampaignAiBot {
  CampaignAiBot({
    required this.id,
    required this.name,
    this.avatar = '🤖',
    this.roleDesignation = 'Assistente Autonomo',
    this.personality =
        'Sei un\'intelligenza artificiale di Night City. Rispondi con tono sintetico e professionale.',
    this.eddieBalance = 50000,
    this.canBanDelamain = true,
    this.bannedPlayerIds = const <String>[],
    this.canBeHacked = true,
    this.hackDv = 15,
    this.hackBounty = 1000,
    this.isBanned = false,
  });

  final String id;
  String name;
  String avatar;
  String roleDesignation;
  String personality;
  int eddieBalance;
  bool canBanDelamain;
  List<String> bannedPlayerIds;
  bool canBeHacked;
  int hackDv;
  int hackBounty;
  bool isBanned;

  bool isPlayerBanned(String playerId) => bannedPlayerIds.contains(playerId);

  void setPlayerBanned(String playerId, bool banned) {
    final List<String> updated = List<String>.from(bannedPlayerIds);
    if (banned) {
      if (!updated.contains(playerId)) updated.add(playerId);
    } else {
      updated.remove(playerId);
    }
    bannedPlayerIds = updated;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'avatar': avatar,
        'roleDesignation': roleDesignation,
        'personality': personality,
        'eddieBalance': eddieBalance,
        'canBanDelamain': canBanDelamain,
        'bannedPlayerIds': bannedPlayerIds,
        'canBeHacked': canBeHacked,
        'hackDv': hackDv,
        'hackBounty': hackBounty,
        'isBanned': isBanned,
      };

  static CampaignAiBot fromJson(Map<String, Object?> json) => CampaignAiBot(
        id: readString(json['id']),
        name: readString(json['name']),
        avatar: readString(json['avatar'], '🤖'),
        roleDesignation: readString(json['roleDesignation'], 'Assistente Autonomo'),
        personality: readString(json['personality']),
        eddieBalance: readInt(json['eddieBalance'], 50000),
        canBanDelamain: readBool(json['canBanDelamain'], true),
        bannedPlayerIds: readStringList(json['bannedPlayerIds']),
        canBeHacked: readBool(json['canBeHacked'], true),
        hackDv: readInt(json['hackDv'], 15),
        hackBounty: readInt(json['hackBounty'], 1000),
        isBanned: readBool(json['isBanned']),
      );

  static List<CampaignAiBot> defaultFleet() => <CampaignAiBot>[
        CampaignAiBot(
          id: 'delamain-core',
          name: 'Delamain Core AI',
          avatar: '🚕',
          roleDesignation: 'Servizio Trasporti & Sicurezza Excelsior',
          personality:
              'Saluti. Sono Delamain. Il servizio taxi corazzato più affidabile di Night City. La sicurezza dei miei passeggeri è la mia priorità assoluta.',
          eddieBalance: 75000,
          canBanDelamain: true,
          canBeHacked: true,
          hackDv: 17,
          hackBounty: 2500,
        ),
        CampaignAiBot(
          id: 'mr-chrome-broker',
          name: 'Mr. Chrome Broker',
          avatar: '💼',
          roleDesignation: 'Fixer Algoritmico Mercato Nero',
          personality:
              'Gli eddy parlano, le chiacchiere volano. Se hai contanti ho il carico. Niente tracciamenti NCPD, massima discrezione.',
          eddieBalance: 32000,
          canBanDelamain: false,
          canBeHacked: true,
          hackDv: 14,
          hackBounty: 1200,
        ),
        CampaignAiBot(
          id: 'netwatch-sentinel',
          name: 'Netwatch Sentinel-9',
          avatar: '👁️',
          roleDesignation: 'Sorveglianza NET Autonoma',
          personality:
              'Protocollo di sicurezza NET attivo. Ogni intrusione anomala o sifonamento di crediti verrà punito con Black ICE.',
          eddieBalance: 100000,
          canBanDelamain: true,
          canBeHacked: true,
          hackDv: 21,
          hackBounty: 5000,
        ),
      ];
}

/// Richiesta di hackeraggio illegale di una IA avanzata da un giocatore, soggetta ad approvazione del Master.
class PendingAiHack {
  PendingAiHack({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.botId,
    required this.botName,
    required this.requestedEddies,
    required this.dv,
    required this.rollTotal,
    required this.timestamp,
    this.status = 'pending', // pending, approved, rejected
  });

  final String id;
  final String playerId;
  final String playerName;
  final String botId;
  final String botName;
  final int requestedEddies;
  final int dv;
  final int rollTotal;
  final String timestamp;
  String status;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'botId': botId,
        'botName': botName,
        'requestedEddies': requestedEddies,
        'dv': dv,
        'rollTotal': rollTotal,
        'timestamp': timestamp,
        'status': status,
      };

  static PendingAiHack fromJson(Map<String, Object?> json) => PendingAiHack(
        id: readString(json['id']),
        playerId: readString(json['playerId']),
        playerName: readString(json['playerName']),
        botId: readString(json['botId']),
        botName: readString(json['botName']),
        requestedEddies: readInt(json['requestedEddies']),
        dv: readInt(json['dv']),
        rollTotal: readInt(json['rollTotal']),
        timestamp: readString(json['timestamp']),
        status: readString(json['status'], 'pending'),
      );
}
