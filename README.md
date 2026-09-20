# Reporte Ciudadano

Prototipo Flutter **0.8.0** para consultar, enviar, revisar y seguir problemas persistentes de El Alto. Interfaz en español, orientada a Android. Usa únicamente datos ficticios, identificados como **Datos de demostración**.

## Estado actual: octava entrega — mapa y filtros

- Explorar alterna lista y mapa esquemático con marcadores agrupados y tarjetas públicas. Desplazamiento y zoom mediante botones accesibles; búsqueda explícita en el área.
- Filtros combinables por categoría, seguimiento y fechas inclusivas de última observación en Bolivia. Conserva búsqueda, filtros y posiciones durante la navegación.
- Ubicación simulada contextual, ensayo de rechazo y orden por cercanía. Sin proveedor cartográfico, calles, límites oficiales ni permisos GPS reales.

Alcance y verificación: [Octava entrega](docs/08_entrega_mapa_filtros.md).

### Capacidades conservadas de la séptima entrega

- **Perfil → Mis envíos → reporte → Retirar autoría**: confirmación explícita para conservar el reporte como **Autor anónimo**. Los aportes de su autor en ese reporte también se anonimizan, incluso al aprobar revisiones posteriores. No cambia la visibilidad ni elimina la cuenta.
- **Detalle → Denunciar contenido**: motivo y detalles privados, acceso simulado contextual, recepción y reintento idempotente. No envía reclamos a autoridades ni oculta automáticamente el contenido.
- **Perfil → Mis denuncias de contenido**: recepción y estado propios. **Moderación → Revisar denuncias de contenido**: cola, revisión con motivo y cierre. En reportes locales aprobados se puede ocultar todo el reporte y cerrar la denuncia en una misma escritura.
- El catálogo sigue siendo de lectura: admite recepción y cierre de revisión de denuncias, pero su ocultamiento se demuestra con reportes locales. No hay moderación granular independiente de un comentario/foto en esta entrega.
- Persistencia **JSON v5**, compatible con v1–v4. Se conservan los datos previos y la identidad de reintento. Los vínculos internos de autoría siguen en el almacenamiento local; la política de retención del piloto está pendiente.

Escenarios, alcance y comprobaciones: [Séptima entrega](docs/07_entrega_privacidad_contenido.md). La validación manual integral sigue pendiente; el prototipo aún no se considera completo.

### Capacidades conservadas de la sexta entrega

- Desde el detalle, **Lectura pública y enlace · demo** abre una representación adaptable y sin cuenta del reporte aprobado: evidencia, gestiones, actualizaciones, comentarios e historial públicos.
- **Copiar enlace de demostración** vuelve a consultar disponibilidad y copia únicamente un identificador local. El botón de enlace de la cabecera permite pegarlo y abrirlo en el prototipo.
- Los enlaces `reporte-ciudadano-demo://local/reportes/<id>` no son páginas web, no están publicados ni indexados y no abren la app desde otras aplicaciones. Los reportes locales requieren los datos de este dispositivo.
- Oculto, duplicado e inexistente tienen estados propios. Un duplicado solo enlaza a un principal visible. Una edición pendiente conserva la versión aprobada y sus medios; ocultar retira también el contenido de una lectura compartida abierta.
- Esta vista no modifica seguimientos ni marca avisos como leídos. **Abrir en la aplicación** vuelve al detalle participativo, sin acciones automáticas.

Recorridos y comprobaciones históricas: [Sexta entrega](docs/06_entrega_lectura_publica.md). La séptima conserva estos recorridos sin añadir dependencias ni plataformas.

### Capacidades conservadas de la quinta entrega

