// API-аас ирэх өгөгдлийн загварууд (backend/app/schemas.py-тай таарна).

DateTime _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        isActive: j['is_active'] as bool? ?? true,
        createdAt: _date(j['created_at']),
      );
}

class Treatment {
  final String method;
  final bool isOrganic;
  final String instructions;

  Treatment({required this.method, required this.isOrganic, required this.instructions});

  factory Treatment.fromJson(Map<String, dynamic> j) => Treatment(
        method: j['method'] as String? ?? '',
        isOrganic: j['is_organic'] as bool? ?? true,
        instructions: j['instructions'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'method': method, 'is_organic': isOrganic, 'instructions': instructions};
}

class Disease {
  final int id;
  final String key;
  final String plant;
  final String nameMn;
  final String nameEn;
  final bool isHealthy;
  final String pathogen;
  final String symptoms;
  final String description;
  final String prevention;
  final List<Treatment> treatments;

  Disease({
    required this.id,
    required this.key,
    required this.plant,
    required this.nameMn,
    required this.nameEn,
    required this.isHealthy,
    this.pathogen = '',
    this.symptoms = '',
    this.description = '',
    this.prevention = '',
    this.treatments = const [],
  });

  factory Disease.fromJson(Map<String, dynamic> j) => Disease(
        id: j['id'] as int,
        key: j['key'] as String? ?? '',
        plant: j['plant'] as String? ?? '',
        nameMn: j['name_mn'] as String? ?? '',
        nameEn: j['name_en'] as String? ?? '',
        isHealthy: j['is_healthy'] as bool? ?? false,
        pathogen: j['pathogen'] as String? ?? '',
        symptoms: j['symptoms'] as String? ?? '',
        description: j['description'] as String? ?? '',
        prevention: j['prevention'] as String? ?? '',
        treatments: ((j['treatments'] as List?) ?? [])
            .map((e) => Treatment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'plant': plant,
        'name_mn': nameMn,
        'name_en': nameEn,
        'is_healthy': isHealthy,
        'pathogen': pathogen,
        'symptoms': symptoms,
        'description': description,
        'prevention': prevention,
        'treatments': treatments.map((t) => t.toJson()).toList(),
      };
}

class Prediction {
  final String key;
  final String nameMn;
  final String plant;
  final double confidence;

  Prediction({required this.key, required this.nameMn, required this.plant, required this.confidence});

  factory Prediction.fromJson(Map<String, dynamic> j) => Prediction(
        key: j['key'] as String? ?? '',
        nameMn: j['name_mn'] as String? ?? '',
        plant: j['plant'] as String? ?? '',
        confidence: _num(j['confidence']),
      );
}

class Diagnosis {
  final int id;
  final DateTime createdAt;
  final String status;
  final String statusLabel;
  final double confidence;
  final double affectedPct;
  final String severity;
  final String message;
  final String note;
  final String imageUrl;
  final String overlayUrl;
  final Disease? disease;
  final List<Prediction> topPredictions;
  final List<String> warnings;
  final String userName;

  Diagnosis({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    required this.confidence,
    required this.affectedPct,
    required this.severity,
    required this.message,
    required this.note,
    required this.imageUrl,
    required this.overlayUrl,
    required this.disease,
    required this.topPredictions,
    required this.warnings,
    required this.userName,
  });

  bool get needsReview => status == 'needs_review';

  String get title => disease?.nameMn ?? 'Тодорхойгүй';

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        id: j['id'] as int,
        createdAt: _date(j['created_at']),
        status: j['status'] as String? ?? '',
        statusLabel: j['status_label'] as String? ?? '',
        confidence: _num(j['confidence']),
        affectedPct: _num(j['affected_pct']),
        severity: j['severity'] as String? ?? '',
        message: j['message'] as String? ?? '',
        note: j['note'] as String? ?? '',
        imageUrl: j['image_url'] as String? ?? '',
        overlayUrl: j['overlay_url'] as String? ?? '',
        disease: j['disease'] == null ? null : Disease.fromJson(j['disease'] as Map<String, dynamic>),
        topPredictions: ((j['top_predictions'] as List?) ?? [])
            .map((e) => Prediction.fromJson(e as Map<String, dynamic>))
            .toList(),
        warnings: ((j['warnings'] as List?) ?? []).map((e) => e.toString()).toList(),
        userName: j['user_name'] as String? ?? '',
      );
}

class AdminStats {
  final int users;
  final int diagnoses;
  final int needsReview;
  final int diseases;
  final List<MapEntry<String, int>> topDiseases;
  final List<MapEntry<String, int>> last7Days;

  AdminStats({
    required this.users,
    required this.diagnoses,
    required this.needsReview,
    required this.diseases,
    required this.topDiseases,
    required this.last7Days,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        users: j['users'] as int? ?? 0,
        diagnoses: j['diagnoses'] as int? ?? 0,
        needsReview: j['needs_review'] as int? ?? 0,
        diseases: j['diseases'] as int? ?? 0,
        topDiseases: ((j['top_diseases'] as List?) ?? [])
            .map((e) => MapEntry(e['name'].toString(), (e['count'] as num).toInt()))
            .toList(),
        last7Days: ((j['last_7_days'] as List?) ?? [])
            .map((e) => MapEntry(e['date'].toString(), (e['count'] as num).toInt()))
            .toList(),
      );
}
