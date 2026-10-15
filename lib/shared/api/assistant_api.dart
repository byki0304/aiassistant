import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../logic/domain.dart';

class AssistantApi {
  AssistantApi({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'aiassistant'),
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String name) {
    final current = uid;
    if (current == null) {
      throw StateError('unauthenticated');
    }
    return _firestore.collection('users').doc(current).collection(name);
  }

  Stream<List<ScheduleItem>> watchSchedules() {
    return _col('schedules').orderBy('startAt').snapshots().map(
          (snap) => snap.docs.map(ScheduleItem.fromDoc).toList(),
        );
  }

  Stream<List<BalanceItem>> watchBalances() {
    return _col('balance_entries').orderBy('occurredAt').snapshots().map(
          (snap) => snap.docs.map(BalanceItem.fromDoc).toList(),
        );
  }

  Stream<List<NewsItem>> watchNews() {
    return _col('news_items').orderBy('publishedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(NewsItem.fromDoc).toList(),
        );
  }

  Stream<List<WeatherItem>> watchWeather() {
    return _col('weather_logs').orderBy('searchedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(WeatherItem.fromDoc).where((item) => item.isLive).toList(),
        );
  }

  Stream<List<ExchangeItem>> watchExchange() {
    return _col('exchange_logs').orderBy('searchedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(ExchangeItem.fromDoc).where((item) => item.isLive).toList(),
        );
  }

  Stream<List<ChatTurn>> watchTurns() {
    return _col('turns').orderBy('createdAt').snapshots().map(
          (snap) => snap.docs.map(ChatTurn.fromDoc).toList(),
        );
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable(name).call(data);
    final payload = result.data;
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return {'ok': true};
  }

  Future<WeatherItem> getWeather({
    required String cityName,
    required String cityQuery,
  }) async {
    final data = await _call('getWeather', {
      'cityName': cityName,
      'cityQuery': cityQuery,
    });
    return WeatherItem.fromMap(data);
  }

  Future<ExchangeItem> getExchange({
    required String currencyCode,
    required String currencyLabel,
  }) async {
    final data = await _call('getExchange', {
      'currencyCode': currencyCode,
      'currencyLabel': currencyLabel,
    });
    return ExchangeItem.fromMap(data);
  }

  Future<List<NewsItem>> getNews(String country) async {
    final data = await _call('getNews', {'country': country});
    final raw = data['items'];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => NewsItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ChatTurn> submitPrompt({
    required String text,
    required String locale,
    bool isVoice = false,
    String? filePath,
    String? fileName,
  }) async {
    final data = await _call('submitPrompt', {
      'text': text,
      'locale': locale,
      'isVoice': isVoice,
      'filePath': filePath,
      'fileName': fileName,
    });
    return ChatTurn.fromMap(Map<String, dynamic>.from(data['turn'] as Map));
  }

  Future<ChatTurn> confirmExtracted({
    required String turnId,
    required String kind,
  }) async {
    final data = await _call('confirmExtracted', {'turnId': turnId, 'kind': kind});
    return ChatTurn.fromMap(Map<String, dynamic>.from(data['turn'] as Map));
  }

  Future<void> deleteByIds(String collection, List<String> ids) {
    return _call('deleteByIds', {'collection': collection, 'ids': ids});
  }

  Future<ChatTurn> appendTurn(ChatTurn turn) async {
    final data = await _call('appendTurn', {'turn': turn.toJson()});
    return ChatTurn.fromMap(Map<String, dynamic>.from(data['turn'] as Map));
  }

  Future<String> scriptNews({
    required String newsId,
    required String locale,
  }) async {
    final data = await _call('scriptNews', {'newsId': newsId, 'locale': locale});
    return '${data['scriptKo'] ?? data['scriptText'] ?? ''}';
  }

  Future<void> withdraw() => _call('withdraw', {});

  Future<String> upload({
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final current = uid;
    if (current == null) {
      throw StateError('unauthenticated');
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final ref = _storage.ref('uploads/$current/${stamp}_$fileName');
    await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: contentType));
    return ref.fullPath;
  }
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;

  static ScheduleItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ScheduleItem(
      id: doc.id,
      title: '${data['title'] ?? ''}',
      startAt: readTime(data['startAt']),
      endAt: readTime(data['endAt']),
      allDay: data['allDay'] == true,
    );
  }
}

class BalanceItem {
  const BalanceItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.occurredAt,
    required this.runningBalance,
  });

  final String id;
  final String description;
  final int amount;
  final bool isIncome;
  final DateTime occurredAt;
  final int runningBalance;

  static BalanceItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BalanceItem(
      id: doc.id,
      description: '${data['description'] ?? ''}',
      amount: (data['amount'] as num?)?.round() ?? 0,
      isIncome: data['isIncome'] == true,
      occurredAt: readTime(data['occurredAt']),
      runningBalance: (data['runningBalance'] as num?)?.round() ?? 0,
    );
  }
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.country,
    required this.title,
    required this.summary,
    required this.source,
    required this.link,
    required this.publishedAt,
    this.scriptKo,
  });

  final String id;
  final String country;
  final String title;
  final String summary;
  final String source;
  final String link;
  final DateTime publishedAt;
  final String? scriptKo;

  static NewsItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return NewsItem.fromMap({...doc.data() ?? {}, 'id': doc.id});
  }

  static NewsItem fromMap(Map<String, dynamic> data) {
    return NewsItem(
      id: '${data['id'] ?? ''}',
      country: '${data['country'] ?? ''}',
      title: '${data['title'] ?? ''}',
      summary: '${data['summary'] ?? ''}',
      source: '${data['source'] ?? ''}',
      link: '${data['link'] ?? ''}',
      publishedAt: readTime(data['publishedAt']),
      scriptKo: (data['scriptKo'] ?? data['scriptText']) as String?,
    );
  }
}

