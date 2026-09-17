import '../../../core/geo_point.dart';
import '../../reports/domain/report.dart';
import 'review_record.dart';

const reportCategories = [
  'Baches y calzada',
  'Aceras y accesibilidad',
  'Alumbrado',
  'Basura',
  'Drenajes',
  'Señalización y semáforos',
  'Parques y espacio público',
];

/// Valores iniciales propuestos, centralizados para poder configurarlos.
class ReportRules {
  const ReportRules({
    this.titleMin = 10,
    this.titleMax = 100,
    this.descriptionMin = 20,
    this.descriptionMax = 1500,
    this.referenceMax = 200,
    this.maxPhotos = 5,
    this.duplicateRadius = 150,
  });
  final int titleMin,
      titleMax,
      descriptionMin,
      descriptionMax,
      referenceMax,
      maxPhotos;
  final double duplicateRadius;
  String? titleError(String value) =>
      value.trim().length < titleMin || value.trim().length > titleMax
      ? 'Escribe entre $titleMin y $titleMax caracteres.'
      : null;
  String? descriptionError(String value) =>
      value.trim().length < descriptionMin ||
          value.trim().length > descriptionMax
      ? 'Escribe entre $descriptionMin y $descriptionMax caracteres.'
      : null;
  String? validate(ReportDraft draft, DateTime now) {
    if (!reportCategories.contains(draft.category)) {
      return 'Selecciona una categoría.';
    }
    final title = titleError(draft.title);
    if (title != null) return 'Título: $title';
    final description = descriptionError(draft.description);
    if (description != null) return 'Descripción: $description';
    if (draft.observedAt.isAfter(now)) {
      return 'La observación no puede ser futura.';
    }
    if (draft.point == null || !draft.point!.isValid) {
      return 'Selecciona un punto válido.';
    }
    if (!draft.cityConfirmed) {
      return 'Confirma que el punto corresponde a El Alto.';
    }
    if (draft.reference.length > referenceMax) {
      return 'La referencia supera $referenceMax caracteres.';
    }
    if (draft.photos.length > maxPhotos) {
      return 'Adjunta como máximo $maxPhotos fotos.';
    }
    return null;
  }
}

class ReportDraft {
  ReportDraft({
    required this.id,
    required this.ownerId,
    required this.observedAt,
    this.reportId,
    this.baseRevisionId,
    this.category = '',
    this.title = '',
    this.description = '',
    this.latitude = '',
    this.longitude = '',
    this.zone = '',
    this.reference = '',
    this.cityConfirmed = false,
    this.step = 0,
    List<String> photos = const [],
  }) : photos = List.unmodifiable(photos);
  final String id,
      ownerId,
      category,
      title,
      description,
      latitude,
      longitude,
      zone,
      reference;
  final DateTime observedAt;
  final String? reportId, baseRevisionId;
  final bool cityConfirmed;
  final int step;
  final List<String> photos;
  GeoPoint? get point {
    final lat = double.tryParse(latitude.replaceAll(',', '.'));
    final lon = double.tryParse(longitude.replaceAll(',', '.'));
    return lat == null || lon == null ? null : GeoPoint(lat, lon);
  }

  ReportDraft copyWith({
    String? id,
    String? reportId,
    String? baseRevisionId,
    String? category,
    String? title,
    String? description,
    DateTime? observedAt,
    String? latitude,
    String? longitude,
    String? zone,
    String? reference,
    bool? cityConfirmed,
    int? step,
    List<String>? photos,
  }) => ReportDraft(
    id: id ?? this.id,
    reportId: reportId ?? this.reportId,
    baseRevisionId: baseRevisionId ?? this.baseRevisionId,
    ownerId: ownerId,
    category: category ?? this.category,
    title: title ?? this.title,
    description: description ?? this.description,
    observedAt: observedAt ?? this.observedAt,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    zone: zone ?? this.zone,
    reference: reference ?? this.reference,
    cityConfirmed: cityConfirmed ?? this.cityConfirmed,
    step: step ?? this.step,
    photos: photos ?? this.photos,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'reportId': reportId,
    'baseRevisionId': baseRevisionId,
    'ownerId': ownerId,
    'category': category,
    'title': title,
    'description': description,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'zone': zone,
    'reference': reference,
    'cityConfirmed': cityConfirmed,
    'step': step,
    'photos': photos,
  };
  factory ReportDraft.fromJson(Map<String, dynamic> json) => ReportDraft(
    id: json['id'] as String,
    reportId: json['reportId'] as String?,
    baseRevisionId: json['baseRevisionId'] as String?,
    ownerId: json['ownerId'] as String,
    category: json['category'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
    latitude: json['latitude'] as String,
    longitude: json['longitude'] as String,
    zone: json['zone'] as String,
    reference: json['reference'] as String,
    cityConfirmed: json['cityConfirmed'] as bool,
    step: json['step'] as int,
    photos: (json['photos'] as List).cast<String>(),
  );
}

class ReportSubmission {
  const ReportSubmission({
    required this.draft,
    required this.alias,
    required this.sentAt,
    this.status = ReviewStatus.pending,
    this.decision,
  });
  final ReportDraft draft;
  final String alias;
  final DateTime sentAt;
  final ReviewStatus status;
  final ModerationEvent? decision;
  String get id => draft.id;
  String get reportId => draft.reportId ?? id;
  ReportSubmission reviewed(ReviewStatus status, ModerationEvent decision) =>
      ReportSubmission(
        draft: draft,
        alias: alias,
        sentAt: sentAt,
        status: status,
        decision: decision,
      );
  Map<String, Object?> toJson() => {
    'draft': draft.toJson(),
    'alias': alias,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'status': status.name,
    'decision': decision?.toJson(),
  };
  factory ReportSubmission.fromJson(
    Map<String, dynamic> json,
  ) => ReportSubmission(
    draft: ReportDraft.fromJson(json['draft'] as Map<String, dynamic>),
    alias: json['alias'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String).toUtc(),
    status: ReviewStatus.values.byName(json['status'] as String? ?? 'pending'),
    decision: json['decision'] == null
        ? null
        : ModerationEvent.fromJson(json['decision'] as Map<String, dynamic>),
  );
}

String moderationMessage(DateTime now) {
  final hour = now.toUtc().subtract(const Duration(hours: 4)).hour;
  return hour < 8 || hour >= 20
      ? 'Tu envío quedó pendiente para revisión en horario de atención.'
      : 'Tu envío está pendiente de revisión. No hay un plazo de aprobación garantizado.';
}
