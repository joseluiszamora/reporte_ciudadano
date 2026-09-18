# Instrucciones para agentes — Reporte Ciudadano

## Alcance y fuentes de verdad

Estas instrucciones se aplican a todo el repositorio. Trabaja y redacta la documentación y los textos de interfaz en español.

Antes de modificar el producto, consulta:

1. [Especificación del proyecto v0.2](docs/01_especificacion_proyecto_v0.2.md): alcance, reglas de negocio, roles, privacidad y criterios de aceptación.
2. [Diseño del prototipo Flutter v0.2](docs/02_prototipo_flutter_v0.2.md): pantallas P01–P18, navegación, estilo, estados y recorridos de validación.

Las decisiones explícitas del promotor prevalecen sobre los documentos iniciales. Usa la especificación para las reglas de producto y el diseño para su representación visual. Si una contradicción afecta el trabajo y no se resuelve con esa autoridad, solicita aclaración. No conviertas propuestas o pendientes en decisiones confirmadas. Al cambiar una regla acordada, actualiza la documentación afectada y mantén este archivo coherente con ella.

## Estado del repositorio y objetivo

El repositorio contiene documentación en `docs/` y un prototipo Flutter para Android hasta la sexta entrega: tema, navegación, lista/detalle públicos, acceso simulado, reportes y borradores, moderación con versiones, ocultamiento, duplicados, confirmaciones únicas, aportes revisados, seguimiento, avisos simulados, gestiones revisadas, solución/verificación/reapertura y lectura pública compartida de demostración. La moderación editorial de reportes opera sobre envíos creados en el dispositivo; el contenido original del catálogo es de lectura y admite participación, gestiones y decisiones de seguimiento locales. Consulta `README.md` y `docs/06_entrega_lectura_publica.md` para el alcance, ejecución y comprobaciones actuales; las entregas anteriores se conservan en los documentos 03, 04 y 05. No hay infraestructura ni integraciones externas reales; no describas componentes planeados como existentes.

La etapa en curso es un prototipo navegable en Flutter, en español y orientado a Android, con datos ficticios y repositorios sustituibles. La base actual no completa todos los flujos de esa etapa. Construir el prototipo no autoriza contratar infraestructura ni abrir un piloto real.

El propósito es documentar problemas urbanos persistentes y seguir gestiones ciudadanas hasta una solución revisada. El territorio inicial es El Alto, Bolivia. Se tratan hechos urbanos, no denuncias contra personas o instituciones.

## Límites del alcance

- Incluir exploración mapa/lista, filtros, detalle, reporte en tres pasos, borradores, acceso simulado, aportes, confirmaciones, seguimiento, notificaciones simuladas, moderación adaptable, gestiones y lectura pública de demostración.
- Mantener fuera del alcance: La Paz, alertas temporales, zonas seguidas, pestaña independiente de Novedades, publicación desde la web, iOS, envío automático de reclamos, expedientes PDF, cuentas institucionales verificadas, rankings, chat privado, video, IA de clasificación/moderación, sincronización offline completa, publicación automática en segundo plano y navegación vial.
- No mostrar controles inactivos para funciones pospuestas ni selectores de ciudad o de tipo de incidente.
- Figma no es un entregable requerido.

## Arquitectura al iniciar la implementación

