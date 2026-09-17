# Reporte Ciudadano

Prototipo Flutter **0.3.0** para consultar, enviar y revisar problemas persistentes de El Alto. Interfaz en español, orientada a Android. Usa únicamente datos ficticios, identificados como **Datos de demostración**.

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

La moderación opera sobre **envíos creados en este dispositivo**. Los seis reportes públicos del catálogo inicial siguen siendo ejemplos de lectura; no aparecen en la cola ni como principales seleccionables. Para probar duplicados, crear y aprobar dos reportes. No hay moderación automática, servidor, notificaciones ni comunicación con autoridades.

### Capacidades conservadas de la segunda entrega

- Acceso simulado por correo/código o Google, con alias ficticio y sin credenciales reales.
- Reporte en tres pasos: datos y adjuntos opcionales → punto manual o GPS simulado y coincidencias públicas → resumen editable y envío a revisión.
- Validación de categoría, título, descripción, fecha no futura, coordenadas, declaración de El Alto, referencia y máximo de cinco adjuntos simulados. Los límites propuestos están centralizados en `ReportRules`.
- Borradores autoguardados al cambiar campos y paso, con guardado explícito y recuperación desde Perfil. Al salir con cambios se puede guardar, descartar o seguir editando.
- Persistencia local de borradores y envíos pendientes tras reiniciar la aplicación. La sesión se reinicia como visitante; entrar con el mismo proveedor de demostración permite recuperar sus datos.
- Coincidencias por categoría y distancia (radio inicial configurable de 150 m), solo entre reportes públicos abiertos. Abrir el detalle conserva el borrador y no envía nada. Se puede continuar como problema distinto. Confirmar un reporte existente queda para la entrega de participación.
- Envíos con estado **Pendiente de aprobación**, accesibles desde Perfil → Mis envíos y desde moderación. No se incorporan a Explorar ni a consultas públicas por ID hasta su aprobación y siempre que sean visibles.
- Reintentos con una identidad estable por borrador: un doble envío o una respuesta perdida no generan otro reporte.
- Mensajes de revisión de 08:00 a 20:00 en Bolivia, sin prometer un plazo de aprobación.

Se conserva la primera entrega: tema visual, navegación principal, lista con búsqueda por zona/referencia, filtro de soluciones verificadas, detalle público, errores/reintentos y seis reportes públicos de ejemplo. Siguiendo sigue siendo una pantalla informativa.

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
- **Dos cuentas:** correo y Google representan dos identidades de demostración separadas. Cerrar sesión oculta sus borradores y pendientes; entrar con el otro proveedor no los muestra. Esto prueba comportamiento de interfaz, no seguridad de producción.
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
| Territorio y coincidencias | Coordenadas de demostración y cálculo local de cercanía. Sin mapas, geocodificación ni límites oficiales. |
| Moderación y publicación | Operaciones locales simuladas: cola, comparación, decisiones, correcciones, disposición pública y auditoría persistida. Sin controles de servidor. |
| Gestiones y solución | Estados precargados en el catálogo; aún sin operaciones para registrar gestiones o verificar/reabrir soluciones. |
| Confirmar, seguir, aportar, notificaciones y lectura compartida | Pendientes de próximas entregas. |
| Seguridad del piloto | No implementada: la separación local de cuentas no sustituye autorización de servidor. |

Los reportes públicos precargados son ficticios y se restauran al arrancar. Los borradores, envíos, publicaciones y decisiones creados por el usuario persisten únicamente en este dispositivo; borrar los datos de la app los elimina. El prototipo no recoge credenciales reales ni pide permisos GPS/cámara. No hay envío automático en segundo plano.

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
  features/submissions/
    domain/                    # Borradores, reglas, sesión, contratos de repositorios y adaptadores
    data/                      # Repositorio local serializado y almacenamiento en preferencias
    presentation/              # Acceso, formulario, Perfil, estado de envío y moderación adaptable
    prototype_services.dart    # Inyección de dependencias sustituibles
