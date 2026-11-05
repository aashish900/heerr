import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/jam.dart';
import 'package:heerr/services/backend_service.dart';

// JM4: jam endpoints, same scripted-adapter pattern as backend_service_test.

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastRequest = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

(BackendService, _FakeAdapter) _service(
  FutureOr<ResponseBody> Function(RequestOptions) responder,
) {
  final _FakeAdapter adapter = _FakeAdapter(responder);
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
  return (BackendService(dio), adapter);
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

void main() {
  test('jamCreate POSTs /jam and parses the session', () async {
    final (BackendService s, _FakeAdapter a) = _service((_) => _json(
        '{"id":"s1","code":"K7Q2MX","expires_at":"2026-11-05T12:00:00Z"}',
        201));
    final JamSession js = await s.jamCreate();
    expect(a.lastRequest!.method, 'POST');
    expect(a.lastRequest!.path, '/jam');
    expect(js.id, 's1');
    expect(js.code, 'K7Q2MX');
  });

  test('jamEnd DELETEs /jam/{id}', () async {
    final (BackendService s, _FakeAdapter a) =
        _service((_) => ResponseBody.fromString('', 204));
    await s.jamEnd('s1');
    expect(a.lastRequest!.method, 'DELETE');
    expect(a.lastRequest!.path, '/jam/s1');
  });

  test('jamJoin sends the code; 404 maps to NotFoundError', () async {
    final (BackendService s, _FakeAdapter a) = _service((_) => _json(
        '{"id":"s1","host_username":"aashish",'
        '"expires_at":"2026-11-05T12:00:00Z"}',
        200));
    final JamJoin j = await s.jamJoin('k7q2mx');
    expect(jsonEncode(a.lastRequest!.data), '{"code":"k7q2mx"}');
    expect(j.hostUsername, 'aashish');

    final (BackendService s2, _) =
        _service((_) => _json('{"detail":"no active jam session"}', 404));
    await expectLater(s2.jamJoin('nope'), throwsA(isA<NotFoundError>()));
  });

  test('jamSend POSTs kind + payload and returns the id', () async {
    final (BackendService s, _FakeAdapter a) =
        _service((_) => _json('{"id":7}', 201));
    final int id =
        await s.jamSend('s1', 'seek', <String, dynamic>{'position_ms': 10});
    expect(a.lastRequest!.path, '/jam/s1/commands');
    expect(jsonEncode(a.lastRequest!.data),
        '{"kind":"seek","payload":{"position_ms":10}}');
    expect(id, 7);
  });

  test('jamSync sends explicit null after and parses commands', () async {
    final (BackendService s, _FakeAdapter a) = _service((_) => _json(
        '{"commands":[{"id":3,"kind":"pause","payload":{},"sender":"g"}],'
        '"cursor":3,"ended":false}',
        200));
    final JamSyncResponse r = await s.jamSync('s1', state: null, after: null);
    expect(a.lastRequest!.path, '/jam/s1/sync');
    expect(jsonEncode(a.lastRequest!.data), '{"state":null,"after":null}');
    expect(r.cursor, 3);
    expect(r.commands.single.kind, 'pause');
    expect(r.commands.single.sender, 'g');
  });

  test('jamState GETs /jam/{id}/state', () async {
    final (BackendService s, _FakeAdapter a) = _service((_) => _json(
        '{"state":{"playing":true},"state_at":null,'
        '"host_username":"aashish","ended":false}',
        200));
    final JamState st = await s.jamState('s1');
    expect(a.lastRequest!.method, 'GET');
    expect(a.lastRequest!.path, '/jam/s1/state');
    expect(st.state!['playing'], true);
    expect(st.ended, false);
  });
}