- **Perfil → Escenario de moderación · demo → Abrir moderación → Gestiones y solución**: registrar gestiones sobre reportes aprobados, recuperar borradores y revisar versiones.
- Fecha, destinatario ficticio, acción, referencia, respuesta, siguiente paso, resumen y evidencia pública simulada; responsable, notas y documentos internos separados. Nada se publica hasta aprobar la gestión; una edición pendiente conserva la versión aprobada anterior.
- Desde **Aportar comentario o evidencia**, elegir **Proponer solución** o **Evidencia contradictoria**. Aprobar una propuesta cambia a **Solución reportada**; verificar exige otra decisión con motivo público. La evidencia contradictoria aprobada se conserva y abre revisión, sin reapertura automática.
- Verificar, conservar el estado tras revisión y reabrir registran motivo, fecha y revisor. Una gestión o respuesta nunca resuelve por sí sola el reporte. No se emiten avisos públicos mientras el reporte esté oculto.
- Persistencia JSON **v4**, compatible con v1/v2/v3; gestiones, decisiones, auditoría y avisos comparten escritura local. Reintentos idempotentes y rechazo de decisiones de seguimiento obsoletas.

Recorridos, límites y comprobaciones: [Quinta entrega](docs/05_entrega_gestiones_solucion.md). Seguimos en la etapa de prototipo; no se ha iniciado un piloto real.

### Capacidades conservadas de la cuarta entrega

- Desde el detalle: confirmar que sigue ocurriendo, actualizar la observación sin sumar otra persona, seguir/dejar de seguir y aportar comentarios o evidencia.
- El autor no suma al umbral independiente. `CommunityRules` mantiene el umbral inicial **propuesto y configurable** de dos observadores. Los comentarios no son confirmaciones; confirmar no reabre ni degrada una solución verificada.
- Aportes y adjuntos simulados con borradores, revisión previa, motivo, corrección, rechazo, edición y reenvío idempotente. Una edición pendiente conserva el aporte aprobado anterior.
- **Siguiendo** muestra reportes públicos seguidos y novedades sin leer. Abrir el detalle marca sus novedades públicas como leídas. Ocultos y duplicados se retiran de esa lista.
- Campana **Notificaciones simuladas**: novedades públicas aprobadas y decisiones privadas para el autor, lectura y preferencias de comentarios agrupados. El permiso push rechazado es un escenario simulado; no hay push real.
- Tres identidades ciudadanas ficticias: correo, Google y **Perfil → Tercera cuenta ciudadana · demo**. La moderación usa otra identidad independiente.
- Las capacidades comunitarias siguen persistidas junto con las demás decisiones locales.

Escenarios, comprobaciones y revisión de las entregas anteriores: [Cuarta entrega y estado del proyecto](docs/04_entrega_comunidad.md).

## Ejecutar

Entorno utilizado: Flutter **3.47.3** estable y Dart **3.13.3**. Se necesita el SDK Android y un teléfono con depuración USB o un emulador iniciado. No se necesitan cuentas, claves ni servicios externos para utilizar el prototipo.

Desde la raíz:

```powershell
flutter pub get
flutter devices
flutter run -d <id-del-dispositivo-android>
```

Sustituir el identificador por el mostrado en `flutter devices`. Solo está generada la plataforma Android. Para producir un APK de desarrollo:

```powershell
flutter build apk --debug
```

El resultado se guarda en `build/app/outputs/flutter-apk/app-debug.apk`. Para compilar exclusivamente para un emulador Android x64:

```powershell
flutter build apk --debug --target-platform android-x64
```

Un APK x64 no sirve para teléfonos ARM. La primera compilación de cada arquitectura puede requerir descargar motores Flutter y dependencias Android. No hay configuración de publicación en tiendas.

## Tercera entrega: revisión y versiones

