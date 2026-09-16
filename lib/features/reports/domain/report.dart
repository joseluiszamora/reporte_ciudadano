import '../../../core/geo_point.dart';

enum ReviewStatus { pending, correctionRequested, approved, rejected }

enum PublicDisposition { visible, hidden, duplicate }

enum TrackingStatus {
  reported('Reportado'),
  confirmed('Confirmado por la comunidad'),
  solutionReported('Solución reportada'),
  verified('Solución verificada');

  const TrackingStatus(this.label);
  final String label;
}

/// Una revisión nunca sustituye a la versión pública hasta ser aprobada.
class ReportRevision {
  const ReportRevision({
    required this.title,
    required this.description,
    required this.status,
  });
  final String title;
  final String description;
  final ReviewStatus status;
}

/// Solo contiene información apta para lectura pública, no notas internas.
class PublicEvent {
  const PublicEvent(this.date, this.text);
  final DateTime date;
  final String text;
}

class Report {
  const Report({
    required this.id,
    required this.category,
    required this.zone,
    required this.reference,
    required this.authorAlias,
    required this.observedAt,
    required this.submittedAt,
    required this.publishedAt,
    required this.tracking,
    this.publicRevision,
    this.pendingRevision,
    this.disposition = PublicDisposition.visible,
    this.confirmations = 0,
    this.management = const [],
    this.updates = const [],
    this.comments = const [],
    this.history = const [],
    this.point,
  });

  final String id;
  final String category;
  final String zone;
  final String reference;
  final String authorAlias;
  final DateTime observedAt;
  final DateTime submittedAt;
  final DateTime? publishedAt;
  final TrackingStatus tracking;
  final ReportRevision? publicRevision;
  final ReportRevision? pendingRevision;
  final PublicDisposition disposition;
  final int confirmations;
  final List<PublicEvent> management;
  final List<PublicEvent> updates;
  final List<PublicEvent> comments;
  final List<PublicEvent> history;
  final GeoPoint? point;

  bool get isPublic =>
      disposition == PublicDisposition.visible &&
      publicRevision?.status == ReviewStatus.approved;

  /// Proyección pública: nunca entregar la edición pendiente al visitante.
  Report publicView() => Report(
    id: id,
    category: category,
    zone: zone,
    reference: reference,
    authorAlias: authorAlias,
    observedAt: observedAt,
    submittedAt: submittedAt,
    publishedAt: publishedAt,
    tracking: tracking,
    publicRevision: publicRevision,
    disposition: disposition,
    confirmations: confirmations,
    management: management,
    updates: updates,
    comments: comments,
    history: history,
    point: point,
  );
}

/// Hora civil de Bolivia (UTC−4); independiente de la zona del dispositivo.
String boliviaDate(DateTime value) {
  final local = value.toUtc().subtract(const Duration(hours: 4));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · '
      '${two(local.hour)}:${two(local.minute)}';
}
