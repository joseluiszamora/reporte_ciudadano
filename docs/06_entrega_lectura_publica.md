# Sexta entrega — Lectura pública compartida (0.6.0)

Fecha: 17 de septiembre de 2026. Fuentes: [especificación v0.2](01_especificacion_proyecto_v0.2.md), secciones 3, 4, 6 y 9–11; [diseño v0.2](02_prototipo_flutter_v0.2.md), pantalla P15. Ejecución Android: [README](../README.md#ejecutar).

## Alcance entregado

Representación navegable de la lectura pública de un reporte dentro del prototipo Flutter. Se consulta sin cuenta, es adaptable y comparte contenido y visibilidad con el detalle de la aplicación. No se ha publicado una web ni iniciado el piloto.

- **Lectura pública y enlace · demo**, desde el detalle: título, categoría, ubicación ficticia, alias público, fechas, seguimiento, evidencia aprobada, gestiones, actualizaciones, comentarios e historial públicos. Conserva las aclaraciones de solución reportada/verificada.
- **Copiar enlace de demostración**: consulta nuevamente la disponibilidad y solicita copiar solo el identificador local. Informa éxito o error y evita confirmar una copia obsoleta si cambia la lectura durante la consulta.
- **Abrir enlace de demostración**, icono de enlace de la cabecera: entrada manual de un enlace y acceso a un reporte de ejemplo. Rechaza enlaces externos, parámetros, credenciales, fragmentos y rutas no admitidas.
- **Abrir en la aplicación**: vuelve al detalle participativo conservando el reporte. No inicia sesión, sigue, confirma ni envía nada automáticamente.
- La lectura compartida no utiliza datos privados de la sesión ni marca sus notificaciones como leídas. Tampoco ofrece formularios de publicación ni acciones de moderación.

## Recorrido de demostración

1. Ejecutar `flutter run -d <id-del-dispositivo-android>` desde la raíz, después de `flutter pub get`. Consultar dispositivos con `flutter devices`.
2. Como visitante, abrir un reporte desde Explorar y pulsar **Lectura pública y enlace · demo**.
3. Leer sus secciones públicas y pulsar **Copiar enlace de demostración**. La copia usa la API de portapapeles de Flutter; no envía mensajes ni abre aplicaciones externas.
4. Volver a la pantalla principal. Abrir el icono **Abrir enlace de demostración**, pegar el texto y pulsar **Abrir lectura pública**. También se puede usar **Probar reporte de ejemplo**.
5. Pulsar **Abrir en la aplicación** si se desea volver al detalle con participación. El acceso posterior sigue siendo simulado y contextual.

Formato de ejemplo:

```text
reporte-ciudadano-demo://local/reportes/1
```

Este formato se interpreta únicamente en el campo del prototipo. No es una URL web publicada ni un enlace registrado en Android. No abre la app desde mensajes o navegadores. Los reportes creados localmente requieren los datos de este dispositivo; copiar un identificador no transfiere esos datos a otro teléfono. La dirección no contiene alias, correo, credenciales, contenido ni revisiones privadas.

### Estados y privacidad

| Escenario | Resultado |
| --- | --- |
| Aprobado y visible | Se muestra la versión pública vigente y sus elementos aprobados. |
| Edición pendiente | Se conserva la versión anterior, incluidos sus adjuntos. No aparece el nuevo texto ni sus medios. |
| Nuevo pendiente o identificador inexistente | Aviso genérico Reporte no disponible, sin confirmar datos del envío privado. |
| Oculto | Reporte oculto; se retiran contenido y acciones de enlace incluso si la vista estaba abierta. |
| Duplicado | Reporte duplicado; acceso al principal únicamente mientras este sea público. Se conserva el modo de lectura pública al navegar al principal. |
| Principal oculto | Desaparece el acceso al principal. No se muestran sus datos ni motivos internos. |
| Error de consulta | Mensaje y Reintentar. No se conserva una copia anterior visible como si estuviera actualizada. |
| Error al copiar | Mensaje de fallo y posibilidad de reintentar, sin afirmar que se copió. |
| Autor anónimo precargado | Se muestra Autor anónimo. Esto demuestra lectura de ese estado; no implementa aún retirar autoría desde Perfil. |

Para probar los estados del catálogo, sustituir el identificador final por `5` (pendiente, sin contenido público), `7` (oculto), `8` (duplicado sin principal disponible) o `9` (anónimo). Para probar duplicado con navegación al principal, crear y aprobar dos reportes locales y marcar uno como duplicado del otro desde moderación. Los ejemplos son ficticios.

## Implementación y límites

- `DemoReportLink` concentra codificación y validación del identificador. No introduce permisos, secretos ni servicios externos.
- `OpenDemoLinkPage` abre la lectura mediante el `ReportRepository` recibido.
- `ReportDetailPage(publicReading: true)` reutiliza contenido y consulta del detalle, con acciones exclusivamente de lectura/enlace. Evita duplicar la proyección de gestiones, aportes o estado de solución. El detalle y la representación pública respetan áreas seguras.
- `ModeratedReportRepository` sigue combinando catálogo, publicaciones locales, comunidad y seguimiento. Propaga los avisos generales de oculto/duplicado del catálogo sin exponer motivos internos.
- La vista escucha cambios públicos y vuelve a consultar. Durante carga y error no muestra la versión anterior de la lectura. Cambiar el repositorio o el identificador también renueva la consulta.
- El portapapeles se modifica únicamente por una pulsación explícita. No se lee automáticamente. Una copia ya realizada no puede revocarse; al contener solo el identificador, abrirla vuelve a comprobar el estado público actual.
- Se mantiene **JSON v4**, los repositorios sustituibles y la plataforma Android. No cambian dependencias ni configuración nativa; no hay web, indexación, exportación PDF ni publicación desde navegador.

## Verificación

| Comprobación ejecutada | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test --reporter compact` | **98 pruebas aprobadas**, incluidas las 87 anteriores y 11 nuevas. |
| `flutter build apk --debug --target-platform android-x64` | APK generado en `build/app/outputs/flutter-apk/app-debug.apk`. |
| Enlaces relativos y `git diff --check` | Correctos, sin enlaces rotos ni errores de espacios. |

La compilación mostró advertencias del entorno Java que no impidieron generar el APK. No se cambiaron dependencias para resolver los avisos informativos de versiones disponibles.

Las 11 pruebas nuevas cubren formato y rechazo de enlaces, copia y apertura sin cuenta, retorno al detalle sin acciones automáticas, conservación de revisión/medios aprobados, separación de gestión pública y datos internos, ocultamiento de una vista abierta, navegación al principal y su revocación, pendientes/inexistentes, lectura anónima, errores de consulta/portapapeles y lectura sin modificar avisos de la sesión.

Cuatro recorridos prueban entrada de enlace, error y lectura hasta el historial con texto al **200 %**, teclado y áreas seguras en **360 × 800, 390 × 844, 412 × 915 y 1440 × 900**. El aviso específico de ocultamiento sustituye la expectativa antigua de aviso genérico en la prueba inicial del catálogo; se mantiene la comprobación de no exposición del contenido.

El portapapeles se comprueba mediante su canal de plataforma simulado en pruebas. No se ha probado manualmente en un dispositivo, con lector de pantalla ni entre aplicaciones. Tampoco se compiló ARM ni se validaron controles de servidor.

## Próximo trabajo

La siguiente fase de la secuencia es **cerrar brechas y validar el prototipo completo**. Permanecen pendientes retiro de autoría, denuncia de contenido, mapa/lista y filtros completos, además de validación manual integral. Los diez recorridos del diseño siguen siendo la referencia: los recorridos con mapa y retiro de autoría aún no están completos. El funcionamiento automatizado de las entregas no acredita la seguridad ni operación de un piloto real.

Historial: [quinta entrega](05_entrega_gestiones_solucion.md) y [cuarta entrega con revisión de anteriores](04_entrega_comunidad.md).
