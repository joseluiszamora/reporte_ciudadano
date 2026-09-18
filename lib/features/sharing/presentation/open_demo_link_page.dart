import 'package:flutter/material.dart';

import '../../reports/domain/report_repository.dart';
import '../../reports/presentation/report_detail_page.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/demo_report_link.dart';

class OpenDemoLinkPage extends StatefulWidget {
  const OpenDemoLinkPage({required this.repository, super.key});
  final ReportRepository repository;
  @override
  State<OpenDemoLinkPage> createState() => _OpenDemoLinkPageState();
}

class _OpenDemoLinkPageState extends State<OpenDemoLinkPage> {
  final _link = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _open() {
    try {
      final id = DemoReportLink.decode(_link.text);
      setState(() => _error = null);
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReportDetailPage(
            repository: widget.repository,
            reportId: id,
            publicReading: true,
          ),
        ),
      );
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: flowAppBar(context, 'Abrir enlace · demo'),
    body: FlowBody(
      children: [
        const DemoNotice(),
        const Text(
          'Lectura pública sin cuenta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Pega un enlace copiado desde la lectura pública. Funciona únicamente aquí, con los datos de este dispositivo. No hay una página publicada, enlace web ni indexación.',
        ),
        TextField(
          key: const Key('demo-link-input'),
          controller: _link,
          minLines: 2,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Enlace de demostración',
          ),
          onSubmitted: (_) => _open(),
        ),
        if (_error != null) FlowError(_error!),
        FilledButton(
          onPressed: _open,
          child: const Text('Abrir lectura pública'),
        ),
        OutlinedButton(
          onPressed: () {
            _link.text = DemoReportLink.encode('1');
            _open();
          },
          child: const Text('Probar reporte de ejemplo'),
        ),
        const Text(
          'Un enlace no da acceso a borradores ni envíos pendientes. Si el reporte se oculta, su contenido deja de estar disponible también desde esta vista.',
        ),
      ],
    ),
  );
}