class WeatherItem {
  const WeatherItem({
    required this.id,
    required this.cityName,
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.searchedAt,
    required this.expireAt,
  });

  final String id;
  final String cityName;
  final double temperature;
  final String condition;
  final int humidity;
  final DateTime searchedAt;
  final DateTime expireAt;

  bool get isLive => isUnexpired(expireAt, DateTime.now());

  static WeatherItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return WeatherItem.fromMap({...doc.data() ?? {}, 'id': doc.id});
  }

  static WeatherItem fromMap(Map<String, dynamic> data) {
    return WeatherItem(
      id: '${data['id'] ?? ''}',
      cityName: '${data['cityName'] ?? ''}',
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0,
      condition: '${data['condition'] ?? ''}',
      humidity: (data['humidity'] as num?)?.round() ?? 0,
      searchedAt: readTime(data['searchedAt']),
      expireAt: readTime(data['expireAt']),
    );
  }
}

class ExchangeItem {
  const ExchangeItem({
    required this.id,
    required this.currencyLabel,
    required this.currencyCode,
    required this.rateToKrw,
    required this.ratePerHundred,
    required this.searchedAt,
    required this.expireAt,
  });

  final String id;
  final String currencyLabel;
  final String currencyCode;
  final double rateToKrw;
  final double? ratePerHundred;
  final DateTime searchedAt;
  final DateTime expireAt;

  bool get isLive => isUnexpired(expireAt, DateTime.now());

  static ExchangeItem fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ExchangeItem.fromMap({...doc.data() ?? {}, 'id': doc.id});
  }

  static ExchangeItem fromMap(Map<String, dynamic> data) {
    return ExchangeItem(
      id: '${data['id'] ?? ''}',
      currencyLabel: '${data['currencyLabel'] ?? ''}',
      currencyCode: '${data['currencyCode'] ?? ''}',
      rateToKrw: (data['rateToKrw'] as num?)?.toDouble() ?? 0,
      ratePerHundred: (data['ratePerHundred'] as num?)?.toDouble(),
      searchedAt: readTime(data['searchedAt']),
      expireAt: readTime(data['expireAt']),
    );
  }
}

class ChatTurn {
  const ChatTurn({
    required this.id,
    required this.userText,
    required this.aiText,
    this.isVoice = false,
    this.fileName,
    this.table,
    this.chart,
    this.savedMenu,
    this.awaitingConfirm = false,
    this.extractedSchedules = const [],
    this.extractedBalances = const [],
    this.createdAt,
    this.pending = false,
    this.failed = false,
    this.localOnly = false,
  });

  final String id;
  final String userText;
  final String aiText;
  final bool isVoice;
  final String? fileName;
  final TableModel? table;
  final ChartModel? chart;
  final String? savedMenu;
  final bool awaitingConfirm;
  final List<ScheduleDraft> extractedSchedules;
  final List<BalanceDraft> extractedBalances;
  final DateTime? createdAt;
  final bool pending;
  final bool failed;
  final bool localOnly;

  ChatTurn copyWith({
    String? id,
    String? aiText,
    bool? pending,
    bool? failed,
    bool? localOnly,
    String? savedMenu,
    bool? awaitingConfirm,
    TableModel? table,
    ChartModel? chart,
  }) {
    return ChatTurn(
      id: id ?? this.id,
      userText: userText,
      aiText: aiText ?? this.aiText,
      isVoice: isVoice,
      fileName: fileName,
      table: table ?? this.table,
      chart: chart ?? this.chart,
      savedMenu: savedMenu ?? this.savedMenu,
      awaitingConfirm: awaitingConfirm ?? this.awaitingConfirm,
      extractedSchedules: extractedSchedules,
      extractedBalances: extractedBalances,
      createdAt: createdAt,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      localOnly: localOnly ?? this.localOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'userText': userText,
        'aiText': aiText,
        'isVoice': isVoice,
        'fileName': fileName,
        'table': table?.toJson(),
        'chart': chart?.toJson(),
        'savedMenu': savedMenu,
      };

  static ChatTurn fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatTurn.fromMap({...doc.data() ?? {}, 'id': doc.id});
  }

  static ChatTurn fromMap(Map<String, dynamic> data) {
    return ChatTurn(
      id: '${data['id'] ?? ''}',
      userText: '${data['userText'] ?? ''}',
      aiText: '${data['aiText'] ?? ''}',
      isVoice: data['isVoice'] == true,
      fileName: data['fileName'] as String?,
      table: TableModel.fromJson(data['table']),
      chart: ChartModel.fromJson(data['chart']),
      savedMenu: data['savedMenu'] as String?,
      awaitingConfirm: data['awaitingConfirm'] == true,
      extractedSchedules: data['extractedSchedules'] is List
          ? (data['extractedSchedules'] as List)
              .map(ScheduleDraft.fromJson)
              .whereType<ScheduleDraft>()
              .toList()
          : const [],
      extractedBalances: data['extractedBalances'] is List
          ? (data['extractedBalances'] as List)
              .map(BalanceDraft.fromJson)
              .whereType<BalanceDraft>()
              .toList()
          : const [],
      createdAt: data['createdAt'] == null ? null : readTime(data['createdAt']),
    );
  }
}

DateTime readTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is Map && value['_seconds'] is num) {
    return DateTime.fromMillisecondsSinceEpoch((value['_seconds'] as num).toInt() * 1000);
  }
  return DateTime.now();
}
