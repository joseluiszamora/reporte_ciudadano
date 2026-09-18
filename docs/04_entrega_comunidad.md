# Cuarta entrega — Comunidad y seguimiento (0.4.0)

Fecha de revisión: 17 de septiembre de 2026. Fuentes: [especificación v0.2](01_especificacion_proyecto_v0.2.md), [diseño v0.2](02_prototipo_flutter_v0.2.md), código y pruebas del repositorio.

Este documento conserva la revisión de 0.4.0. El estado posterior se documenta en la [quinta entrega](05_entrega_gestiones_solucion.md).

## En qué entrega estamos

El código corresponde a la **cuarta entrega**, registrada en el commit `ffaf7f7` y en `pubspec.yaml` como `0.4.0+4`. Se verifican y documentan aquí comunidad, aportes, seguimiento y notificaciones simuladas. La siguiente entrega prevista por la secuencia es gestiones y solución.

El número de entregas incrementales del repositorio no debe confundirse con las dos etapas de la especificación: seguimos en la etapa de **prototipo Flutter**, sin iniciar el piloto real.

## Revisión de las entregas anteriores

| Entrega | Alcance entregado | Resultado de la revisión |
| --- | --- | --- |
| 1 — Base visual y lectura pública (`cbdff6f`) | Tema, navegación, Explorar en lista, detalle, búsqueda por zona/referencia y filtro de verificados. Datos ficticios y repositorio público. | 12 pruebas de dominio/interfaz pasan en el código actual: consulta pública, exclusión de privados, versión anterior, fechas, navegación, filtros, errores y texto al 200 %. |
| 2 — Envío y borradores (`40817d9`) | Acceso simulado, formulario en tres pasos, coincidencias, persistencia, consulta propia, escenarios de fallo y reintentos. | 19 pruebas adicionales pasan: validación, GPS rechazado, formulario, guardado/descarte, aislamiento de cuentas, idempotencia, pérdida de respuesta y canal nativo de almacenamiento. |
| 3 — Moderación y versiones (`fe404be`) | Cola, comparación, aprobar/corregir/rechazar, edición, motivos, historial, disposición pública y duplicados de reportes locales. | 18 pruebas adicionales pasan: conservación de versión/adjuntos, ocultamiento, rechazo privado, duplicados, migración, atomicidad ante fallo y revisión adaptable. |

**Conclusión:** las tres entregas mantienen el alcance incremental documentado y sus **49 pruebas de regresión pasan** sobre 0.4.0. No se detectaron regresiones en los recorridos automatizados revisados. Esto no equivale a completar todas las pantallas ni todos los criterios del prototipo final.

### Hallazgos y límites

- Se corrigió documentación desactualizada: README y AGENTS describían 0.3.0 y marcaban comunidad como pendiente, aunque el código ya estaba en 0.4.0.
- El escenario anónimo del catálogo y su prueba validan la lectura de un ejemplo; **no implementan retirar autoría desde la interfaz**. Ese flujo sigue pendiente.
- Mapa, filtros por categoría/estado/fecha completos y lectura compartida aún no están implementados. La primera entrega solicitó explícitamente el modo lista; no deben confundirse sus comprobaciones con una validación completa de P02–P04/P15.
- La moderación de reportes precargados no está habilitada; las operaciones de revisión/versiones se demuestran sobre reportes locales. El catálogo permite confirmaciones, seguimiento y aportes desde esta entrega.
- La persistencia se comprueba con repositorios recreados y un canal Android simulado en pruebas. Falta validar manualmente cierre/reapertura y recorridos en un teléfono, lector de pantalla y APK ARM. No se acredita seguridad ni operación del piloto.

## Lo implementado en la cuarta entrega