```

- `ReportRepository`: consultas exclusivamente públicas; nunca entregar revisiones privadas. `ModeratedReportRepository` combina el catálogo con publicaciones locales y notifica solo cambios públicos, sin recargar Explorar por cada autoguardado. `ReportNoticeRepository` entrega avisos generales de oculto/duplicado sin motivos privados.
- `SessionRepository`: identidad actual y acceso. Implementación de demostración sin credenciales.
- `SubmissionRepository`: borradores, envíos propios, preparación de revisiones y operaciones editoriales. El identificador de cada borrador funciona como clave de idempotencia; `reportId` mantiene el reporte y `baseRevisionId` impide enviar una edición obsoleta. Los accesos de autor y moderador se comprueban en el repositorio local, como simulación.
- `PublicationRecord`: separa última revisión, revisión pública aprobada, disposición e historial privado. La proyección pública no entrega motivos, revisor, identificadores de acceso ni medios pendientes. La instantánea JSON v2 guarda esas piezas juntas y admite lectura de v1.
- `DraftStorage`: lectura y escritura de una instantánea JSON versionada. `PreferencesDraftStorage` usa un canal de plataforma hacia las preferencias privadas de Android; `MemoryDraftStorage` se usa en pruebas. La implementación Android escribe fuera del hilo de interfaz y confirma la escritura antes de devolver éxito. Las escrituras se serializan y se actualiza el estado observable después de guardarlo. Un autoguardado tardío no recrea un borrador enviado.
- `LocationAdapter` y `PhotoAdapter`: sustituibles sin incorporar permisos ni dependencias nativas de cámara/GPS en esta entrega.

Inyectar implementaciones mediante `PrototypeServices` y `ReporteCiudadanoApp`. El modelo público sigue separando revisión editorial, disposición pública y seguimiento. Las fechas se guardan en UTC y se muestran en UTC−4 (`America/La_Paz`). El almacenamiento actual no está diseñado para información sensible ni para un piloto con usuarios reales.

## Verificación

```powershell
flutter analyze
flutter test
```

La batería incluye regresión de consulta pública; validación de formularios; acceso por correo y Google; guardado, recuperación y descarte; fallos de almacenamiento; separación de cuentas; fecha de Bolivia; coincidencias públicas; envío sin fotos; GPS rechazado; desconexión y reintento; concurrencia y respuesta perdida sin duplicados. Los widgets recorren lista/detalle y formulario en 360 × 800, 390 × 844 y 412 × 915 con texto al 200 %.

Las pruebas de la tercera entrega añaden corrección y publicación, edición pendiente con adjuntos, aprobación sin levantar ocultamiento, rechazo privado, duplicados y principal oculto, decisiones concurrentes, fallos de disco y migración v1. La interfaz de moderación se prueba al 200 % en 360 × 800, 390 × 844, 412 × 915 y 1440 × 900; también se comprueba la actualización del detalle y la lista abiertos.

Los resultados ejecutados y sus límites se registran en [Verificación de la tercera entrega](docs/03_entrega_revision.md#verificación). La recuperación tras reinicio se prueba recreando el repositorio sobre el almacenamiento de prueba. Esto no sustituye una prueba manual del cierre y apertura en un teléfono ni una auditoría con lector de pantalla. Participación, gestiones, solución y retiro de autoría aún requieren sus próximas entregas.

Resultado de esta entrega: **análisis sin incidencias, 49 pruebas aprobadas y APK de desarrollo Android x64 compilado**. No se ha ejecutado una validación manual en dispositivo ni compilado ARM en esta entrega.

## Documentación de producto

- [Instrucciones para agentes](AGENTS.md)
- [Especificación v0.2](docs/01_especificacion_proyecto_v0.2.md)
- [Diseño del prototipo v0.2](docs/02_prototipo_flutter_v0.2.md)

