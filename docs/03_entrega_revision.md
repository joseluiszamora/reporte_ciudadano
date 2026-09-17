# Tercera entrega — Revisión y versiones (0.3.0)

Implementación del bloque revisión/versiones de la secuencia del prototipo. Fuentes: [especificación v0.2](01_especificacion_proyecto_v0.2.md) y [diseño v0.2](02_prototipo_flutter_v0.2.md). No cambia las reglas acordadas ni habilita un piloto.

## Alcance y ejecución

Consultar [README](../README.md) para requisitos y comandos de ejecución Android. Sin dependencias nuevas ni servicios externos. Desde Perfil se puede cambiar a una identidad moderadora local claramente identificada; cerrar sesión vuelve al visitante y el acceso simulado permite recuperar cada cuenta ciudadana.

Se implementan P16 para revisión editorial y disposición pública, y P18 para estado, motivos e historial propio. La cola incluye únicamente envíos creados en este dispositivo; el catálogo inicial continúa como lectura de ejemplo. Verificar solución, reabrir, gestiones y aportes quedan para sus entregas respectivas. Las pantallas no ofrecen esas acciones todavía.

## Escenarios disponibles

1. **Corrección y aprobación:** enviar como ciudadano; entrar como moderador; pedir corrección con motivo; volver al mismo proveedor ciudadano; corregir y reenviar; aprobar como moderador. El visitante solo ve la versión aprobada.
2. **Edición pendiente:** editar un reporte aprobado, cambiar título, ubicación y adjuntos simulados, y enviar. El detalle público mantiene todos los campos anteriores. Moderación compara las dos versiones; aprobar cambia todos los campos públicos juntos.
3. **Rechazo:** rechazar con motivo y confirmación. Si es un reporte nuevo, nunca se publica; si es una edición, se conserva la versión aprobada anterior. El autor puede preparar una nueva revisión. No representa un canal institucional ni garantiza aprobación.
4. **Ocultar y restaurar:** ocultar con motivo; se retiran texto y adjuntos de detalle, lista y coincidencias. Aprobar otra versión conserva el ocultamiento. Restaurar disposición visible requiere una decisión explícita y no publica contenido sin aprobar.
5. **Duplicados:** crear y aprobar dos reportes. Marcar uno como duplicado y seleccionar el otro como principal. Se retira su contenido público y solo se ofrece el enlace al principal mientras este sea público. No se fusiona información. Los principales seleccionables son publicaciones locales, no el catálogo precargado.
6. **Reinicio:** salir y abrir la aplicación, acceder con el mismo proveedor para recuperar borradores e historial. El escenario moderador conserva decisiones y disposición. La sesión en sí no persiste.
7. **Sin motivo o cancelación:** el diálogo exige motivo antes de confirmar; cancelar no decide ni publica. Una escritura fallida muestra error y admite reintento.

## Datos y privacidad de la simulación

- La instantánea local guarda revisiones inmutables, borradores, estado editorial y punteros de publicación. La escritura serializada concluye antes de notificar cambios. Los datos v1 de la segunda entrega se leen y migran a v2 en la siguiente escritura; se mantiene la clave Android original.
- Cada revisión nueva tiene su propia clave idempotente y referencia la revisión de partida. No se permite crear otra edición mientras la vigente esté pendiente; un borrador obsoleto no reemplaza una versión posterior.
- El repositorio exige una identidad ciudadana propietaria para editar y una identidad moderadora distinta para decidir. Es una representación local de roles; cualquier usuario de este prototipo puede activar el escenario moderador. No acredita protección de producción.
- La proyección pública contiene solo la revisión aprobada y visible. No incluye motivos privados, identidad de acceso, auditoría interna ni adjuntos pendientes. Los avisos de oculto/duplicado solo se ofrecen para reportes que ya tuvieron una aprobación; los pendientes nuevos siguen siendo no disponibles públicamente.
- Las fotos son fichas simuladas. No se reciben imágenes reales, no hay EXIF que procesar ni almacenamiento remoto de medios. El campo de motivo admite únicamente ejemplos ficticios durante esta prueba.
- Aprobar no cambia el estado de seguimiento ni equivale a verificar una solución. Observación, envío y primera publicación conservan fechas distintas; UTC en persistencia, hora de Bolivia en pantalla.

## Verificación

Comprobaciones ejecutadas el 16 de septiembre de 2026:

| Comando | Resultado |
| --- | --- |
| `flutter analyze` | Sin incidencias. |
| `flutter test` | 49 pruebas aprobadas. |
| `flutter build apk --debug --target-platform android-x64` | Compilación correcta; APK en `build/app/outputs/flutter-apk/app-debug.apk`. Solo Android x64, no teléfonos ARM. |
| `git diff --check` y revisión de enlaces locales | Sin errores de espacios ni enlaces rotos en la documentación actualizada. |

El APK no se instaló ni ejecutó manualmente en un dispositivo durante esta entrega. La compilación emitió advertencias del entorno Java/Android SDK sin impedir el resultado.

La batería cubre aislamiento de revisiones, corrección y reenvío, aprobación, medios de la versión anterior, rechazo de ediciones, ocultamiento mantenido al aprobar, principal duplicado inaccesible, idempotencia, revisión obsoleta, fallo de disco sin publicación parcial, auditoría, migración v1 y recuperación de v2.

Las pruebas de widgets comprueban el acceso a moderación desde Perfil, motivo obligatorio, corrección desde el estado propio, cancelación y ocultamiento, así como actualización de lista y detalle abiertos. Se comprueba texto al 200 % en 360 × 800, 390 × 844, 412 × 915 y 1440 × 900; también la comparación en dos columnas con texto normal y el diálogo con teclado y áreas seguras simulados en 360 × 800.

No se ha validado seguridad de servidor, concurrencia entre dispositivos, medios reales, notificaciones push, restauración de infraestructura ni operación con usuarios. La recuperación se prueba recreando el repositorio; queda por hacer una comprobación manual de cierre/apertura en un teléfono y una auditoría con lector de pantalla.

## Cobertura de los diez recorridos del diseño

| Recorrido | Estado al terminar esta entrega |
| --- | --- |
| 1. Consulta pública y detalle | Lista y detalle locales; mapa pendiente. |
| 2. Acceso, envío y pendiente | Implementado con acceso y envío simulados. |
| 3. Corrección, reenvío, aprobación y publicación | Implementado para envíos locales. |
| 4. Edición pendiente conserva versión pública | Implementado, incluidos adjuntos simulados. |
| 5. Confirmación única y seguir | Pendiente de la siguiente entrega. |
| 6. Gestión, resumen aprobado y aviso al seguidor | Ejemplos de lectura; operaciones y avisos pendientes. |
| 7. Solución propuesta, aprobada y verificada | Ejemplos de lectura; operaciones pendientes. |
| 8. Evidencia contradictoria y reapertura | Pendiente. |
| 9. GPS rechazado, borrador y reintento | Implementado con adaptadores simulados. |
| 10. Retiro de autoría y ocultamiento | Ocultamiento implementado en envíos locales; retiro de autoría pendiente. |

La siguiente entrega prevista es comunidad/seguimiento: confirmación única por persona, aportes sujetos a revisión, seguir reportes y notificaciones simuladas, conservando estas reglas de visibilidad.
