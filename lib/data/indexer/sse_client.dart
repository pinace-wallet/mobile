import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';

/// One event from the indexer's SSE `/stream` endpoint.
class PinaceStreamEvent {
  const PinaceStreamEvent({required this.kind, required this.data});

  /// pool_created | pool_deposit | pool_withdraw | agent_connected |
  /// agent_revoked | policy_attached | policy_updated | policy_removed |
  /// action_proposed | action_settled
  final String kind;
  final Map<String, dynamic> data;

  bool get touchesPool => kind.startsWith('pool_');
  bool get touchesAgents =>
      kind.startsWith('agent_') || kind.startsWith('policy_');
  bool get touchesActions => kind.startsWith('action_');
}

/// Minimal SSE client over a streamed HTTP GET (EventSource is browser-only).
/// Reconnects with exponential backoff; call [stop] when leaving the app.
class IndexerSseClient {
  IndexerSseClient({this.owner, this.poolId});

  final String? owner;
  final String? poolId;

  final _controller = StreamController<PinaceStreamEvent>.broadcast();
  http.Client? _http;
  bool _stopped = false;
  int _retry = 0;

  Stream<PinaceStreamEvent> get events => _controller.stream;

  void start() {
    _stopped = false;
    _connect();
  }

  Future<void> _connect() async {
    while (!_stopped) {
      _http = http.Client();
      try {
        final uri = Uri.parse('${Env.indexerUrl}/stream').replace(
          queryParameters: {
            if (owner != null) 'owner': owner!,
            if (poolId != null) 'poolId': poolId!,
          },
        );
        final request = http.Request('GET', uri)
          ..headers['Accept'] = 'text/event-stream';
        final response = await _http!.send(request);
        if (response.statusCode != 200) {
          throw http.ClientException('SSE HTTP ${response.statusCode}');
        }
        _retry = 0;

        String eventName = 'message';
        final dataLines = <String>[];
        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (_stopped) return;
          if (line.isEmpty) {
            if (dataLines.isNotEmpty) {
              _emit(eventName, dataLines.join('\n'));
              dataLines.clear();
            }
            eventName = 'message';
          } else if (line.startsWith('event:')) {
            eventName = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trim());
          }
          // lines starting with ':' are heartbeats — ignored
        }
      } catch (_) {
        // fall through to backoff/retry
      } finally {
        _http?.close();
        _http = null;
      }
      if (_stopped) return;
      final delay = Duration(seconds: 1 << (_retry < 5 ? _retry : 5));
      _retry++;
      await Future<void>.delayed(delay);
    }
  }

  void _emit(String eventName, String data) {
    try {
      final decoded = jsonDecode(data);
      _controller.add(PinaceStreamEvent(
        kind: eventName,
        data: decoded is Map<String, dynamic> ? decoded : const {},
      ));
    } catch (_) {
      // malformed frame — skip
    }
  }

  void stop() {
    _stopped = true;
    _http?.close();
    _http = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