- Flutter es una decisión confirmada. BLoC/Cubit, GoRouter y organización por funcionalidades son propuestas, no dependencias obligatorias.
- Separar presentación, dominio y datos cuando la lógica lo justifique; evitar capas vacías y reglas de negocio duplicadas en widgets.
- Mantener adaptadores sustituibles para datos, sesión, ubicación e imágenes. Centralizar colores, tipografía y espaciado en el tema.
- La segunda entrega usa `PrototypeServices` para inyectar sesión, envíos y adaptadores; `DraftStorage` separa persistencia de las reglas. Conservar borradores y pendientes al reiniciar, serializar escrituras y mantener la clave de idempotencia del borrador en reintentos. Los datos privados nunca se agregan automáticamente al repositorio público.
- La tercera entrega conserva revisiones con un `reportId` estable y un `baseRevisionId` para detectar ediciones obsoletas. `PublicationRecord` separa la revisión aprobada de la última enviada; decidir, publicar y registrar auditoría se persisten juntos en JSON v2, con migración desde v1. `ModeratedReportRepository` comparte la proyección pública de lista, detalle y coincidencias. La identidad moderadora de demostración es independiente de las dos ciudadanas.
- La cuarta entrega amplía la instantánea a JSON v3, compatible con v1/v2, y añade `CommunityRepository` y `CommunityState`. Envios, decisiones, aportes y avisos comparten escritura serializada. La proyección pública añade solo aportes aprobados y confirmaciones únicas; bandeja y Siguiendo comprueban la visibilidad vigente. Hay una tercera identidad ciudadana ficticia para ensayar el umbral propuesto sin contar al autor; el rol moderador sigue separado.
- La quinta entrega añade `FollowUpRepository` y `WorkflowState` en JSON v4, compatible con v1/v2/v3. Gestiones versionadas separan `ManagementSummary` de notas, responsable y documentos internos. `ResolutionRecord` conserva candidato aprobado, evidencias por revisar, versión para rechazar decisiones obsoletas e historial. Aprobar una propuesta permite Solución reportada; verificar, conservar tras revisión o reabrir exige otra acción con motivo público explícito. El revisor y los motivos editoriales permanecen internos. Las decisiones, su proyección y avisos se persisten juntos; ningún cambio de seguimiento restaura un reporte oculto.
- La sexta entrega conserva JSON v4. `DemoReportLink` valida identificadores locales sin datos de sesión y `ReportDetailPage(publicReading: true)` reutiliza la proyección pública, sin participación ni lectura automática de avisos. La copia reconsulta visibilidad; ocultamientos invalidan la vista abierta. Los enlaces solo se abren dentro del prototipo: no hay dominio, web publicada, indexación ni registro de enlaces externos Android.
- Supabase/PostgreSQL/PostGIS/Auth/Storage y FCM son propuestas para el piloto. El proveedor de mapas y las tecnologías de web pública y panel siguen pendientes; no asumir React/Next.js como requisito.
- Separar revisión editorial, disposición pública y seguimiento en el modelo. Un reporte debe poder referenciar una revisión pública aprobada distinta de su edición pendiente.
- Distinguir fechas de observación, envío y publicación. Guardar fechas en UTC y mostrarlas en `America/La_Paz`.
- Preparar el modelo territorial para futuras jerarquías sin añadir opciones de expansión a la interfaz inicial.

## Reglas de negocio que deben conservarse

### Revisión y visibilidad

- Reportes, comentarios, fotografías, actualizaciones con contenido y ediciones requieren aprobación previa a su publicación.
- Estados de revisión propuestos: pendiente de aprobación, corrección solicitada, aprobado y rechazado. La disposición pública —visible, oculto o duplicado— es independiente.
- Un envío nuevo pendiente solo es accesible para su autor y el equipo autorizado. Una edición pendiente conserva la versión pública anterior, incluidos sus medios.
- Aprobar una revisión cambia la versión pública de forma atómica y registra quién decidió, cuándo y por qué; nunca levanta accidentalmente un ocultamiento.
- Aplicar la misma visibilidad a listados, búsquedas, coincidencias, medios, conteos, lectura compartida y notificaciones. Los avisos privados de revisión son para el autor.
- Un duplicado solo enlaza a un principal públicamente accesible; no fusionar aportes automáticamente.
- Se reciben envíos fuera del horario de moderación de 08:00–20:00, hora de Bolivia, y quedan en cola. No prometer plazos ni aprobación automática.

### Seguimiento, confirmaciones y gestiones

- Seguimiento público: reportado → confirmado por la comunidad → solución reportada → solución verificada, con condiciones definidas en la especificación.
- Aprobar evidencia de una solución y verificar la solución son decisiones distintas. Una propuesta pendiente no modifica el estado público; verificar no equivale a certificación municipal.
- Conservar aportes contradictorios aprobados y generar revisión. Reabrir requiere motivo e historial. Los problemas persistentes no vencen automáticamente.
- Una persona cuenta una sola vez por reporte; actualizar su observación no aumenta el conteo. El autor no suma al umbral independiente y los comentarios no son confirmaciones.
- Dos observadores independientes y un radio de duplicados de 150 metros son propuestas configurables. No presentar esos valores ni las reglas de recurrencia como acuerdos definitivos.
- Registrar una gestión, una respuesta o un trabajo anunciado no soluciona por sí solo el problema. Separar el resumen público revisado de notas, responsable interno y documentos sin depurar.

### Datos, permisos y privacidad

