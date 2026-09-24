# Novena entrega — punto ajustable, minimapa y verificación del prototipo

Versión **0.9.0+9**. Continúa la [octava entrega](08_entrega_mapa_filtros.md) y contrasta la implementación con la [especificación](01_especificacion_proyecto_v0.2.md) y el [diseño](02_prototipo_flutter_v0.2.md).

## Cambios disponibles

- **Reportar 2/3:** plano de coordenadas de demostración. Tocar el plano o usar las flechas mueve el punto; los campos de latitud y longitud se actualizan y se guardan en el mismo borrador. La edición manual sigue disponible, incluso tras rechazar el GPS simulado. Un punto manual fuera del encuadre recentra el plano. Cambiar el punto invalida las coincidencias anteriores para consultarlas de nuevo.
- **Detalle y lectura pública:** minimapa esquemático de solo lectura para un reporte visible con coordenadas válidas. Usa el punto de la proyección pública vigente; un reporte oculto carece de minimapa público. Los reportes sin punto muestran un estado textual.
- El plano indica norte y cuadrícula orientativa. No muestra calles, límites, cartografía real ni prueba que un punto pertenezca a El Alto. El catálogo, zona y referencias siguen siendo ficticios.

## Recorridos del diseño

Los diez recorridos de la sección 8 están representados por las pruebas existentes y las nuevas. La tabla describe **cobertura automatizada**, no una ejecución manual completa de cada recorrido en un dispositivo.

| Recorrido | Cobertura automatizada principal |
| --- | --- |
| 1. Consulta lista/mapa → detalle → gestiones | `widget_test.dart`, `explore_map_test.dart`, `geo_views_test.dart`, `follow_up_flow_test.dart` |
| 2. Acceso → reporte → punto → coincidencias → envío | `submission_flow_test.dart`, `geo_views_test.dart` |
| 3. Corrección, reenvío y aprobación | `moderation_flow_test.dart`, `moderation_repository_test.dart` |
| 4. Edición pendiente conserva versión pública | `moderation_repository_test.dart`, `report_repository_test.dart` |
| 5. Confirmación única y seguimiento | `community_flow_test.dart`, `community_repository_test.dart` |
| 6. Gestión aprobada y novedad | `follow_up_flow_test.dart`, `follow_up_repository_test.dart` |
| 7. Solución propuesta, aprobada y verificada | `follow_up_flow_test.dart`, `follow_up_repository_test.dart` |
| 8. Contradicción y reapertura motivada | `follow_up_repository_test.dart` |
| 9. GPS rechazado, borrador y reintento | `submission_flow_test.dart`, `submission_repository_test.dart`, `geo_views_test.dart` |
| 10. Retiro de autoría y ocultamiento | `safety_flow_test.dart`, `safety_repository_test.dart`, `moderation_repository_test.dart` |

Las pruebas de interfaz de esta entrega incluyen texto al 200 % en 360 × 800, 390 × 844 y 412 × 915. Se mantiene la lista equivalente al esquema, objetivos táctiles de 48 × 48 para las flechas, etiquetas accesibles y ausencia de animación automática. No se ha realizado una auditoría con lector de pantalla.

## Qué funciona y qué se simula

El ajuste gráfico, la persistencia local del borrador, la consulta pública y las decisiones locales funcionan dentro de la aplicación. El plano y el minimapa son representaciones ficticias. GPS, fotografías, acceso, moderación, notificaciones y envío a revisión continúan con los adaptadores y escenarios simulados descritos en el [README](../README.md). No hay proveedor de mapas, geocodificación, polígonos oficiales, backend ni publicación web.

## Ejecutar y verificar

Desde la raíz, con Flutter y el SDK Android configurados:

```powershell
flutter pub get
flutter devices
flutter run -d <id-android>
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

El APK de desarrollo se genera en `build/app/outputs/flutter-apk/app-debug.apk`. Una compilación dirigida a ARM64 produce un APK para dispositivos ARM64; recompilar para x64 si se desea instalar en un emulador x64. No es una compilación de publicación.

## Resultados y límites

| Comprobación ejecutada | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test --reporter expanded` | **129 pruebas aprobadas**: 123 anteriores y 6 de esta entrega. |
| `flutter build apk --debug --target-platform android-arm64` | APK ARM64 de desarrollo generado en `build/app/outputs/flutter-apk/app-debug.apk`. |
| Teléfono M2007J20CG, Android 12 | APK instalado y diez recorridos de la sección 8 ejecutados manualmente con datos ficticios. Detalle en la sección siguiente. |
| Emulador Android x64 | Aplicación instalada y abierta. Se revisaron visualmente Explorar, detalle con minimapa, acceso simulado y Reportar 1/3 y 2/3; tocar el plano movió el marcador y actualizó la latitud visible. |
| `git diff --check` | Sin errores de espacios. |

