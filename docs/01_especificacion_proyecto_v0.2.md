# Reporte Ciudadano — Especificación del proyecto

Versión 0.2 · 9 de septiembre de 2026 · El Alto, Bolivia.

Documento relacionado: [02_prototipo_flutter_v0.2.md](02_prototipo_flutter_v0.2.md).

## 1. Estado y autoridad de esta especificación

Esta versión sustituye la propuesta 0.1 para el alcance inicial e incorpora las respuestas del promotor. El entregable de esta etapa es documentación; la siguiente entrega prevista es un prototipo navegable en Flutter con datos ficticios. Este documento no acredita código implementado, infraestructura contratada ni integraciones operativas. Sus instrucciones de construcción se aplicarán cuando se inicie esa etapa.

Se distinguen decisiones confirmadas de propuestas de implementación y asuntos pendientes. Las decisiones explícitas del promotor prevalecen sobre los documentos iniciales.

## 2. Propósito y operación confirmados

La prioridad es impulsar la solución de problemas urbanos mediante seguimiento ciudadano. Los reportes servirán como evidencia para presentar reclamos y realizar gestiones ante juntas vecinales y autoridades. Documentar los problemas e informar a la comunidad apoyan ese propósito.

Es una iniciativa individual. Un equipo interno de tres personas administrará y moderará por turnos de 08:00 a 20:00, en America/La_Paz. Posteriormente se buscarán moderadores dentro de la comunidad y se presentará la iniciativa a juntas vecinales y autoridades. No existe todavía una meta de participación ni un presupuesto asignado.

Se permite reportar en toda la ciudad de El Alto. La Paz queda para una expansión posterior. Inicialmente se atienden problemas persistentes; las alertas de bloqueos, marchas y otros incidentes temporales quedan fuera de esta entrega.

El servicio trata hechos urbanos. No incluye denuncias contra personas o instituciones. Una junta o institución sí puede figurar como destinataria de una gestión, sin atribuir culpabilidad ni presentar una cuenta institucional verificada.

## 3. Alcance por etapa

### Primera entrega: prototipo Flutter

- Aplicación navegable en español, orientada a Android, con repositorios de demostración sustituibles.
- Explorar mapa/lista, filtros, detalle, creación de reporte en tres pasos y borradores.
- Acceso simulado por correo y Google, alias público y consulta sin cuenta.
- Confirmaciones, comentarios, evidencias y seguimiento de reportes.
- Bandeja simulada de notificaciones y preferencias.
- Vista de moderación adaptable para probar aprobación, correcciones, rechazo y ocultamiento.
- Registro de gestiones y recorrido hasta solución verificada.
- Representación navegable de la lectura pública compartida, sin afirmar que existe un enlace publicado.
- Estados de error, GPS rechazado, desconexión, contenido pendiente y falta de fotografías.

Los datos, la autenticación, el envío, las notificaciones y las decisiones de moderación son simulados. Cámara y ubicación pueden demostrarse con adaptadores reales si el entorno lo permite; cada capacidad debe identificarse como real o simulada. Los permisos y cambios de rol de demostración no constituyen seguridad de producción.

### Piloto posterior con usuarios reales

Integrar autenticación, datos, imágenes, autorización del servidor, mapas, moderación, notificaciones y páginas públicas compartibles. Habilitar indexación de reportes aprobados y visibles. Definir distribución Android, operación, privacidad y restauración de datos antes de abrirlo.

### Fuera del alcance inicial

La Paz; alertas de movilidad y sus vencimientos; zonas seguidas y resúmenes; pestaña independiente de Novedades; publicación desde la web; iOS; envío automático de reclamos; expedientes PDF; cuentas institucionales verificadas; rankings; chat privado; video; IA de clasificación o moderación; sincronización offline completa; publicación automática en segundo plano; navegación vial. La generación de expedientes podrá evaluarse después de observar cómo el equipo presenta reclamos.

## 4. Roles y permisos

| Rol | Facultades |
| --- | --- |
| Visitante | Consultar y compartir únicamente contenido aprobado y visible. |
| Ciudadano | Enviar reportes, comentarios, evidencias y correcciones; confirmar observaciones; seguir; denunciar contenido; consultar sus envíos pendientes y motivos de revisión. |
| Moderador | Revisar contenido, pedir correcciones, aprobar o rechazar; ocultar; resolver denuncias; marcar duplicados; verificar soluciones y reabrir con motivo. |
| Administrador | Facultades de moderación y gestión protegida de roles, parámetros y catálogos. |