- **Perfil → Escenario de moderación · demo → Abrir moderación**: identidad independiente, cola por antigüedad y filtros de nuevos/ediciones. No es autorización de producción.
- Comparación completa entre la versión aprobada conservada y la enviada: texto, categoría, ubicación, fecha y adjuntos simulados. Dos columnas en escritorio con texto normal; apiladas en móvil o con texto ampliado.
- Aprobar, solicitar corrección y rechazar con confirmación, motivo, fecha y revisor. La decisión y la versión pública se guardan juntas; un fallo de almacenamiento no publica parcialmente.
- El autor ve sus decisiones e historial en **Perfil → Mis envíos**. Puede corregir, preparar una nueva revisión tras rechazo o editar un reporte aprobado. Reenviar siempre requiere una acción explícita.
- La edición pendiente mantiene la versión pública anterior completa, incluidos sus adjuntos. Aprobar cambia la versión sin modificar el seguimiento ni levantar un ocultamiento.
- Ocultar, restaurar disposición visible y marcar duplicado requieren motivo. El duplicado solo enlaza a otro reporte aprobado y visible; el enlace desaparece si el principal deja de ser público. No se fusionan aportes.
- Explorar, detalle y coincidencias comparten la proyección pública. Lista y detalle abiertos reaccionan a aprobación y ocultamiento; se conserva la búsqueda.
- Revisiones, decisiones, disposición pública y borradores persisten localmente. La lectura migra los datos de la segunda entrega sin cambiar sus identificadores de reintento.

La moderación de reportes opera sobre **envíos creados en este dispositivo**. El contenido original de los seis reportes públicos del catálogo es de lectura; ahora se puede confirmar, seguir y enviar aportes sobre ellos. No aparecen como reportes editables en la cola ni como principales seleccionables. Para probar duplicados, crear y aprobar dos reportes. No hay moderación automática, servidor, push ni comunicación con autoridades.

### Capacidades conservadas de la segunda entrega

- Acceso simulado por correo/código o Google, con alias ficticio y sin credenciales reales.
- Reporte en tres pasos: datos y adjuntos opcionales → punto manual o GPS simulado y coincidencias públicas → resumen editable y envío a revisión.
- Validación de categoría, título, descripción, fecha no futura, coordenadas, declaración de El Alto, referencia y máximo de cinco adjuntos simulados. Los límites propuestos están centralizados en `ReportRules`.
- Borradores autoguardados al cambiar campos y paso, con guardado explícito y recuperación desde Perfil. Al salir con cambios se puede guardar, descartar o seguir editando.
- Persistencia local de borradores y envíos pendientes tras reiniciar la aplicación. La sesión se reinicia como visitante; entrar con el mismo proveedor de demostración permite recuperar sus datos.
- Coincidencias por categoría y distancia (radio inicial configurable de 150 m), solo entre reportes públicos abiertos. Abrir el detalle conserva el borrador y no envía nada. Se puede continuar como problema distinto o confirmar explícitamente desde el detalle existente.
- Envíos con estado **Pendiente de aprobación**, accesibles desde Perfil → Mis envíos y desde moderación. No se incorporan a Explorar ni a consultas públicas por ID hasta su aprobación y siempre que sean visibles.
- Reintentos con una identidad estable por borrador: un doble envío o una respuesta perdida no generan otro reporte.
- Mensajes de revisión de 08:00 a 20:00 en Bolivia, sin prometer un plazo de aprobación.

Se conserva la primera entrega: tema visual, navegación principal, lista con búsqueda por zona/referencia, filtro de soluciones verificadas, detalle público, errores/reintentos y seis reportes públicos de ejemplo.

## Recorrido de demostración

