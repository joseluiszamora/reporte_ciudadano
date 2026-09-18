# Quinta entrega — Gestiones y solución (0.5.0)

Fecha: 17 de septiembre de 2026. Fuentes: [especificación v0.2](01_especificacion_proyecto_v0.2.md), especialmente secciones 6–11, y [diseño v0.2](02_prototipo_flutter_v0.2.md). Ejecución: [README](../README.md#ejecutar).

Este documento conserva la entrega 0.5.0. El estado posterior se documenta en la [sexta entrega](06_entrega_lectura_publica.md).

## Estado y alcance

Esta entrega continúa comunidad y seguimiento con **gestiones revisadas, propuestas de solución, verificación y reapertura**. Seguimos en la etapa de prototipo Flutter para Android; no se inicia el piloto real ni se integran instituciones.

| Capacidad | Comportamiento disponible |
| --- | --- |
| Registro de gestión | Moderación registra fecha no futura, destinatario ficticio, acción, referencia opcional, resumen, respuesta, siguiente paso y evidencia simulada. |
| Información interna | Responsable, notas y documentos sin depurar se mantienen separados de `ManagementSummary`. No se incluyen en consultas públicas ni avisos. |
| Borradores y revisiones | Autoguardado, salida guardar/descartar/continuar, recuperación, envío, aprobación, corrección, rechazo y edición. La última versión aprobada permanece pública durante una edición pendiente o rechazada. |
| Solución propuesta | La ciudadanía elige Proponer solución desde el formulario de aportes. El envío pendiente no modifica el seguimiento; aprobarlo permite Solución reportada. |
| Verificación | Otra acción de moderación, con evidencia de solución aprobada y motivo público explícito. Se registra fecha y revisor interno; no equivale a certificación municipal. |
| Evidencia contradictoria | El tipo explícito Evidencia contradictoria requiere aprobación. Después se conserva en las actualizaciones y genera una revisión; no cambia automáticamente el estado ni reabre. |
| Resolución de contradicciones | Moderación revisa las evidencias y puede conservar el estado con motivo o reabrir una solución reportada/verificada. Las contradicciones pendientes de revisar impiden verificar. |
| Reapertura | Conserva evidencia e historial y vuelve a Reportado o Confirmado por la comunidad según el conteo independiente histórico. No se fija una política definitiva de recurrencia. |
| Avisos | Una gestión aprobada y una decisión de seguimiento generan avisos locales para seguidores solo si el reporte está visible. Se mantienen los avisos privados de revisión de aportes. |

Una gestión, una respuesta recibida o un trabajo anunciado **no cambian por sí solos el seguimiento**. Los motivos editoriales son internos; los motivos de verificar, conservar estado o reabrir se solicitan expresamente como texto revisado para publicación.

## Recorridos para probar

### Registrar y revisar una gestión

1. Entrar en **Perfil → Escenario de moderación · demo → Abrir moderación → Gestiones y solución**.
2. Elegir un reporte aprobado y pulsar **Registrar gestión**. Se admiten los reportes del catálogo y los creados/aprobados en este dispositivo. La edición del contenido original del catálogo sigue fuera de la cola editorial.
3. Completar destinatario ficticio, acción y resumen. Añadir respuesta, referencia o evidencia simulada cuando corresponda. Completar por separado responsable, notas y documentos internos ficticios.
4. Volver atrás y probar guardar, descartar o continuar. Un borrador guardado se recupera desde el mismo reporte, también tras recrear el repositorio o reiniciar la app y volver al escenario moderador.
5. Enviar a revisión. Abrir **Revisar gestión e historial**, comprobar la versión pública conservada y la propuesta. Aprobar, pedir corrección o rechazar exige motivo interno y confirmación.
6. Leer **Gestiones** en el detalle público: solo aparece el resumen aprobado y su evidencia, sin datos internos. El seguimiento no cambia por esta aprobación.
7. Usar **Editar gestión** o **Corregir gestión** para enviar otra revisión. La anterior aprobada permanece visible hasta una nueva aprobación. La identidad del borrador evita duplicados al reintentar.

El escenario tiene una identidad de moderación que representa al equipo y puede registrar y revisar en acciones separadas. No implementa asignación de roles ni segregación de responsabilidades entre revisores reales.

### Proponer, verificar y reabrir una solución

1. Como ciudadano de demostración, abrir un reporte y **Aportar comentario o evidencia**. Elegir **Proponer solución**, describir el hecho ficticio y enviar; los adjuntos son opcionales y simulados.
2. Como moderador, revisar el aporte desde la cola habitual. Aprobar su contenido pasa el reporte a **Solución reportada**; todavía no está verificado.
3. Abrir **Gestiones y solución → reporte**. Revisar la evidencia aprobada y pulsar **Verificar solución**. Escribir el motivo público revisado y confirmar. El estado cambia a **Solución verificada**, con historial y aviso local para seguidores.
4. Como ciudadano, enviar un aporte de tipo **Evidencia contradictoria**. Mientras está pendiente no afecta el estado ni aparece públicamente.
5. Aprobar ese aporte como moderador. El detalle conserva el estado y muestra que el seguimiento necesita revisión. La pantalla del equipo identifica las evidencias por revisar.
6. **Conservar estado tras revisión** resuelve esa revisión con motivo; **Reabrir problema** requiere motivo e incorpora el cambio al historial. Las evidencias aprobadas se conservan en ambos casos.

Los ejemplos precargados de Solución reportada no acreditan una revisión local: para verificar se necesita una nueva propuesta aprobada en el dispositivo. Editar una propuesta previamente verificada genera revisión explícita al aprobarse y conserva el estado hasta decidir. El tipo de un aporte de solución/contradicción existente no puede cambiar para eludir ese recorrido.

### Recuperación y visibilidad

- **Sin conexión:** el formulario de gestión conserva el borrador y muestra el fallo; cambiar el escenario y enviar de nuevo es una acción explícita.
- **Respuesta perdida:** el envío ya existe localmente. Reintentar recupera la misma gestión; también se ve en el reporte al regresar.
- **Decisión obsoleta:** si llega otra evidencia aprobada o cambia el seguimiento mientras se decide, la versión capturada ya no coincide. La acción falla y exige revisar el estado actualizado.
- **Ocultamiento:** sobre un reporte local aprobado, ocultarlo desde la revisión editorial. Su detalle, lista, Siguiendo y avisos públicos dejan de exponerlo. Aprobar gestiones/evidencia o verificarlo internamente no lo restaura. Solo una restauración explícita de disposición vuelve a permitir su consulta.
- **Cambio de sesión:** las pantallas internas dejan de mostrar datos al salir del escenario moderador. La separación se comprueba localmente; no representa autorización de servidor.

## Modelo y persistencia

- `FollowUpRepository` es un contrato inyectable desde `PrototypeServices`; comparte el adaptador local con envíos y comunidad para mantener una escritura atómica.
- `ManagementSummary` contiene exclusivamente información destinada a revisión pública. `ManagementDraft` conserva aparte responsable, notas, documentos internos, identidad de reintento y referencias a revisiones anteriores. `ManagementEntry` añade envío, revisión y decisión.
- `ResolutionRecord` guarda estado, candidato de solución aprobado, identificadores de evidencia por revisar, versión e historial. El motivo de seguimiento es público; la identidad revisora solo se expone al equipo.
- La instantánea **JSON v4** agrega `WorkflowState` y sigue leyendo v1, v2 y v3. La primera escritura posterior actualiza el formato, conserva identificadores y no borra aportes ni borradores anteriores. Se mantiene la clave Android de almacenamiento.
- Decisiones, proyección pública y avisos se confirman juntos después de escribir. Ante un fallo no se modifica el estado observable parcialmente.
- `ModeratedReportRepository` aplica comunidad y seguimiento a una misma proyección de lista, detalle y coincidencias. Siguiendo usa las mismas reglas; los avisos comprueban visibilidad vigente.
- Fechas almacenadas en UTC y mostradas en hora de Bolivia. Fecha de gestión, envío y decisión permanecen separadas.

## Verificación

| Comprobación | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias tras corregir los avisos de estilo. |
| `flutter test test/follow_up_repository_test.dart` | 14 pruebas aprobadas. |
| `flutter test test/follow_up_flow_test.dart` | 7 pruebas aprobadas. |
| `flutter test` | **87 pruebas aprobadas**, incluidas las 66 de entregas anteriores. |
| `flutter build apk --debug --target-platform android-x64` | APK generado en `build/app/outputs/flutter-apk/app-debug.apk`. |
| Enlaces relativos y `git diff --check` | Correctos, sin enlaces rotos ni errores de espacios. |

Las pruebas de dominio cubren separación pública/interna, conservación de versiones/medios, rechazo/corrección, idempotencia, fecha futura, aprobación frente a verificación, contradicción, reapertura, decisiones obsoletas, conteo conservado, ocultamiento, fallos de almacenamiento, roles, reinicio y migración v3. Las pruebas previas conservan cobertura de migraciones anteriores.

La interfaz recorre registro/revisión/publicación y propuesta/aprobación/verificación/reapertura. También prueba gestión, borrador, teclado y diálogo de aprobación con texto al **200 %** en **360 × 800, 390 × 844, 412 × 915 y 1440 × 900**, además de retirar información interna al cerrar sesión.

No se instalaron ni recorrieron manualmente las pantallas en un teléfono. La persistencia tras reinicio se comprueba recreando repositorios y mediante las pruebas existentes del canal Android. Quedan pendientes lector de pantalla, validación manual de áreas seguras y dispositivos reales, APK ARM y operación con usuarios distintos. La compilación mostró advertencias del entorno Java que no impidieron generar el APK.

## Qué está simulado y qué sigue

Navegación, validaciones, guardado local y decisiones funcionan en el prototipo. Acceso, roles, envío, publicación, notificaciones, evidencias y documentos son de demostración. No hay backend, permisos de producción, medios reales, push, recepción oficial, integración institucional ni envío automático de reclamos.

La siguiente entrega de la secuencia es la **representación navegable de lectura pública compartida**, seguida del cierre de validación del prototipo. Continúan pendientes retiro de autoría, denuncia de contenido, mapa/lista y filtros completos y validación manual integral. No se añaden funciones pospuestas ni se considera terminado el prototipo completo.

Historial: [tercera entrega](03_entrega_revision.md) y [cuarta entrega y auditoría de anteriores](04_entrega_comunidad.md).
