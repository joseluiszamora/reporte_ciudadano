/// Identificador local de demostración, sin dominio web ni datos de sesión.
abstract final class DemoReportLink {
  static final _id = RegExp(r'^[a-zA-Z0-9_-]+$');

  static String encode(String reportId) {
    if (!_id.hasMatch(reportId)) {
      throw const FormatException('Identificador de reporte no válido.');
    }
    return Uri(
      scheme: 'reporte-ciudadano-demo',
      host: 'local',
      pathSegments: ['reportes', reportId],
    ).toString();
  }

  static String decode(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'reporte-ciudadano-demo' ||
        uri.host != 'local' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'reportes' ||
        !_id.hasMatch(uri.pathSegments.last)) {
      throw const FormatException(
        'Pega un enlace de demostración generado por este prototipo.',
      );
    }
    return uri.pathSegments.last;
  }
}
