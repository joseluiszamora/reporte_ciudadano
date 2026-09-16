import 'package:flutter/material.dart';

import '../../reports/presentation/report_widgets.dart';
import '../domain/session_repository.dart';
import 'flow_widgets.dart';

Future<bool> requestDemoAccess(
  BuildContext context,
  SessionRepository session,
) async {
  if (session.current != null) return true;
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => AccessPage(session: session)),
      ) ??
      false;
}

class AccessPage extends StatefulWidget {
  const AccessPage({required this.session, super.key});
  final SessionRepository session;
  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  final _alias = TextEditingController();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _email = false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _alias.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login(DemoProvider provider) async {
    if (!_form.currentState!.validate()) return;
    if (provider == DemoProvider.email && _code.text.trim() != '123456') {
      setState(() => _error = 'Usa el código de demostración 123456.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.signIn(provider, _alias.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No pudimos abrir la sesión simulada.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: flowAppBar(context, 'Acceso simulado'),
    body: Form(
      key: _form,
      child: FlowBody(
        children: [
          const DemoNotice(),
          Text(
            'Elige tu alias público',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Usa un alias ficticio. No introduzcas correo, contraseña ni credenciales reales. '
            'Correo y Google representan dos cuentas de demostración distintas en este dispositivo.',
          ),
          TextFormField(
            key: const Key('alias'),
            controller: _alias,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Alias de demostración',
            ),
            validator: (value) =>
                value == null ||
                    value.trim().length < 3 ||
                    value.trim().length > 30 ||
                    value.contains('@')
                ? 'Usa 3–30 caracteres, sin correo.'
                : null,
          ),
          if (_email) ...[
            const Text(
              'Correo ficticio: vecina@example.invalid\nCódigo de demostración: 123456\nNo enviamos ningún correo.',
            ),
            TextFormField(
              key: const Key('demo-code'),
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código de demostración',
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _login(DemoProvider.email),
              child: const Text('Entrar con código simulado'),
            ),
          ] else
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        setState(() => _email = true);
                      }
                    },
              child: const Text('Simular acceso por correo'),
            ),
          OutlinedButton(
            onPressed: _busy ? null : () => _login(DemoProvider.google),
            child: const Text('Simular acceso con Google'),
          ),
          const Text(
            'Al continuar volverás al punto anterior. No se enviará ningún reporte automáticamente.',
          ),
          if (_error != null) FlowError(_error!),
        ],
      ),
    ),
  );
}