- Consulta pública sin cuenta limitada a contenido aprobado y visible. Diferenciar visitante, ciudadano, moderador y administrador según la especificación.
- Usar alias público; nunca mostrar correo ni identificadores de acceso. Retirar autoría conserva el reporte con «Autor anónimo», sin repetir el alias anterior; no equivale a ocultar ni a borrar todos los datos personales.
- Solicitar GPS y cámara en contexto, permitir selección manual y no rastrear ubicación en segundo plano. Reportar sin fotos es válido.
- No inventar límites, distritos ni catálogos oficiales. Sin polígonos validados, no afirmar validación automática de pertenencia a El Alto.
- Aplicar eliminación de EXIF, validación y compresión cuando se procesen imágenes reales; no prometer difuminado automático. Los medios pendientes son privados.
- No incluir secretos privilegiados en clientes. El piloto requerirá autorización de servidor, controles de acceso, idempotencia, transacciones e historial; un selector de roles de demostración no acredita seguridad real.
- Retención, eliminación de cuentas, proveedor de mapas y otros pendientes deben seguir identificados como pendientes hasta acordarse.

## Formularios e interfaz

- Consultar las tablas de los documentos para categorías, campos y pantallas. Valores iniciales configurables: título de 10–100 caracteres, descripción de 20–1.500, referencia opcional de hasta 200 y 0–5 fotos. No permitir observaciones futuras. La entrada de 10 MB por imagen es un límite sugerido.
- Navegación propuesta: Explorar, Reportar, Siguiendo y Perfil; campana para notificaciones. Reportar oculta la navegación inferior durante el flujo.
- Conservar filtros, posición y borradores. Al salir de un reporte con cambios, ofrecer guardar, descartar o continuar. Tras el acceso, volver al contexto exacto sin enviar automáticamente.
- Distinguir etiquetas de revisión y seguimiento. Mostrar errores, vacíos, falta de fotos, GPS rechazado, desconexión, correcciones y reintentos sin duplicados.
- Usar la dirección visual propuesta en el documento de diseño: Roboto, tema claro y comunitario, sin escudos ni apariencia municipal. Tomar colores y medidas de su tabla, sin tratarlos como decisiones inmutables.
- Proporcionar listado equivalente al mapa, nombres accesibles, foco lógico, errores anunciados y reducción de movimiento. No comunicar estados solo mediante color.
- Verificar objetivos táctiles de al menos 48 × 48, botón principal de altura mínima 52, contraste de 4,5:1 para texto normal y 3:1 para texto grande y elementos funcionales.
- Comprobar texto al 200 %, tamaños móviles 360 × 800, 390 × 844 y 412 × 915, teclado y áreas seguras. Moderación debe funcionar tanto en escritorio como en pantalla estrecha.

## Simulaciones y datos de demostración

- Identificar todos los reportes con «Datos de demostración». Usar zonas, referencias y entidades ficticias; no atribuir reclamos o respuestas a entidades reales ni inventar recepciones oficiales.
- Identificar cada capacidad como real o simulada. El acceso por correo y Google del prototipo no debe recoger credenciales reales.
- Cámara y ubicación pueden usar adaptadores reales si el entorno lo permite. No afirmar que autenticación, envío, push, backend, permisos de producción o indexación funcionan si solo se simulan.
- La lectura pública es una representación navegable; compartir debe indicar enlace de demostración o función pendiente, sin afirmar que existe una página publicada.

## Flujo de trabajo y verificación

- Revisar la estructura y las instrucciones aplicables antes de editar; preservar cambios ajenos y limitar el trabajo al alcance solicitado.
- Para implementar el prototipo, seguir como guía: tema/navegación → explorar/detalle → envío/borradores → revisión/versiones → comunidad/seguimiento → gestiones/solución → lectura pública → validación.
- Usar `flutter pub get` para dependencias, `flutter analyze` para análisis estático y `flutter test` para pruebas. La plataforma generada es Android; `flutter build apk --debug` compila una versión de desarrollo. Consultar versiones y requisitos en `README.md`. No afirmar verificaciones no ejecutadas.
- En cambios documentales, verificar coherencia con ambas fuentes y enlaces relativos. En implementación, ejecutar las comprobaciones disponibles pertinentes al cambio y comunicar qué se verificó y qué quedó sin verificar.
- Validar los diez recorridos de la sección 8 del diseño y los criterios de aceptación de la sección 11 de la especificación. Priorizar aislamiento de pendientes, conservación de la versión pública, ocultamiento en todas las superficies, confirmación única, retiro de autoría y reintentos sin duplicados.
- La entrega del prototipo debe incluir código ejecutable, instrucciones de ejecución, escenarios disponibles, inventario de funciones reales/simuladas, limitaciones y verificaciones realizadas.
- No presentar el prototipo como validación de un piloto: este requiere backend real y pruebas entre usuarios, concurrencia, permisos, privacidad, medios, restauración y operación según la especificación.