Propuesta: el equipo interno registra las gestiones ante juntas y autoridades. La incorporación futura de moderadores requerirá asignación explícita de un administrador; no será automática por volumen de participación.

## 5. Reportes y territorio

Categorías de partida: baches y calzada; aceras y accesibilidad; alumbrado; basura; drenajes; señalización y semáforos; parques y espacio público. Son un catálogo inicial revisable.

| Campo | Regla de partida |
| --- | --- |
| Categoría | Obligatoria; no mostrar selector de tipo mientras solo haya problemas persistentes. |
| Título | 10–100 caracteres. |
| Descripción | 20–1.500 caracteres, centrada en el hecho observado. |
| Ubicación | Punto exacto del problema ajustable manualmente; ciudad El Alto. |
| Zona y referencia | Opcionales; referencia de hasta 200 caracteres. |
| Momento observado | Ahora por defecto; se admite una observación anterior, no futura. |
| Fotos | 0–5; reportar sin foto es válido. |
| Autoría | Alias público; nunca correo ni identificador de acceso. |

Los límites numéricos se heredan como propuestas configurables, no como decisiones expresamente validadas. La precisión solicitada es la del punto seleccionado para el hecho, no una garantía de exactitud del GPS.

No hay fuente territorial disponible. No inventar límites, distritos ni catálogos oficiales. Sin polígonos validados, no afirmar validación automática de pertenencia a El Alto: el usuario declara la ciudad y moderación revisa discrepancias. El prototipo usará zonas y referencias ficticias claramente identificadas. La búsqueda real inicial puede basarse en un catálogo local validado y referencias de reportes; no presupone geocodificación completa de direcciones.

Preparar el modelo para distintas jerarquías territoriales al incorporar La Paz. Guardar fechas en UTC y mostrarlas en America/La_Paz.

## 6. Aprobación previa y visibilidad

Decisión confirmada: reportes, comentarios, fotografías, actualizaciones con contenido y ediciones requieren aprobación antes de aparecer públicamente. Las confirmaciones simples de observación no requieren revisión individual, pero sí autenticación, validación y límites en servidor.

Propuesta de estados de revisión por envío o revisión de contenido:

| Estado | Visibilidad y acción |
| --- | --- |
| Pendiente de aprobación | Solo autor y equipo autorizado. |
| Corrección solicitada | Solo autor y equipo; motivo y opción de corregir y reenviar. |
| Aprobado | Puede incorporarse a la versión pública si el reporte sigue visible. |
| Rechazado | No se publica; autor conoce el motivo y dispone de canal de revisión. |

Separar la revisión de contenido de la disposición pública del reporte: visible, oculto o duplicado. La aprobación de una revisión no debe levantar accidentalmente un ocultamiento. Un duplicado enlaza al principal solo si ese principal es públicamente accesible; no se fusionan aportes automáticamente.

Una edición pendiente conserva la versión pública previamente aprobada. Guardar una revisión separada del contenido, incluidos sus medios. La aprobación cambia la versión de manera atómica y registra quién decidió, cuándo y por qué. Un reporte nuevo pendiente no tiene versión pública.

Fuera de 08:00–20:00 se pueden enviar contenidos; quedan en cola. No prometer resolución dentro de un número de horas ni aprobación automática al comenzar el turno.

Las consultas públicas, búsquedas, medios, vistas compartidas y notificaciones deben respetar la misma visibilidad. Las notificaciones privadas al autor pueden informar sobre su revisión, sin distribuir contenido pendiente a seguidores.

## 7. Seguimiento y confirmaciones

Mantener el seguimiento independiente de la revisión editorial:

| Estado público | Condición |
| --- | --- |
| Reportado | Primera versión aprobada y visible. |
| Confirmado por la comunidad | Umbral de observadores independientes; propuesta inicial de dos cuentas distintas del autor. |
| Solución reportada | Evidencia y explicación de solución aprobadas para publicación; pendiente de verificar la solución. |
| Solución verificada | Moderación revisó la solución y registró el motivo; no equivale a certificación municipal. |

