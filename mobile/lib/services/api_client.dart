import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// API алдаа — хэрэглэгчид харуулах монгол мессежтэй.
class ApiException implements Exception {
  final String message;
  final List<String> details;
  final int? statusCode;

  ApiException(this.message, {this.details = const [], this.statusCode});

  @override
  String toString() => details.isEmpty ? message : '$message\n• ${details.join('\n• ')}';
}

/// Backend-тэй харилцах цорын ганц класс (Лаб 5-ын Presentation → Business давхаргын холбоос).
class ApiClient extends ChangeNotifier {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _kBaseUrl = 'base_url';
  static const _kToken = 'token';

  String baseUrl = defaultBaseUrl();
  String? _token;
  AppUser? user;

  bool get isLoggedIn => _token != null && user != null;

  /// Android эмулятор 10.0.2.2 хаягаар компьютерын localhost руу хандана.
  static String defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString(_kBaseUrl) ?? defaultBaseUrl();
    _token = p.getString(_kToken);
    if (_token != null) {
      try {
        user = AppUser.fromJson(await _send('GET', '/api/auth/me') as Map<String, dynamic>);
      } catch (_) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    baseUrl = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBaseUrl, u);
    notifyListeners();
  }

  String mediaUrl(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  // ------------------------------------------------------------------ HTTP
  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final req = http.Request(method, uri)..headers.addAll(_headers());
    if (body != null) req.body = jsonEncode(body);
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      return _handle(res);
    } on TimeoutException {
      throw ApiException('Сервер хариу өгөхгүй байна. Интернэт болон серверийн хаягаа шалгана уу.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Сервертэй холбогдож чадсангүй ($baseUrl). '
          'Профайл → Серверийн хаяг хэсгээс хаягаа шалгана уу.');
    }
  }

  dynamic _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = text;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && _token != null) {
      logout();
    }
    throw _parseError(data, res.statusCode);
  }

  ApiException _parseError(dynamic data, int code) {
    final detail = data is Map ? data['detail'] : null;
    if (detail is String) return ApiException(detail, statusCode: code);
    if (detail is Map) {
      return ApiException(detail['message']?.toString() ?? 'Алдаа гарлаа',
          details: ((detail['errors'] as List?) ?? []).map((e) => e.toString()).toList(), statusCode: code);
    }
    if (detail is List) {
      // FastAPI/Pydantic-ийн баталгаажуулалтын алдаа
      final msgs = detail.map((e) {
        final field = (e is Map && e['loc'] is List && (e['loc'] as List).isNotEmpty)
            ? (e['loc'] as List).last.toString()
            : '';
        final m = e is Map ? e['msg'].toString() : e.toString();
        return field.isEmpty ? m : '$field: $m';
      }).toList();
      return ApiException('Оруулсан мэдээлэл буруу байна', details: msgs, statusCode: code);
    }
    return ApiException('Алдаа гарлаа (код $code)', statusCode: code);
  }

  // ------------------------------------------------------------------ Нэвтрэлт
  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token = data['access_token'] as String;
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, _token!);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', body: {'email': email, 'password': password});
    await _saveSession(data as Map<String, dynamic>);
  }

  Future<void> register(String name, String email, String password) async {
    final data =
        await _send('POST', '/api/auth/register', body: {'name': name, 'email': email, 'password': password});
    await _saveSession(data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? password}) async {
    final data = await _send('PUT', '/api/auth/me', body: {
      if (name != null && name.isNotEmpty) 'name': name,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    user = AppUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<bool> checkServer() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ Оношилгоо
  Future<Diagnosis> diagnose(Uint8List bytes, String filename, {String note = ''}) async {
    final uri = Uri.parse('$baseUrl/api/diagnoses');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(json: false))
      ..fields['note'] = note
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename.isEmpty ? 'leaf.jpg' : filename));
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      return Diagnosis.fromJson(_handle(res) as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException('Сервер хариу өгөхгүй байна. Дахин оролдоно уу.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Сервертэй холбогдож чадсангүй ($baseUrl).');
    }
  }

  Future<List<Diagnosis>> history() async {
    final data = await _send('GET', '/api/diagnoses') as List;
    return data.map((e) => Diagnosis.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Diagnosis> diagnosis(int id) async =>
      Diagnosis.fromJson(await _send('GET', '/api/diagnoses/$id') as Map<String, dynamic>);

  Future<void> deleteDiagnosis(int id) async => _send('DELETE', '/api/diagnoses/$id');

  // ------------------------------------------------------------------ Өвчний сан
  Future<List<Disease>> diseases({String q = '', String plant = ''}) async {
    final data = await _send('GET', '/api/diseases', query: {
      if (q.isNotEmpty) 'q': q,
      if (plant.isNotEmpty) 'plant': plant,
    }) as List;
    return data.map((e) => Disease.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> plants() async =>
      (await _send('GET', '/api/diseases/plants') as List).map((e) => e.toString()).toList();

  Future<Disease> disease(int id) async =>
      Disease.fromJson(await _send('GET', '/api/diseases/$id') as Map<String, dynamic>);

  // ------------------------------------------------------------------ Админ
  Future<AdminStats> adminStats() async =>
      AdminStats.fromJson(await _send('GET', '/api/admin/stats') as Map<String, dynamic>);

  Future<List<AppUser>> adminUsers() async {
    final data = await _send('GET', '/api/admin/users') as List;
    return data.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> adminUpdateUser(int id, {String? role, bool? isActive}) async {
    final data = await _send('PATCH', '/api/admin/users/$id', body: {
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
    });
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<void> adminDeleteUser(int id) async => _send('DELETE', '/api/admin/users/$id');

  Future<Disease> adminSaveDisease(Disease d, {int? id}) async {
    final data = id == null
        ? await _send('POST', '/api/admin/diseases', body: d.toJson())
        : await _send('PUT', '/api/admin/diseases/$id', body: d.toJson());
    return Disease.fromJson(data as Map<String, dynamic>);
  }

  Future<void> adminDeleteDisease(int id) async => _send('DELETE', '/api/admin/diseases/$id');

  Future<List<Diagnosis>> adminDiagnoses({String status = ''}) async {
    final data =
        await _send('GET', '/api/admin/diagnoses', query: {if (status.isNotEmpty) 'status': status}) as List;
    return data.map((e) => Diagnosis.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Diagnosis> adminReview(int diagnosisId, int diseaseId) async => Diagnosis.fromJson(
      await _send('PATCH', '/api/admin/diagnoses/$diagnosisId', body: {'disease_id': diseaseId})
          as Map<String, dynamic>);
}