La revisión en emulador fue puntual; no incluyó los diez recorridos completos ni la auditoría de accesibilidad con TalkBack. El APK ARM64 se instaló después en el teléfono descrito abajo. El emulador ejecutó una compilación x64 del mismo código.

## Recorrido manual en teléfono físico

El 23/09/2026 se instaló el APK ARM64 de desarrollo en un M2007J20CG con Android 12. Se comprobó directamente el recorrido 1: abrir Explorar en mapa y lista, entrar a un reporte ficticio y consultar ubicación, gestiones e historial. El detalle mostró el punto en el minimapa y el estado «Sin gestiones registradas» del dato de demostración.

El recorrido 2 quedó completo: acceso local simulado con alias ficticio, formulario 1/3 sin fotografías, punto manual, coincidencia pública, revisión 3/3 y envío pendiente. En el recorrido 9 se simuló GPS rechazado y se pudo marcar el punto manualmente; el escenario «Sin conexión» conservó el borrador y el reintento normal dejó un único envío y cero borradores en Perfil. La interrupción USB y el cambio a otra aplicación se resolvieron al retomar la prueba.

El recorrido 3 también quedó completo: moderación solicitó una corrección motivada, la autora añadió una referencia ficticia y reenvió el mismo reporte, y moderación aprobó la nueva versión con motivo. Explorar pasó de cinco a seis reportes abiertos y mostró el contenido aprobado.

| Recorrido manual restante | Resultado observado en el teléfono |
| --- | --- |
| 4. Edición publicada | Una edición cambió el título y quedó pendiente. Explorar conservó el título anterior y seis reportes. Tras aprobarla con motivo, apareció el título nuevo sin crear otro reporte. |
| 5. Confirmación y seguimiento | Una identidad ciudadana distinta confirmó dos veces; el detalle mantuvo **1 observador independiente**. «Seguir reporte» cambió a «Dejar de seguir». |
| 6. Gestión y aviso | La gestión pendiente no cambió el estado. Tras aprobar el resumen público, este apareció en la lista y el detalle; la cuenta seguidora recibió «Gestión aprobada para publicación» en la bandeja simulada. |
| 7. Solución | La propuesta ciudadana quedó en revisión. Aprobar el aporte cambió el estado a «Solución reportada»; una decisión posterior con motivo lo cambió a «Solución verificada». Ambas constan en el historial. |
| 8. Contradicción | El aporte contradictorio aprobado abrió «Revisión de seguimiento pendiente», conservando «Solución verificada». La reapertura explícita con motivo público devolvió el estado a «Reportado» y quedó en el historial. |
| 10. Privacidad y ocultamiento | La autora retiró la autoría; el detalle público mostró «Autor anónimo» y mantuvo el reporte visible. Después, moderación lo ocultó con motivo: Explorar volvió de seis a cinco reportes y la cuenta seguidora ya no lo vio en Siguiendo. |

Así, los diez recorridos de la sección 8 se ejecutaron manualmente en **un único teléfono físico** con identidades simuladas y datos ficticios. Esta prueba no verifica permisos reales entre dispositivos, concurrencia, backend, push, cartografía oficial ni operación de piloto. La cobertura automatizada de la tabla anterior es independiente de estos resultados.

Durante el recorrido se observó la etiqueta incorrecta «1 observadores independientes». Se corrigió a «1 observador independiente (simulado)» y se verificó en el APK ARM64 actualizado sobre el mismo teléfono con un reporte ficticio del catálogo. Después del cambio, `flutter analyze` no reportó incidencias, `flutter test --reporter expanded` aprobó **129 pruebas**, `flutter build apk --debug --target-platform android-arm64` terminó correctamente y `git diff --check` no encontró errores de espacios.

La instalación del APK actualizado mediante `flutter install --debug -d c85fb391` **desinstaló antes la versión anterior** y borró los envíos, aportes y decisiones locales creados para la prueba. Se comprobó «Mis envíos (0)» al volver a la cuenta ficticia. Las observaciones de la tabla corresponden a la ejecución previa a esa reinstalación; el teléfono conserva el APK corregido y una confirmación nueva sobre un reporte ficticio del catálogo. Para conservar datos locales en una futura actualización, evitar un procedimiento que desinstale la aplicación.

La validación con lector de pantalla, permisos reales, varias identidades en distintos dispositivos y restauración sigue pendiente. El prototipo local no acredita permisos de servidor ni operación de un piloto. Antes de ese piloto también deben acordarse el proveedor cartográfico, la fuente territorial, la retención y eliminación de datos, y la operación de moderación.