Aprobar el contenido de una propuesta de solución y verificar que el problema está solucionado son decisiones distintas. Las propuestas pendientes no cambian el estado público. Aportes contradictorios aprobados se conservan y generan revisión. Una reapertura requiere motivo e historial.

Una persona cuenta una vez por reporte; puede actualizar la fecha de observación sin sumar otra persona. El autor puede informar que continúa, pero no sumar al umbral independiente. Un comentario no cuenta como confirmación. Los problemas persistentes no vencen automáticamente.

Umbral, período de observaciones recientes y tratamiento exacto de recurrencias quedan por validar antes del piloto. Propuesta: mostrar total histórico y última observación por separado; crear un incidente vinculado cuando hay una nueva ocurrencia después de una solución real, y reabrir cuando la solución anterior fue incorrecta.

Proponer posibles duplicados por categoría y cercanía entre problemas abiertos; radio inicial sugerido de 150 metros. Permitir continuar como problema distinto y no revelar coincidencias pendientes de otros usuarios.

## 8. Registro de gestiones

Propuesta funcional para materializar el objetivo confirmado de presentar reclamos. El equipo registra acciones realizadas fuera de la app; no hay envío automático ni confirmación de recepción por una autoridad desde el sistema.

Campos: reporte, fecha de gestión, junta o entidad destinataria, acción realizada, referencia del reclamo opcional, evidencia opcional, respuesta recibida, siguiente paso y responsable interno. Mantener el responsable interno y documentos sin depurar fuera de la vista pública. Publicar una versión revisada de la gestión y sus adjuntos seguros.

Presentar un reclamo, recibir una respuesta o anunciar un trabajo no significa solucionar el problema. Estas acciones aparecen en la cronología sin cambiar por sí solas el estado de seguimiento.

## 9. Privacidad, retiro y notificaciones

Retirar autoría conserva el reporte y sus aportes con la etiqueta «Autor anónimo». No equivale a ocultarlo ni a borrar todos los datos personales. Moderación puede ocultar contenido. Antes del piloto se definirá qué vínculo privado de autoría se conserva, quién accede y por cuánto tiempo, además del tratamiento de la eliminación de cuentas y de datos personales dentro del texto o fotos.

Solicitar GPS y cámara en contexto, permitir punto manual, no rastrear ubicación de fondo. Eliminar EXIF; validar y comprimir imágenes sin destruir su utilidad como evidencia. Límite inicial sugerido de entrada: 10 MB por imagen. No prometer difuminado automático.

Los medios pendientes son privados. Los medios aprobados deben respetar revocación y control de visibilidad. Ocultar invalida las superficies y cachés controladas por la plataforma; no garantiza borrar inmediatamente copias externas ni resultados ya almacenados por buscadores. La política de publicación deberá explicar ese límite.

Seguir un reporte activa novedades aprobadas de estado, evidencias y gestiones. Comentarios configurables y agrupados; confirmaciones individuales sin push por defecto. La bandeja interna funciona aunque se rechace el permiso push. Nunca enviar una notificación pública por el mero envío a revisión.

## 10. Arquitectura y modelo conceptual

Flutter está confirmado. BLoC/Cubit, GoRouter y la estructura por funcionalidades siguen como propuestas de implementación. Separar presentación, dominio y datos cuando exista lógica que lo justifique; evitar capas vacías.

Supabase con PostgreSQL/PostGIS, Auth y Storage es la recomendación provisional para el piloto. FCM es la propuesta para push. Proveedor de mapas pendiente de cobertura local, licencia, integración y costo. Tecnología de web pública y panel pendiente; React/Next.js del documento original no es una obligación. El prototipo permite ensayar moderación en Flutter adaptable sin fijar por ello la tecnología web final.

Entidades conceptuales: perfiles y roles protegidos; ciudades y unidades territoriales; categorías; reportes; revisiones de contenido; medios; comentarios; actualizaciones; confirmaciones únicas por usuario/reporte; seguimientos de reportes; gestiones; historial de seguimiento; denuncias de contenido; acciones de moderación; notificaciones y tokens privados. No crear zonas seguidas ni motor de alertas en esta etapa.

