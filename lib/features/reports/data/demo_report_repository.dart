import '../../../core/geo_point.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

class DemoReportRepository implements ReportRepository {
  DemoReportRepository({List<Report>? reports})
    : _reports = List.unmodifiable(reports ?? demoReports());
  final List<Report> _reports;

  @override
  Future<List<Report>> listPublicReports() async {
    final result =
        _reports.where((r) => r.isPublic).map((r) => r.publicView()).toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    return List.unmodifiable(result);
  }

  @override
  Future<Report?> getPublicReport(String id) async {
    for (final report in _reports) {
      if (report.id == id && report.isPublic) return report.publicView();
    }
    return null;
  }
}

List<Report> demoReports() {
  final date = DateTime.utc(2026, 9, 9, 16);
  Report make(
    String id,
    String title,
    String category,
    TrackingStatus state, {
    int people = 0,
    List<PublicEvent> management = const [],
    List<PublicEvent> updates = const [],
    bool anonymous = false,
    PublicDisposition disposition = PublicDisposition.visible,
    bool pending = false,
    bool editing = false,
  }) => Report(
    id: id,
    point: GeoPoint(-16.5000 - int.parse(id) * 0.0001, -68.1600),
    category: category,
    zone: 'Zona de demostración $id',
    reference:
        'Pasaje ficticio $id, junto al espacio comunitario de demostración.',
    authorAlias: anonymous ? 'Autor anónimo' : 'Vecina de demostración',
    observedAt: date.subtract(Duration(hours: int.parse(id))),
    submittedAt: date,
    publishedAt: pending ? null : date.add(const Duration(hours: 1)),
    tracking: state,
    disposition: disposition,
    confirmations: people,
    publicRevision: pending
        ? null
        : ReportRevision(
            title: title,
            description:
                'Ejemplo ficticio: $title. El problema dificulta el uso cotidiano '
                'del espacio público. La referencia y los hechos son de demostración.',
            status: ReviewStatus.approved,
          ),
    pendingRevision: pending || editing
        ? const ReportRevision(
            title: 'Contenido privado de demostración',
            description:
                'Esta revisión no debe aparecer en consultas públicas.',
            status: ReviewStatus.pending,
          )
        : null,
    management: management,
    updates: updates,
    history: pending
        ? const []
        : [
            PublicEvent(
              date.add(const Duration(hours: 1)),
              'Primera versión aprobada en la demostración.',
            ),
          ],
  );
  return [
    make(
      '1',
      'Bache en el pasaje comunitario',
      'Baches y calzada',
      TrackingStatus.reported,
    ),
    make(
      '2',
      'Acera deteriorada junto al paso peatonal',
      'Aceras y accesibilidad',
      TrackingStatus.confirmed,
      people: 3,
      management: [
        PublicEvent(
          date,
          'Reclamo ficticio presentado a Junta de demostración. '
          'Siguiente paso: consultar una respuesta. Esta gestión no implica una solución.',
        ),
      ],
    ),
    make(
      '3',
      'Luminaria con posible reparación',
      'Alumbrado',
      TrackingStatus.solutionReported,
      people: 2,
      updates: [
        PublicEvent(
          date,
          'Explicación de posible solución aprobada en el escenario. Falta verificar la solución.',
        ),
      ],
    ),
    make(
      '4',
      'Rampa reparada en espacio comunitario',
      'Aceras y accesibilidad',
      TrackingStatus.verified,
      updates: [
        PublicEvent(
          date,
          'Moderación verificó la reparación en el escenario ficticio. No es certificación municipal.',
        ),
      ],
    ),
    make(
      '5',
      'Basura pendiente de revisión',
      'Basura',
      TrackingStatus.reported,
      pending: true,
    ),
    make(
      '6',
      'Señalización deteriorada en el pasaje',
      'Señalización y semáforos',
      TrackingStatus.reported,
      editing: true,
    ),
    make(
      '7',
      'Reporte oculto',
      'Drenajes',
      TrackingStatus.reported,
      disposition: PublicDisposition.hidden,
    ),
    make(
      '8',
      'Reporte duplicado',
      'Drenajes',
      TrackingStatus.reported,
      disposition: PublicDisposition.duplicate,
    ),
    make(
      '9',
      'Banco deteriorado en espacio comunitario',
      'Parques y espacio público',
      TrackingStatus.reported,
      anonymous: true,
    ),
  ];
}