1. Abrir **Reportar** como visitante.
2. Escribir un alias ficticio. Elegir **Simular acceso con Google**, o **Simular acceso por correo** e introducir el código visible **123456**. No se conecta a Google ni se envía correo.
3. Seleccionar categoría y completar título (10–100 caracteres) y descripción (20–1.500). Dejar el momento observado en Ahora o elegir uno anterior en hora de Bolivia. Las fotos son opcionales.
4. En el segundo paso, introducir coordenadas manualmente o pulsar **Usar mi ubicación · simulada**. El ejemplo `-16.5000, -68.1600` con categoría Baches y calzada produce una coincidencia ficticia. Declarar El Alto; no hay validación territorial automática.
5. Revisar coincidencias y continuar como problema distinto, si corresponde. Revisar el resumen y pulsar **Enviar a revisión**.
6. Consultar **Ver estado de mi envío**, o volver a **Perfil → Mis envíos**. El envío sigue fuera de Explorar.
7. Volver a Perfil y entrar en **Escenario de moderación · demo → Abrir moderación**. Abrir el envío, pulsar **Solicitar corrección**, escribir un motivo ficticio y confirmar.
8. Volver a Perfil, cerrar la sesión simulada y entrar con el mismo proveedor ciudadano del paso 2. Abrir **Mis envíos → Corregir y reenviar**, completar la corrección y enviar explícitamente.
9. Regresar al escenario de moderación y **Aprobar versión** con motivo. Cerrar la sesión: el reporte aparece en Explorar como visitante.
10. Entrar de nuevo como autor y **Editar reporte**. Tras enviarlo, Explorar conserva el texto y los adjuntos anteriores. Moderación muestra ambas versiones; aprobar reemplaza la pública.
11. Desde la revisión, **Ocultar reporte** con motivo. Desaparece de lista, detalle y coincidencias. Aprobar otra edición no lo restaura; esa acción es independiente.

Más escenarios y cobertura: [Entrega de revisión y versiones](docs/03_entrega_revision.md).

### Escenarios de recuperación

- **Borrador:** escribir datos, volver atrás y elegir Guardar borrador. Recuperarlo desde Perfil. También se puede cerrar y abrir la app y entrar con el mismo proveedor simulado.
- **GPS rechazado:** activar ese escenario antes de solicitar ubicación. El formulario mantiene la entrada manual y no vuelve a pedir GPS durante ese recorrido.
- **Sin conexión / Fallo de envío:** elegir el escenario en el resumen y enviar. El borrador permanece guardado. Cambiar a Envío normal y reintentar explícitamente.
- **Respuesta perdida:** el envío queda recibido localmente, pero se muestra incertidumbre. Pulsar Recuperar envío devuelve el mismo registro; no crea un duplicado. También aparece en Mis envíos tras reiniciar.
- **Cuentas:** correo, Google y la tercera cuenta ciudadana representan identidades de demostración separadas. Cerrar sesión oculta sus borradores, pendientes, seguimientos y avisos; entrar con otra cuenta no los muestra. Esto prueba comportamiento de interfaz, no seguridad de producción.
- **Fotos:** Simular cámara/galería agrega fichas de adjuntos que se pueden quitar; no crea ni accede a fotografías reales.

## Qué funciona, qué está simulado y qué falta

| Capacidad | Estado |
| --- | --- |
| Navegación, formularios, búsqueda y consulta | Funcionan localmente. |
| Guardado y recuperación | Almacenamiento local real con preferencias privadas de Android; sin servidor, sincronización ni almacenamiento seguro de datos sensibles. |
| Acceso por correo/Google | Simulado, sin autenticación externa. Cada proveedor corresponde a una cuenta local fija. |
| Envío a revisión | Transacción local simulada. No se comunica con moderadores ni autoridades reales. |
| GPS | Adaptador simulado: punto fijo o permiso rechazado. No usa la ubicación del dispositivo. |
| Cámara/galería | Fichas simuladas, sin fotografías ni acceso al dispositivo. No se procesa EXIF porque no se reciben imágenes reales. |
| Territorio y coincidencias | Coordenadas de demostración y cálculo local de cercanía. Mapa esquemático local, sin cartografía real, geocodificación ni límites oficiales. |
| Moderación y publicación | Operaciones locales simuladas: cola, comparación, decisiones, correcciones, disposición pública y auditoría persistida. Sin controles de servidor. |
| Gestiones y solución | Registro, borradores, revisión y versiones locales; propuesta, verificación y reapertura con historial. Entidades, evidencias y documentos ficticios; no hay recepción oficial, envío de reclamos ni certificación municipal. |
| Confirmar, seguir y aportar | Operaciones locales: confirmación única y aportes revisados antes de publicación. |
| Notificaciones y preferencias | Bandeja local simulada. Avisos privados para autores y públicos para seguidores; sin push ni servicios externos. |
| Lectura compartida | Vista local de demostración, apertura de identificadores y copia al portapapeles. Sin web publicada, indexación, enlaces Android externos ni distribución de contenido a otros dispositivos. |
| Retiro de autoría | Anonimización de metadatos públicos del reporte propio y de sus aportes en él, conservando revisión, seguimiento y contenido. No borra datos ni depura automáticamente texto/fotos. |
| Denuncia de contenido | Recepción y revisión privadas locales. Ocultamiento atómico del reporte local completo al resolver. Sin servicio real de moderación ni comunicación institucional. |
| Seguridad del piloto | No implementada: la separación local de cuentas no sustituye autorización de servidor. |

