/// Dart mirrors of the indexer DTOs (Frontend/lib/indexer/types.ts).
/// Amounts stay as decimal strings; parse to BigInt at display/compute time.
library;

class PoolBalance {
  const PoolBalance({required this.coinType, required this.amount});

  final String coinType;
  final String amount;

  factory PoolBalance.fromJson(Map<String, dynamic> json) => PoolBalance(
        coinType: json['coinType'] as String,
        amount: json['amount'] as String,
      );

  BigInt get amountMist => BigInt.tryParse(amount) ?? BigInt.zero;
}

class Pool {
  const Pool({
    required this.poolId,
    required this.owner,
    required this.status,
    required this.protocolVersion,
    required this.createdAt,
    required this.balances,
  });

  final String poolId;
  final String owner;
  final String status;
  final int protocolVersion;
  final String createdAt; // ISO string
  final List<PoolBalance> balances;

  factory Pool.fromJson(Map<String, dynamic> json) => Pool(
        poolId: json['poolId'] as String,
        owner: json['owner'] as String,
        status: json['status'] as String,
        protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] as String? ?? '',
        balances: (json['balances'] as List<dynamic>? ?? [])
            .map((b) => PoolBalance.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  BigInt balanceOf(String coinType) => balances
      .where((b) => b.coinType == coinType || '0x${b.coinType}' == coinType)
      .fold(BigInt.zero, (sum, b) => sum + b.amountMist);
}

class AgentPolicy {
  const AgentPolicy({
    required this.id,
    required this.policyType,
    required this.configHash,
    required this.marketplaceId,
    required this.config,
    required this.status,
    required this.attachedAt,
    required this.updatedAt,
    required this.removedAt,
  });

  final String id;
  final String policyType;
  final String? configHash;
  final String? marketplaceId;

  /// Denormalized on-chain config, snake_case keys
  /// (e.g. max_per_tx, max_per_window, window_ms, spent_in_window).
  final Map<String, dynamic>? config;
  final String status;
  final int? attachedAt;
  final int? updatedAt;
  final int? removedAt;

  factory AgentPolicy.fromJson(Map<String, dynamic> json) => AgentPolicy(
        id: json['id'] as String,
        policyType: json['policyType'] as String,
        configHash: json['configHash'] as String?,
        marketplaceId: json['marketplaceId'] as String?,
        config: json['config'] as Map<String, dynamic>?,
        status: json['status'] as String? ?? 'attached',
        attachedAt: (json['attachedAt'] as num?)?.toInt(),
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
        removedAt: (json['removedAt'] as num?)?.toInt(),
      );

  bool get isSpendingLimit => policyType.contains('spending_limit_policy');

  BigInt? configValue(String key) {
    final v = config?[key];
    if (v == null) return null;
    return BigInt.tryParse(v.toString());
  }
}

class Agent {
  const Agent({
    required this.id,
    required this.address,
    required this.poolId,
    required this.owner,
    required this.name,
    required this.status,
    required this.runStatus,
    required this.expiresMs,
    required this.connectedAt,
    required this.revokedAt,
    required this.actionCount,
    required this.lastActiveAt,
    this.policies,
  });

  final String id;
  final String address;
  final String poolId;
  final String owner;
  final String name;
  final String status; // active | revoked
  final String runStatus; // running | done | idle
  final int expiresMs;
  final int? connectedAt;
  final int? revokedAt;
  final int actionCount;
  final int? lastActiveAt;
  final List<AgentPolicy>? policies;

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        id: json['id'] as String,
        address: json['address'] as String,
        poolId: json['poolId'] as String,
        owner: json['owner'] as String,
        name: json['name'] as String? ?? json['address'] as String,
        status: json['status'] as String? ?? 'active',
        runStatus: json['runStatus'] as String? ?? 'idle',
        expiresMs: (json['expiresMs'] as num?)?.toInt() ?? 0,
        connectedAt: (json['connectedAt'] as num?)?.toInt(),
        revokedAt: (json['revokedAt'] as num?)?.toInt(),
        actionCount: (json['actionCount'] as num?)?.toInt() ?? 0,
        lastActiveAt: (json['lastActiveAt'] as num?)?.toInt(),
        policies: (json['policies'] as List<dynamic>?)
            ?.map((p) => AgentPolicy.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  bool get isRevoked => status == 'revoked';
}

class ActionDto {
  const ActionDto({
    required this.id,
    required this.poolId,
    required this.agentAddress,
    required this.nonce,
    required this.kind,
    required this.amountIn,
    required this.minAmountOut,
    required this.quotedAmountOut,
    required this.settlementStatus,
    required this.status,
    required this.proposedAt,
    required this.settledAt,
  });

  final String id;
  final String poolId;
  final String agentAddress;
  final int nonce;
  final String kind; // swap | withdraw | deposit | unknown
  final String amountIn;
  final String minAmountOut;
  final String? quotedAmountOut;
  final int? settlementStatus; // 1 = success
  final String status; // proposed | settled
  final int? proposedAt;
  final int? settledAt;

