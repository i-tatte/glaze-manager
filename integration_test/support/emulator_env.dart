import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// 実機確認用の Firebase エミュレータの接続先。
///
/// 実プロジェクト (glaze-manager) には一切つながない。プロジェクト ID を
/// `demo-` で始めているので、エミュレータにつながらなかった場合も、実在しない
/// プロジェクトへの通信として失敗するだけである。端末内のキャッシュと
/// サインイン状態もプロジェクト ID ごとに分かれるので、実アプリのものとは
/// 混ざらない。
const emulatorProjectId = 'demo-glaze-manager';
const emulatorBucket = 'demo-glaze-manager.appspot.com';
const emulatorHost = '127.0.0.1';
const authEmulatorPort = 9099;

/// 管理用の REST は、常に動いているエミュレータに送る。
const liveFirestorePort = 8080;
const liveStoragePort = 9199;

/// アプリ (SDK) がつなぐ Firestore のポート。誰も待ち受けていないポートを
/// 指定すると、「サーバーに届かない」状態を再現できる。
const sdkFirestorePort = int.fromEnvironment(
  'GM_FIRESTORE_PORT',
  defaultValue: liveFirestorePort,
);

/// アプリが写真を送る先の Storage のポート。
const sdkStoragePort = int.fromEnvironment(
  'GM_STORAGE_PORT',
  defaultValue: liveStoragePort,
);

/// 結果の JSON を書き出すディレクトリ。空なら書き出さない。
const reportDir = String.fromEnvironment('GM_REPORT_DIR');

/// 起動をまたいで値を渡すためのファイルを置くディレクトリ。
const stateDir = String.fromEnvironment('GM_STATE_DIR');

const _adminHeaders = {'Authorization': 'Bearer owner'};

Future<void> initFirebaseForEmulators() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:000000000000:web:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: emulatorProjectId,
      storageBucket: emulatorBucket,
    ),
  );
  if (Firebase.app().options.projectId != emulatorProjectId) {
    throw StateError('実機確認はデモ用のプロジェクトでしか動かさない');
  }
  // アプリの main() と同じ設定
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(
    emulatorHost,
    sdkFirestorePort,
  );
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authEmulatorPort);
  // Functions は本番と同じく firebasestorage.googleapis.com を指す URL を
  // 書き戻す。アプリが表示のために読みにいく先を Storage エミュレータに
  // 読み替える (読み替えないと実在しないバケットへの 404 になる)。
  HttpOverrides.global = _EmulatorHttpOverrides();
}

/// 本番の Storage のダウンロード URL を、Storage エミュレータへ読み替える。
Uri rewriteStorageUrl(Uri url) => url.host == 'firebasestorage.googleapis.com'
    ? url.replace(scheme: 'http', host: emulatorHost, port: sdkStoragePort)
    : url;

class _EmulatorHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _RewritingHttpClient(super.createHttpClient(context));
}

/// URL だけを読み替えて、残りはそのまま本物の HttpClient に任せる。
class _RewritingHttpClient implements HttpClient {
  _RewritingHttpClient(this._inner);

  final HttpClient _inner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _inner.openUrl(method, rewriteStorageUrl(url));
  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  void close({bool force = false}) => _inner.close(force: force);
  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;
  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials c) =>
      _inner.addCredentials(url, realm, c);
  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials c,
  ) => _inner.addProxyCredentials(host, port, realm, c);
  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;
  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;
  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;
  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;
  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;
  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
}

/// 新しい利用者を作ってサインインする。
Future<User> signUpFreshUser() async {
  if (FirebaseAuth.instance.currentUser != null) {
    await FirebaseAuth.instance.signOut();
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: 'it-$stamp@example.com',
    password: 'password-$stamp',
  );
  return credential.user!;
}

/// Windows の firebase_storage はエミュレータにつなげない (C++ SDK が未対応)。
/// 送信だけを Storage エミュレータの REST に差し替える。送り先のパスは
/// 本物の [StorageService.getUploadPath] をそのまま使う。
class EmulatorStorageService extends StorageService {
  EmulatorStorageService({this.port = sdkStoragePort});

  final int port;

  /// 送信を試みたパス (成否を問わない)
  final attempts = <String>[];

  /// 送信に成功したパスと、その時刻
  final uploads = <String, DateTime>{};

  @override
  Future<void> uploadTestPieceImage({
    required String testPieceId,
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final path = getUploadPath(testPieceId: testPieceId, name: name);
    attempts.add(path);
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final contentType = mimeType ?? 'application/octet-stream';
    final boundary = 'gmit${DateTime.now().microsecondsSinceEpoch}';
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=utf-8\r\n\r\n'
          '${jsonEncode({'name': path, 'contentType': contentType})}\r\n'
          '--$boundary\r\n'
          'Content-Type: $contentType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final response = await http.post(
      Uri.parse(
        'http://$emulatorHost:$port/v0/b/$emulatorBucket/o'
        '?name=${Uri.encodeQueryComponent(path)}',
      ),
      headers: {
        'Content-Type': 'multipart/related; boundary=$boundary',
        'X-Goog-Upload-Protocol': 'multipart',
        'Authorization': 'Firebase $token',
      },
      body: body.takeBytes(),
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'Storage emulator upload failed: '
        '${response.statusCode} ${response.body}',
      );
    }
    uploads[path] = DateTime.now();
  }

  @override
  Future<void> deleteTestPieceImage(String imageUrl) async {}

  @override
  Future<void> deleteAllTestPieceFiles(String testPieceId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    for (final dir in ['images', 'thumbnails']) {
      for (final name in await adminListObjects(
        'users/$uid/test_pieces/$dir/$testPieceId/',
      )) {
        await http.delete(
          Uri.parse(
            'http://$emulatorHost:$liveStoragePort/storage/v1/b/'
            '$emulatorBucket/o/${Uri.encodeComponent(name)}',
          ),
          headers: _adminHeaders,
        );
      }
    }
  }
}