Los reportes públicos precargados son ficticios. Las gestiones y decisiones locales de seguimiento se aplican sobre ellos al cargar. Los borradores, envíos, publicaciones, decisiones, participaciones, gestiones, seguimientos y avisos creados por el usuario persisten únicamente en este dispositivo; borrar los datos de la app los elimina. El prototipo no recoge credenciales reales ni pide permisos GPS/cámara/push. No hay envío automático en segundo plano.

No se incluyen funciones pospuestas como alertas temporales, zonas seguidas, selector de ciudades, rankings, chat o publicación web. Esta entrega no completa el prototipo ni habilita un piloto.

## Organización y puntos de sustitución

```text
lib/
  main.dart                    # Carga persistencia y compone dependencias; permite reintentar si falla la lectura
  app.dart                     # Idioma, tema y navegación
  core/
    theme/app_theme.dart
    geo_point.dart             # Coordenadas y distancia
  features/reports/            # Repositorio de lectura pública, Explorar y detalle
  features/community/          # Confirmaciones, aportes, seguimientos, bandeja y sus contratos
  features/follow_up/          # Gestiones públicas/internas, revisión y decisiones de solución
  features/sharing/            # Formato del enlace local y apertura de lectura pública
  features/safety/             # Retiro de autoría, denuncias privadas y revisión
  features/submissions/
    domain/                    # Borradores, reglas, sesión, contratos de repositorios y adaptadores
    data/                      # Repositorio local serializado y almacenamiento en preferencias
    presentation/              # Acceso, formulario, Perfil, estado de envío y moderación adaptable
    prototype_services.dart    # Inyección de dependencias sustituibles
```