Un reporte referencia su revisión pública aprobada. Los envíos y revisiones tienen estado, autor, fechas, motivo y revisor. Las gestiones diferencian resumen público revisado de información operativa privada. Registrar por separado momento observado, enviado y publicado; no alterar la observación al aprobar.

Contratos propuestos: listar/consultar reportes públicos; consultar envíos propios; buscar coincidencias públicas; enviar reporte o revisión con clave de idempotencia; aprobar/solicitar corrección/rechazar una revisión; confirmar observación; seguir reporte; enviar aporte; registrar gestión; verificar solución; ocultar; retirar autoría. Toda operación sensible se autoriza en servidor, con transacción e historial; las notificaciones se emiten mediante eventos posteriores a la aprobación.

Para producción: RLS o controles equivalentes, índices geográficos, paginación, agrupación de marcadores, cuotas, validación de medios, limpieza de archivos huérfanos y deduplicación de solicitudes. No incluir secretos privilegiados en clientes. Separar datos ficticios de producción.

## 11. Criterios de aceptación

### Prototipo

- Recorrer consulta → envío → pendiente → aprobación → publicación → gestión → solución propuesta → solución verificada.
- Probar corrección solicitada y reenvío; una edición pendiente no reemplaza la versión pública.
- Diferenciar autor, visitante y moderador en escenarios de demostración.
- Ocultar un reporte lo retira de todas las vistas públicas simuladas; retirar autoría lo conserva anónimo.
- Confirmar dos veces no incrementa dos veces el conteo.
- Rechazar GPS, reportar sin fotos, conservar borrador y reintentar sin duplicar el envío simulado.
- Mostrar solo El Alto y problemas persistentes; no dejar controles de funciones pospuestas.
- Probar texto ampliado al 200 %, navegación accesible y pantallas pequeñas.

### Antes del piloto

Comprobar esos recorridos con backend real y pruebas de permisos de usuarios distintos, concurrencia, idempotencia, medios privados y ocultamiento. Verificar que una cuenta no puede asignarse roles, aprobarse contenido ni consultar pendientes ajenos. Validar horario operativo, atención de denuncias, restauración, privacidad, fuente territorial o procedimiento manual, cuotas y distribución. El prototipo por sí solo no verifica estos controles.

Medir utilidad y completitud de reportes, personas que regresan e interactúan, aportes útiles, tiempos de revisión, reportes con gestión registrada y soluciones con evidencia. Primero levantar una línea base; no se han acordado metas numéricas. No usar el volumen como ranking de calidad urbana.

## 12. Presupuesto orientativo y pendientes

Estimación presentada en la conversación para 100–500 usuarios activos/mes y hasta 1.000 reportes mensuales con fotos comprimidas: USD 50–90/mes de infraestructura; reserva sugerida de USD 100. No es presupuesto aprobado ni cotización. Excluye desarrollo, moderación, impuestos, dominio y registro en tiendas. Un prototipo local simulado puede operar sin servicios de pago.

Referencias consultadas el 9 de septiembre de 2026: [Supabase](https://supabase.com/pricing), base Pro de USD 25/mes para un proyecto básico; [MapTiler](https://www.maptiler.com/cloud/pricing/), referencia Flex de USD 25/mes; [Resend](https://resend.com/pricing), reserva de USD 0–20/mes; alojamiento web estimado USD 0–20/mes; [FCM](https://firebase.google.com/pricing), servicio sin cargo. Revalidar precios y cuotas antes de contratar. La reserva no cubre cualquier escala o consumo.

Pendientes para el piloto: mapas y búsqueda territorial, retención y eliminación, reglas numéricas de confirmación, recurrencias, publicación web e indexación, nombre/dominio, presupuesto aprobado y canales de revisión de decisiones. El registro de gestiones y los estados de corrección aquí detallados son propuestas de diseño listas para probar, no procesos institucionales ya existentes.

## 13. Cambios respecto de la versión 0.1

Se concentra el lanzamiento en El Alto; se posponen alertas y zonas seguidas; se añade acceso Google; se exige aprobación previa de contenido y revisiones; se incorpora horario operativo; el retiro conserva autoría anónima; se introduce registro de gestiones; se adelanta moderación al prototipo; se separa prototipo simulado del piloto real. Se eliminan las instrucciones que daban por hecho iniciar inmediatamente el MVP completo.