// --- エミュレータの管理用 REST (SDK を通さずにサーバー側の状態を見る) ---

Uri _docUri(String docPath, [Map<String, dynamic>? query]) => Uri.parse(
  'http://$emulatorHost:$liveFirestorePort/v1/projects/$emulatorProjectId'
  '/databases/(default)/documents/$docPath',
).replace(queryParameters: query);

Object? _fromValue(Map<String, dynamic> value) {
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('integerValue')) {
    return int.parse(value['integerValue'] as String);
  }
  if (value.containsKey('doubleValue')) {
    return (value['doubleValue'] as num).toDouble();
  }
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('timestampValue')) {
    return DateTime.parse(value['timestampValue'] as String);
  }
  if (value.containsKey('arrayValue')) {
    final values = (value['arrayValue'] as Map)['values'] as List? ?? const [];
    return [for (final v in values) _fromValue(v as Map<String, dynamic>)];
  }
  if (value.containsKey('mapValue')) {
    final fields = (value['mapValue'] as Map)['fields'] as Map? ?? const {};
    return {
      for (final e in fields.entries)
        e.key as String: _fromValue(e.value as Map<String, dynamic>),
    };
  }
  return value;
}

Map<String, dynamic> _toValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is List) {
    return {
      'arrayValue': {
        'values': [for (final v in value) _toValue(v)],
      },
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': {
          for (final e in value.entries) '${e.key}': _toValue(e.value),
        },
      },
    };
  }
  throw ArgumentError('unsupported value: $value');
}

/// サーバー側の文書を読む。なければ null。
Future<Map<String, dynamic>?> adminGetDoc(String docPath) async {
  final response = await http.get(_docUri(docPath), headers: _adminHeaders);
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw HttpException('adminGetDoc $docPath: ${response.statusCode}');
  }
  final fields =
      (jsonDecode(response.body) as Map<String, dynamic>)['fields'] as Map? ??
      const {};
  return {
    for (final e in fields.entries)
      e.key as String: _fromValue(e.value as Map<String, dynamic>),
  };
}

/// サーバー側に文書を直接書く (アプリを通さずに既存データを用意する)。
Future<void> adminSetDoc(String docPath, Map<String, dynamic> fields) async {
  final response = await http.patch(
    _docUri(docPath),
    headers: {..._adminHeaders, 'Content-Type': 'application/json'},
    body: jsonEncode({
      'fields': {for (final e in fields.entries) e.key: _toValue(e.value)},
    }),
  );
  if (response.statusCode != 200) {
    throw HttpException(
      'adminSetDoc $docPath: ${response.statusCode} ${response.body}',
    );
  }
}

/// サーバー側のコレクションの文書 ID の一覧。
Future<List<String>> adminListDocIds(String collectionPath) async {
  final response = await http.get(
    _docUri(collectionPath, {'pageSize': '300'}),
    headers: _adminHeaders,
  );
  if (response.statusCode != 200) {
    throw HttpException('adminListDocIds: ${response.statusCode}');
  }
  final documents =
      (jsonDecode(response.body) as Map<String, dynamic>)['documents']
          as List? ??
      const [];
  return [
    for (final d in documents) ((d as Map)['name'] as String).split('/').last,
  ];
}

/// Storage エミュレータにあるファイルの名前の一覧。
Future<List<String>> adminListObjects(String prefix) async {
  final response = await http.get(
    Uri.parse(
      'http://$emulatorHost:$liveStoragePort/storage/v1/b/$emulatorBucket/o',
    ).replace(queryParameters: {'prefix': prefix}),
    headers: _adminHeaders,
  );
  if (response.statusCode != 200) {
    throw HttpException('adminListObjects: ${response.statusCode}');
  }
  final items =
      (jsonDecode(response.body) as Map<String, dynamic>)['items'] as List? ??
      const [];
  return [for (final i in items) (i as Map)['name'] as String]..sort();
}

// --- 結果の記録 ---

/// 測った値と確かめた結果を、コンソールと JSON の両方に残す。
class Report {
  Report(this.name);

  final String name;
  final Map<String, Object?> values = {};

  void add(String key, Object? value) {
    values[key] = value;
    // ignore: avoid_print
    print('[gm-it] $name: $key = $value');
  }

  Future<void> flush() async {
    if (reportDir.isEmpty) return;
    final file = File(p.join(reportDir, '$name.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(values),
      flush: true,
    );
  }
}

/// 起動をまたいで渡す値を読む。なければ空。
Future<Map<String, dynamic>> readState(String name) async {
  if (stateDir.isEmpty) throw StateError('GM_STATE_DIR is not set');
  final file = File(p.join(stateDir, '$name.json'));
  if (!await file.exists()) return {};
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

/// 起動をまたいで渡す値を書く。
Future<void> writeState(String name, Map<String, dynamic> state) async {
  if (stateDir.isEmpty) throw StateError('GM_STATE_DIR is not set');
  final file = File(p.join(stateDir, '$name.json'));
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(state), flush: true);
}

/// 条件が成り立つまで待つ。成り立ったら経過時間を、時間切れなら null を返す。
Future<Duration?> waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 60),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    if (await condition()) return watch.elapsed;
    await Future<void>.delayed(interval);
  }
  return null;
}

/// 通信できないことを表す失敗か (FirebaseException の code を見る)。
String describeError(Object error) => error is FirebaseException
    ? 'FirebaseException(${error.plugin}/${error.code})'
    : '${error.runtimeType}: $error';