  factory ActionDto.fromJson(Map<String, dynamic> json) => ActionDto(
        id: json['id'] as String,
        poolId: json['poolId'] as String,
        agentAddress: json['agentAddress'] as String,
        nonce: (json['nonce'] as num?)?.toInt() ?? 0,
        kind: json['kind'] as String? ?? 'unknown',
        amountIn: json['amountIn'] as String? ?? '0',
        minAmountOut: json['minAmountOut'] as String? ?? '0',
        quotedAmountOut: json['quotedAmountOut'] as String?,
        settlementStatus: (json['settlementStatus'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'proposed',
        proposedAt: (json['proposedAt'] as num?)?.toInt(),
        settledAt: (json['settledAt'] as num?)?.toInt(),
      );

  bool get isSuccess => settlementStatus == 1;
}

class EventLog {
  const EventLog({
    required this.id,
    required this.eventType,
    required this.poolId,
    required this.agentAddress,
    required this.nonce,
    required this.txDigest,
    required this.checkpointSeq,
    required this.timestamp,
    this.action,
  });

  final String id;
  final String eventType;
  final String poolId;
  final String? agentAddress;
  final int? nonce;
  final String txDigest;
  final int checkpointSeq;
  final String timestamp; // ISO string
  final ActionDto? action;

  factory EventLog.fromJson(Map<String, dynamic> json) => EventLog(
        id: json['id'] as String,
        eventType: json['eventType'] as String,
        poolId: json['poolId'] as String,
        agentAddress: json['agentAddress'] as String?,
        nonce: (json['nonce'] as num?)?.toInt(),
        txDigest: json['txDigest'] as String? ?? '',
        checkpointSeq: (json['checkpointSeq'] as num?)?.toInt() ?? 0,
        timestamp: json['timestamp'] as String? ?? '',
        action: json['action'] == null
            ? null
            : ActionDto.fromJson(json['action'] as Map<String, dynamic>),
      );

  DateTime get time => DateTime.tryParse(timestamp) ?? DateTime.now();
}

class Milestone {
  const Milestone({
    required this.id,
    required this.agentId,
    required this.action,
    required this.amount,
    required this.coinType,
    required this.timestamp,
    required this.status,
    this.txDigest,
  });

  final String id;
  final String agentId;
  final String action;
  final String amount;
  final String coinType;
  final int timestamp;
  final String status; // success | reverted | pending
  final String? txDigest;

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        agentId: json['agentId'] as String? ?? '',
        action: json['action'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
        coinType: json['coinType'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'pending',
        txDigest: json['txDigest'] as String?,
      );
}

class TimelineSummary {
  const TimelineSummary({
    required this.actionCount,
    required this.successRate,
    required this.lastActiveAt,
  });

  final int actionCount;
  final double? successRate;
  final int? lastActiveAt;

  factory TimelineSummary.fromJson(Map<String, dynamic> json) =>
      TimelineSummary(
        actionCount: (json['actionCount'] as num?)?.toInt() ?? 0,
        successRate: (json['successRate'] as num?)?.toDouble(),
        lastActiveAt: (json['lastActiveAt'] as num?)?.toInt(),
      );
}

class AgentTimeline {
  const AgentTimeline({
    required this.events,
    required this.milestones,
    required this.summary,
    required this.hasMore,
  });

  final List<EventLog> events;
  final List<Milestone> milestones;
  final TimelineSummary summary;
  final bool hasMore;

  factory AgentTimeline.fromJson(Map<String, dynamic> json) => AgentTimeline(
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) => EventLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        milestones: (json['milestones'] as List<dynamic>? ?? [])
            .map((m) => Milestone.fromJson(m as Map<String, dynamic>))
            .toList(),
        summary: TimelineSummary.fromJson(
            json['summary'] as Map<String, dynamic>? ?? const {}),
        hasMore: json['hasMore'] as bool? ?? false,
      );
}

class OwnerStats {
  const OwnerStats({
    required this.owner,
    required this.totalAgents,
    required this.executingCount,
    required this.successCount,
    required this.settledCount,
    required this.inFlightCount,
    required this.successRate,
  });

  final String owner;
  final int totalAgents;
  final int executingCount;
  final int successCount;
  final int settledCount;
  final int inFlightCount;
  final double? successRate;

  factory OwnerStats.fromJson(Map<String, dynamic> json) => OwnerStats(
        owner: json['owner'] as String? ?? '',
        totalAgents: (json['totalAgents'] as num?)?.toInt() ?? 0,
        executingCount: (json['executingCount'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        settledCount: (json['settledCount'] as num?)?.toInt() ?? 0,
        inFlightCount: (json['inFlightCount'] as num?)?.toInt() ?? 0,
        successRate: (json['successRate'] as num?)?.toDouble(),
      );
}

class Paginated<T> {
  const Paginated({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<T> data;
  final int total;
  final int page;
  final int limit;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      Paginated(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );

  bool get hasMore => page * limit < total;
}
