# Séptima entrega — Autoría y denuncia de contenido (0.7.0)

Fecha: 20 de septiembre de 2026. Fuentes: [especificación v0.2](01_especificacion_proyecto_v0.2.md), roles, privacidad y criterios de aceptación; [diseño v0.2](02_prototipo_flutter_v0.2.md), P13, P14, P16 y recorrido 10. Ejecución: [README](../README.md#ejecutar).

## Alcance

Esta entrega cierra dos brechas del prototipo: retiro de autoría y denuncia privada de contenido. No completa todavía mapa/filtros ni valida un piloto real. Todo contenido y toda identidad deben seguir siendo de demostración.

### Retiro de autoría

- Disponible para el autor de un reporte local con revisión aprobada, desde su estado de envío en Perfil. También funciona si está oculto o tiene una edición pendiente.
- Exige confirmación con explicación. Se conserva el reporte como **Autor anónimo**, junto con seguimiento, medios, gestiones e historial. No se restaura un ocultamiento.
- Los metadatos de los aportes del mismo autor en ese reporte se anonimizan. Los aportes de otras personas conservan su propia autoría. Aprobar una edición posterior o un nuevo aporte del autor no vuelve a mostrar su alias anterior.
- Lista, detalle, coincidencias, Siguiendo y lectura compartida reciben la proyección anonimizada. Los avisos existentes no contienen alias y no se generan avisos públicos por el retiro.
- El retiro es idempotente y persiste. La interfaz no ofrece deshacerlo. Un fallo de almacenamiento no modifica parcialmente la proyección.

**Límite de privacidad:** se anonimizan los metadatos de autoría, sin sustituir arbitrariamente palabras dentro de descripciones, fotografías, notas o aportes ajenos. Esos datos pueden necesitar revisión de contenido. Se conserva el vínculo privado y el alias original en las revisiones internas del prototipo, accesibles según el rol local. No es eliminación de cuenta ni borrado de todos los datos personales; la política de retención del piloto sigue pendiente.

### Denuncia de contenido

- Desde el detalle participativo: privacidad, acoso, información falsa, spam u otro motivo. Detalles privados opcionales, obligatorios para Otro; máximo tomado de `CommunityRules.textMax` como valor configurable de demostración.
- El visitante vuelve al reporte después del acceso simulado sin enviar automáticamente. Debe pulsar de nuevo la acción y enviar expresamente.
- Recepción privada y estado en **Perfil → Mis denuncias de contenido**. No aparece la denuncia en comentarios, historial público ni avisos de seguidores. El autor del reporte no puede consultar denuncias de otras personas.
- Escenarios de desconexión y respuesta perdida. Reintentar el mismo formulario recupera la misma denuncia; la respuesta perdida puede dejar una recepción persistida. Los textos sin enviar no se guardan al reiniciar y salir con cambios requiere confirmar el descarte.
- No se contacta a instituciones ni se denuncia a personas. Se señala contenido dentro de un reporte para que lo revise el equipo; no se prometen plazos.
- **Moderación → Revisar denuncias de contenido** muestra pendientes primero, por antigüedad, y revisiones finalizadas. El equipo puede consultar el contenido público vigente, registrar un motivo interno y cerrar sin cambiar visibilidad.
- Para un reporte local aprobado, **Ocultar reporte y cerrar denuncia** requiere confirmación y guarda ambas decisiones juntas. Retira el reporte completo de las superficies públicas. El motivo y la identidad revisora permanecen internos; el denunciante consulta un estado general de revisión finalizada.

El catálogo inicial sigue siendo de lectura: se pueden recibir y cerrar revisiones de denuncias sobre sus ejemplos, pero el ocultamiento se demuestra con reportes locales. Los detalles permiten señalar una sección, comentario o adjunto; esta entrega no incorpora retirada granular de ese elemento. No hay notificaciones nuevas de denuncias: su estado se consulta desde Perfil.

## Recorridos de prueba

### Retirar sin ocultar

1. Ejecutar la aplicación con las instrucciones del README. Enviar un reporte ficticio desde una identidad ciudadana y aprobarlo en moderación.
2. Volver a la misma identidad ciudadana. Abrir **Perfil → Mis envíos → reporte → Retirar autoría**.
3. Cancelar para comprobar que se conserva el alias. Repetir y confirmar el retiro.
4. Consultar el reporte desde Explorar y su lectura pública: aparece Autor anónimo, con sus medios y seguimiento conservados.
5. Enviar una edición o aporte nuevo desde ese autor y aprobarlo. La proyección mantiene la anonimización.

### Denunciar y revisar

1. Abrir un reporte como visitante y pulsar **Denunciar contenido**. Simular acceso; comprobar que no hay recepción automática.
2. Pulsar otra vez, elegir motivo y escribir detalles ficticios. Probar **Sin conexión**: el formulario conserva lo escrito mientras siga abierto.
3. Elegir **Respuesta perdida**, enviar y reintentar. Debe existir una sola denuncia en Perfil, con estado pendiente.
4. Entrar al escenario moderador y abrir **Revisar denuncias de contenido**. Consultar la denuncia y el contenido público vigente.
5. Para un reporte local, escribir motivo interno, pulsar **Ocultar reporte y cerrar denuncia** y confirmar. Para un ejemplo del catálogo, ensayar **Cerrar sin cambiar visibilidad**.
6. Volver como denunciante: se ve Revisión finalizada sin los motivos internos. En el caso ocultado, comprobar que ya no hay contenido público en lista, detalle, Siguiendo ni lectura compartida.

## Datos y arquitectura

- `SafetyRepository` es inyectable desde `PrototypeServices`; su implementación local comparte la cola serializada y el almacenamiento con envíos, comunidad y seguimiento.
- `SafetyState` conserva retiros por `reportId`, fecha y actor interno, además de las denuncias y decisiones. Los identificadores de recepción son estables para reintentos.
- **JSON v5** conserva lectura de v1, v2, v3 y v4. La siguiente escritura actualiza el formato sin alterar identificadores de reportes, borradores o revisiones anteriores. No cambia la clave de preferencias Android.
- La consulta propia de denuncias devuelve un estado de decisión sin motivo ni identidad interna. La consulta completa exige el rol moderador de demostración.
- El retiro incrementa la versión pública y refresca la proyección. Recibir o cerrar una denuncia sin ocultar no publica contenido ni cambia seguimiento. El ocultamiento usa la disposición pública existente y conserva el historial editorial.
- Fechas almacenadas en UTC y mostradas en hora de Bolivia. No se agregan dependencias, permisos nativos, plataformas ni integraciones externas.

## Verificación

| Comprobación ejecutada | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test --reporter expanded` | **112 pruebas aprobadas**: 98 anteriores y 14 nuevas. |
| `flutter build apk --debug --target-platform android-x64` | APK generado en `build/app/outputs/flutter-apk/app-debug.apk`. |
| Enlaces relativos y `git diff --check` | Correctos, sin enlaces rotos ni errores de espacios. |

La compilación mostró advertencias del entorno Java y de versiones del SDK Android que no impidieron generar el APK. No se actualizaron dependencias. Las pruebas ampliadas del formulario usan desplazamiento mediante gesto para alcanzar Enviar con teclado, siguiendo el comportamiento de la pantalla.

Ocho pruebas de repositorio cubren retiro autorizado, anonimización de aportes propios/terceros, revisiones futuras, visibilidad conservada, idempotencia, fallo de disco, reinicio, denuncias privadas, revisión y ocultamiento atómicos, límites del catálogo y migración v4 → v5. Las pruebas anteriores conservan las migraciones de versiones previas; se actualiza su expectativa de escritura al formato actual.

Seis pruebas de interfaz cubren Perfil, cancelación y confirmación de retiro, lectura compartida anónima, acceso contextual sin envío automático, respuesta perdida, consulta propia y revisión. Cuatro recorridos prueban retiro, formulario de denuncia y revisión con ocultamiento al **200 %**, con teclado y áreas seguras, en **360 × 800, 390 × 844, 412 × 915 y 1440 × 900**.

No se realizó validación manual en teléfono, lector de pantalla ni compilación ARM. La persistencia se comprueba recreando repositorios; no se acredita seguridad de producción, retención o eliminación real de cuentas.

## Estado de los diez recorridos del diseño

| Recorridos | Estado al terminar esta entrega |
| --- | --- |
| 1 — Consulta, detalle y gestiones | Disponible en lista; mapa pendiente. |
| 2–4 — Envío, corrección y versiones | Disponibles; regresión automatizada de entregas anteriores. |
| 5 — Confirmación única y seguimiento | Disponible; conservado en regresión. |
| 6–8 — Gestiones, solución y contradicciones | Disponibles con datos y decisiones locales simuladas. |
| 9 — GPS rechazado y reintento | Disponible mediante adaptadores y escenarios simulados. |
| 10 — Retiro de autoría y ocultamiento | Implementado sobre reportes locales; anonimización y ocultamiento son acciones independientes. |

Continuación disponible en la [octava entrega](08_entrega_mapa_filtros.md), con mapa esquemático y filtros. Al cierre de esta séptima entrega, la siguiente debía abordar **mapa/lista y filtros completos**, conservando el listado equivalente y sin dar por elegido un proveedor de mapas. Luego corresponde completar la validación manual integral. La etapa de prototipo sigue abierta; el piloto requiere backend, permisos reales, pruebas entre usuarios, medios, restauración y operación.

Historial: [sexta entrega](06_entrega_lectura_publica.md), [quinta entrega](05_entrega_gestiones_solucion.md) y [auditoría de entregas anteriores](04_entrega_comunidad.md).