- `ReportRepository`: consultas exclusivamente públicas; nunca entregar revisiones privadas. `ModeratedReportRepository` combina el catálogo con publicaciones locales y notifica solo cambios públicos, sin recargar Explorar por cada autoguardado. `ReportNoticeRepository` entrega avisos generales de oculto/duplicado sin motivos privados.
- `SessionRepository`: identidad actual y acceso. Implementación de demostración sin credenciales.
- `SubmissionRepository`: borradores, envíos propios, preparación de revisiones y operaciones editoriales. El identificador de cada borrador funciona como clave de idempotencia; `reportId` mantiene el reporte y `baseRevisionId` impide enviar una edición obsoleta. Los accesos de autor y moderador se comprueban en el repositorio local, como simulación.
- `PublicationRecord`: separa última revisión, revisión pública aprobada, disposición e historial privado. La proyección pública no entrega motivos editoriales, revisor, identificadores de acceso ni medios pendientes. La instantánea JSON v5 guarda esas piezas junto con `CommunityState`, `WorkflowState` y `SafetyState` y admite lectura de v1–v4.
- `CommunityRepository`: contrato sustituible para confirmaciones, aportes, seguimiento y avisos. El adaptador local comparte almacenamiento y cola de escrituras con envíos para que aprobación y aviso se confirmen juntos. `PrototypeServices` permite inyectar ambos contratos y `CommunityScope` los lleva a las rutas de interfaz. Las fotos de los aportes usan el mismo `PhotoAdapter` simulado.
- `FollowUpRepository`: contrato sustituible para gestiones y solución. `ManagementSummary` solo contiene los campos destinados a publicación; `ManagementDraft` conserva por separado información interna y una identidad estable de reintento. `ResolutionRecord` separa el candidato aprobado de la decisión de verificación y controla versiones obsoletas. Sus motivos de seguimiento se solicitan explícitamente como texto público revisado. `PrototypeServices` admite inyectar el contrato y la proyección pública lo comparte con comunidad.
- `DraftStorage`: lectura y escritura de una instantánea JSON versionada. `PreferencesDraftStorage` usa un canal de plataforma hacia las preferencias privadas de Android; `MemoryDraftStorage` se usa en pruebas. La implementación Android escribe fuera del hilo de interfaz y confirma la escritura antes de devolver éxito. Las escrituras se serializan y se actualiza el estado observable después de guardarlo. Un autoguardado tardío no recrea un borrador enviado.
- `LocationAdapter` y `PhotoAdapter`: sustituibles sin incorporar permisos ni dependencias nativas de cámara/GPS en esta entrega.
- `DemoReportLink`: codifica y valida enlaces de demostración con solo el identificador. La lectura compartida reutiliza `ReportDetailPage` en modo `publicReading` y consulta el mismo `ReportRepository`; no crea una copia del reporte ni consulta datos privados. El portapapeles usa la API de Flutter, solo tras pulsar Copiar.
- `SafetyRepository`: contrato inyectable para retiro y denuncias. El adaptador local conserva retiros por reporte, anonimiza la proyección y guarda decisiones de denuncia junto con el ocultamiento. `ownComplaints` no expone motivos internos ni identidad del revisor. Un futuro adaptador debe actualizar también la fuente de lectura pública, como hace el adaptador local.

Inyectar implementaciones mediante `PrototypeServices` y `ReporteCiudadanoApp`. El modelo público sigue separando revisión editorial, disposición pública y seguimiento. Las fechas se guardan en UTC y se muestran en UTC−4 (`America/La_Paz`). El almacenamiento actual no está diseñado para información sensible ni para un piloto con usuarios reales.

## Verificación

```powershell
flutter analyze
flutter test
```

La batería incluye regresión de consulta pública; validación de formularios; acceso por correo y Google; guardado, recuperación y descarte; fallos de almacenamiento; separación de cuentas; fecha de Bolivia; coincidencias públicas; envío sin fotos; GPS rechazado; desconexión y reintento; concurrencia y respuesta perdida sin duplicados. Los widgets recorren lista/detalle y formulario en 360 × 800, 390 × 844 y 412 × 915 con texto al 200 %.

Las pruebas de la tercera entrega añaden corrección y publicación, edición pendiente con adjuntos, aprobación sin levantar ocultamiento, rechazo privado, duplicados y principal oculto, decisiones concurrentes, fallos de disco y migración v1. La interfaz de moderación se prueba al 200 % en 360 × 800, 390 × 844, 412 × 915 y 1440 × 900; también se comprueba la actualización del detalle y la lista abiertos.

Los resultados históricos se conservan en los documentos de entregas 03–06; el estado actual se documenta en [Octava entrega](docs/08_entrega_mapa_filtros.md). La recuperación tras reinicio se prueba recreando el repositorio sobre el almacenamiento de prueba. Esto no sustituye una prueba manual del cierre y apertura en un teléfono ni una auditoría con lector de pantalla. La cartografía real, el minimapa del detalle y el ajuste gráfico del punto de envío siguen pendientes.

La séptima entrega añade ocho pruebas de repositorio y seis de interfaz a las 98 existentes. Los resultados de ejecución completa, análisis y compilación están en su documento de entrega. No se ha ejecutado una validación manual en dispositivo ni compilado ARM en esta revisión.

## Documentación de producto

- [Instrucciones para agentes](AGENTS.md)
- [Especificación v0.2](docs/01_especificacion_proyecto_v0.2.md)
- [Diseño del prototipo v0.2](docs/02_prototipo_flutter_v0.2.md)