- **Confirmar / actualizar observación:** una identidad cuenta una vez por reporte. El autor no suma al umbral independiente; no se confunden comentarios y confirmaciones. Fecha comunitaria separada de la observación original.
- **Umbral propuesto:** dos observadores independientes, configurable mediante `CommunityRules`; no es una política definitiva de recurrencia. Una confirmación no reabre ni rebaja una solución verificada.
- **Aportes:** comentario o evidencia, texto y hasta cinco fichas de adjuntos simulados. Borrador local, salida guardar/descartar/continuar, escenarios de desconexión/respuesta perdida, revisión, motivo, corrección y reenvío. Ediciones pendientes conservan la versión aprobada anterior.
- **Siguiendo:** solo reportes públicos seguidos por la cuenta actual y marca de novedades públicas sin leer. Abrir el detalle marca esos avisos como leídos. Dejar de seguir elimina avisos públicos de ese seguimiento.
- **Bandeja:** novedades públicas tras aprobación o paso al umbral de confirmación; decisiones privadas solo para su autor. Comentarios optativos y agrupados por usuario/reporte. No se generan avisos públicos al enviar contenido pendiente ni por cada confirmación individual.
- **Ocultamiento:** consulta pública, contenido de aportes, conteos, Siguiendo y avisos públicos respetan la disposición vigente. Aprobar un aporte de un reporte oculto no lo restaura ni genera un aviso público. Los motivos internos no aparecen en textos públicos.
- **Persistencia v3:** reportes, aportes, observaciones, seguimientos, preferencias y avisos en una instantánea; decisiones y avisos se confirman juntos. Lectura compatible con v1/v2. Se conserva la clave Android de almacenamiento anterior.

## Recorrido de demostración

1. Ejecutar con las [instrucciones del README](../README.md). Abrir un reporte desde Explorar.
2. Pulsar **Confirmar que sigue ocurriendo** como visitante. Entrar con un alias ficticio y un proveedor simulado. La app vuelve al detalle sin confirmar automáticamente; pulsar otra vez y confirmar el diálogo.
3. Repetir con **Ya confirmaste · actualizar observación**. El conteo no suma otra persona. Seguir el reporte y comprobar **Siguiendo**.
4. Para un reporte propio, aprobarlo primero mediante moderación. Confirmar como autor, luego desde Google y desde **Perfil → Tercera cuenta ciudadana · demo**. Solo las dos personas independientes alcanzan el umbral propuesto.
5. Desde el detalle, **Aportar comentario o evidencia**. Completar el texto ficticio, añadir adjuntos simulados si corresponde y enviar. Consultar **Perfil → Mis aportes**. El contenido sigue pendiente y privado.
6. Entrar en **Escenario de moderación · demo → Abrir moderación** y abrir el aporte. Solicitar corrección, aprobar o rechazar con motivo y confirmación. El autor recibe un aviso privado local. Una aprobación permite ver el aporte en Comentarios o Actualizaciones cuando el reporte está visible.
7. Abrir la campana. Activar avisos agrupados de comentarios si se desea; **Simular permiso push rechazado** no impide leer la bandeja. No se envía push real en ningún escenario.
8. Probar ocultamiento con un reporte local seguido: desaparece de lista, detalle, Siguiendo y avisos públicos; los avisos privados de revisión permanecen para su autor.

## Verificación de esta revisión

| Comprobación ejecutada | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| Regresión de las entregas 1–3 | 49 pruebas aprobadas. |
| Lógica comunitaria | 12 pruebas aprobadas. |
| Nuevos recorridos de interfaz comunitaria | 5 pruebas aprobadas. |
| `flutter test` completo | **66 pruebas aprobadas** en una ejecución conjunta. |
| `flutter build apk --debug --target-platform android-x64` | APK compilado correctamente en `build/app/outputs/flutter-apk/app-debug.apk`. No se instaló ni probó manualmente en dispositivo. |
| Enlaces locales y `git diff --check` | Sin enlaces rotos ni errores de espacios en los cambios revisados. |

Los cinco recorridos de interfaz comprueban acceso contextual, confirmación repetida, seguimiento, aporte con respuesta perdida, moderación, aviso privado y texto al 200 % en las tres medidas móviles. La compilación muestra advertencias del entorno Java/SDK Android que no impidieron generar el APK. Los paquetes sugieren versiones más nuevas incompatibles con las restricciones actuales; no se cambiaron dependencias durante esta revisión.

## Pendientes del prototipo completo

Gestiones y avisos de gestión; propuestas de solución, verificación y reapertura con motivo; tratamiento explícito de evidencia contradictoria dentro de ese recorrido; retiro de autoría; denuncia de contenido; mapa y filtros completos; representación de lectura compartida; validación manual integral. Los ejemplos de soluciones y gestiones del catálogo siguen siendo datos precargados.

Fuera de alcance continúan las funciones pospuestas de la especificación. El acceso, envío, medios, moderación y bandeja son simulados; no hay backend, permisos de producción, push ni integración institucional real.
