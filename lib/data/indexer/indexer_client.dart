import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import 'models.dart';

class IndexerException implements Exception {
  IndexerException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'IndexerException($statusCode): $message';
}

/// REST client for the Pinace indexer (port of Frontend/lib/indexer/client.ts):
/// short in-memory TTL cache + in-flight de-duplication keyed by full URL.
class IndexerClient {
  IndexerClient({http.Client? httpClient, this.cacheTtl = const Duration(seconds: 15)})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration cacheTtl;

  final _cache = <String, (DateTime, dynamic)>{};
  final _inFlight = <String, Future<dynamic>>{};

  Future<dynamic> _get(String path, [Map<String, String?>? query]) {
    final params = <String, String>{
      if (query != null)
        for (final e in query.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    final uri = Uri.parse('${Env.indexerUrl}$path')
        .replace(queryParameters: params.isEmpty ? null : params);
    final key = uri.toString();

    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < cacheTtl) {
      return Future.value(cached.$2);
    }
    return _inFlight.putIfAbsent(key, () async {
      try {
        final res = await _http.get(uri).timeout(const Duration(seconds: 15));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw IndexerException(res.statusCode, res.body);
        }
        final body = jsonDecode(res.body);
        _cache[key] = (DateTime.now(), body);
        return body;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  /// Drop cached responses; optionally only those whose URL contains [prefix].
  void invalidate([String? prefix]) {
    if (prefix == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((key, _) => key.contains(prefix));
    }
  }

  Future<Pool> getPool(String poolId) async =>
      Pool.fromJson(await _get('/pools/$poolId') as Map<String, dynamic>);

  Future<Paginated<Agent>> getAgents({
    String? owner,
    String? poolId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async =>
      Paginated.fromJson(
        await _get('/agents', {
          'owner': owner,
          'poolId': poolId,
          'status': status,
          'page': '$page',
          'limit': '$limit',
        }) as Map<String, dynamic>,
        Agent.fromJson,
      );

  Future<Agent> getAgent(String agentId) async =>
      Agent.fromJson(await _get('/agents/$agentId') as Map<String, dynamic>);

  Future<AgentTimeline> getAgentTimeline(String agentId, {String? before}) async =>
      AgentTimeline.fromJson(
        await _get('/agents/$agentId/timeline', {'before': before})
            as Map<String, dynamic>,
      );

  Future<Paginated<ActionDto>> getActions({
    String? poolId,
    String? agentAddress,
    String? status,
    String? kind,
    int page = 1,
    int limit = 20,
  }) async =>
      Paginated.fromJson(
        await _get('/actions', {
          'poolId': poolId,
          'agentAddress': agentAddress,
          'status': status,
          'kind': kind,
          'page': '$page',
          'limit': '$limit',
        }) as Map<String, dynamic>,
        ActionDto.fromJson,
      );

  Future<Paginated<EventLog>> getEvents({
    String? poolId,
    String? agentAddress,
    String? eventType,
    int page = 1,
    int limit = 50,
  }) async =>
      Paginated.fromJson(
        await _get('/events', {
          'poolId': poolId,
          'agentAddress': agentAddress,
          'eventType': eventType,
          'page': '$page',
          'limit': '$limit',
        }) as Map<String, dynamic>,
        EventLog.fromJson,
      );

  Future<OwnerStats> getOwnerStats(String address) async => OwnerStats.fromJson(
      await _get('/owners/$address/stats') as Map<String, dynamic>);
}
