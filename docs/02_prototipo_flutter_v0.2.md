# Reporte Ciudadano — Diseño del prototipo Flutter

Versión 0.2 · 9 de septiembre de 2026 · El Alto, Bolivia.

Reglas de producto: [01_especificacion_proyecto_v0.2.md](01_especificacion_proyecto_v0.2.md). Este documento sustituye el brief visual 0.1 para la primera entrega. Describe un prototipo por construir, no una app existente.

## 1. Objetivo y alcance visual

Validar que una persona entiende cómo documentar un problema persistente, enviarlo a aprobación, conocer sus gestiones y seguirlo hasta una solución revisada. Probar también el trabajo del equipo moderador. Usar Flutter con datos simulados; Figma no es un entregable requerido.

Solo El Alto y problemas persistentes. No mostrar selector de ciudad, pestañas de alertas, Novedades independiente, zonas seguidas ni controles inactivos para futuras funciones. La ampliación territorial se prepara en el modelo, no ocupa espacio en la interfaz inicial.

## 2. Dirección visual de partida

Mantener la dirección inicial como propuesta revisable: estilo claro, comunitario, sin escudos ni apariencia municipal. Priorizar título, ubicación, evidencia y seguimiento sobre fotografías decorativas.

| Elemento | Valor inicial |
| --- | --- |
| Fuente | Roboto |
| Fondo / superficie | #F8FAFC / #FFFFFF |
| Principal / presionado / suave | #1D4ED8 / #1E40AF / #EFF6FF |
| Texto principal / secundario | #0F172A / #475569 |
| Borde decorativo / campo | #CBD5E1 / #64748B |
| Advertencia / fondo | #92400E / #FFFBEB |
| Error / fondo | #B91C1C / #FEF2F2 |
| Solución / fondo | #166534 / #F0FDF4 |
| Título pantalla | 24/32, peso 700 |
| Título sección | 20/28, peso 600 |
| Lectura / título tarjeta | 16/24, pesos 400 / 600 |
| Metadatos | 14/20 |
| Espaciado | 4, 8, 12, 16, 24, 32 |
| Márgenes | 16; 24 en superficies más anchas |
| Radios | Tarjetas 16; botones/campos 12 |
| Objetivos táctiles | Mínimo 48 × 48; botón principal de altura mínima 52 |

Verificar contraste final: 4,5:1 texto normal y 3:1 texto grande y elementos funcionales. No comunicar estados solo con color. Dimensiones lógicas Flutter; alturas mínimas, texto escalable y contenido desplazable.

Referencia móvil 390 × 844; comprobar 360 × 800, 412 × 915, teclado, áreas seguras y texto al 200 %. Moderación adaptable con referencia de escritorio 1440 × 900 y alternativa utilizable en pantalla estrecha.

## 3. Navegación propuesta

Cuatro destinos: Explorar, Reportar, Siguiendo y Perfil. Reportar abre un flujo y oculta la navegación inferior. Campana en cabecera para la bandeja. El encabezado identifica El Alto sin presentar un selector de ciudades.

Explorar conserva modo mapa/lista, filtros y desplazamiento. Siguiendo contiene únicamente reportes. Perfil contiene mis reportes, pendientes, borradores, preferencias, ayuda y acceso. La vista de moderación se abre desde un acceso autorizado; en demostración, un selector de escenario claramente etiquetado permite representar cada rol.

## 4. Pantallas y comportamientos

| ID | Pantalla | Contenido y decisiones |
| --- | --- | --- |
| P01 | Bienvenida | Propósito centrado en seguimiento de problemas de El Alto; explorar sin registro; ingresar opcional. No pedir GPS al iniciar. |
| P02 | Explorar mapa | Búsqueda de zona/referencia, filtros, marcadores agrupados, ubicación contextual, «Buscar en esta zona» y tarjeta seleccionada. Atribución visible si se usa proveedor real. |
| P03 | Explorar lista | Categoría, título, zona/referencia, estado, última observación, evidencia opcional y última gestión si existe. Cercanía con GPS; recientes sin él. |
| P04 | Filtros | Categoría, seguimiento y fecha. Abiertos por defecto; permitir soluciones verificadas. Limpiar y aplicar; filtros activos visibles. |
| P05 | Detalle | Título, categoría, ubicación, fechas, estado, fotos o «Sin foto adjunta», descripción, autor, minimapa; confirmar, seguir y aportar. Secciones Gestiones, Actualizaciones, Comentarios e Historial. |
| P06 | Reportar 1/3 | Categoría, título, descripción, momento observado y 0–5 fotos. Mensaje sobre hechos y datos personales. Cámara/galería con estado real o simulado explícito. |
| P07 | Reportar 2/3 | Punto ajustable, «Usar mi ubicación», El Alto y zona/referencia. Coincidencias públicas; ver y confirmar existente o continuar como problema distinto. |
| P08 | Reportar 3/3 | Resumen editable y «Enviar a revisión». Explicar que alias, ubicación y contenido serán públicos tras aprobarse. Éxito: «Reporte enviado · Pendiente de aprobación». |
| P09 | Acceso | Correo/código y Google; alias inicial. En prototipo acceso simulado, sin recoger credenciales reales. Volver al contexto sin enviar nada automáticamente. |
| P10 | Aportar | Comentario, sigue ocurriendo, agregar evidencia o proponer solución. Textos/fotos a revisión. Confirmación simple inmediata en el escenario simulado. |
| P11 | Siguiendo | Reportes y novedades aprobadas desde la última visita; sin pestaña Zonas. Vacío con acción Explorar. |
| P12 | Notificaciones | Cambios aprobados, evidencias y gestiones; preferencias y lectura. Avisos privados de revisión para el autor. No simular push real sin identificarlo. |
| P13 | Perfil y mis envíos | Mis reportes, pendientes, correcciones solicitadas, rechazados y borradores. Retirar autoría con explicación; proceso de eliminación de cuenta marcado pendiente de política definitiva. |
| P14 | Denunciar contenido | Motivos de privacidad, acoso, información falsa, spam u otros. Recepción para revisión sin promesa de plazo. Distinto del reclamo urbano ante autoridades. |
| P15 | Lectura pública | Vista adaptable del reporte aprobado y visible, gestiones y evidencia pública. Estados oculto, duplicado e inexistente. En prototipo es una representación; compartir indica enlace de demostración o función pendiente. |
| P16 | Moderación | Cola por antigüedad y tipo; detalle del envío y comparación de versiones; aprobar, pedir corrección, rechazar, ocultar, duplicado, verificar solución y reabrir. Motivo y auditoría. |
| P17 | Registrar gestión | Fecha, destinatario, acción, referencia opcional, evidencia, respuesta y siguiente paso. Separar información pública de notas/responsable internos. |
| P18 | Estado de mi envío | Línea de revisión con fecha de envío, motivo, correcciones y reenviar. Accesible al autor; no forma parte de la lectura pública. |

En P05, «Gestión registrada» describe una acción, no un nuevo estado de solución. «Solución verificada» explica que fue revisada por moderación. «Solución reportada» aclara que falta verificar la solución, aunque la evidencia ya esté aprobada para publicación.

En P08 y P18 mostrar «Revisamos contenido de 08:00 a 20:00, hora de Bolivia». Fuera del horario: «Tu envío quedó pendiente para revisión en horario de atención». No introducir un contador ni fecha prometida de aprobación.

En P16 un moderador puede aprobar contenido sin verificar una solución. Ocultar y rechazar requieren confirmación de la acción y motivo; mantener claridad sobre la diferencia entre ambos. No mostrar contenido pendiente en el modo visitante.

## 5. Versiones, retiro y estados de interacción

| Situación | Comportamiento visible |
| --- | --- |
| Nuevo reporte pendiente | Autor ve su envío y estado; comunidad no lo encuentra. |
| Edición pendiente | Autor ve borrador enviado y versión pública anterior claramente diferenciados. |
| Corrección solicitada | Motivo localizado y acción «Corregir y reenviar». |
| Rechazado | Motivo privado para autor y vía de revisión; sin contenido público nuevo. |
| Foto o comentario pendiente | Etiqueta visible para autor; no se incorpora a galería, comentarios ni conteos públicos. |
| Solución propuesta pendiente de aprobación | Envío privado; el estado público anterior permanece. |
| Evidencia de solución aprobada | «Solución reportada · Pendiente de verificar». |
| Reporte oculto | Sustituir texto/fotos por aviso general y retirar acciones públicas. |
| Autoría retirada | Conservar reporte e historial público con «Autor anónimo», sin repetir alias anterior. |
| Duplicado | Aviso y acceso al principal visible; nunca publicar un enlace que revele un pendiente. |
| GPS rechazado | Selección manual, sin solicitudes repetitivas. |
| Sin conexión | Conservar borrador; indicar antigüedad de datos guardados. |
| Envío fallido | «No pudimos enviar. Tu borrador está guardado» y reintentar. |
| Confirmación repetida | «Ya confirmaste»; actualizar observación sin aumentar personas. |

Salir de Reportar con cambios ofrece guardar borrador, descartar o seguir editando. Un visitante que inicia sesión vuelve al punto exacto. Abrir una coincidencia no publica también el borrador y confirmar exige una acción explícita.

## 6. Componentes Flutter reutilizables

Tema central para colores, texto y espaciado. Componentes: tarjeta de reporte; etiqueta de seguimiento; etiqueta de revisión; resumen de gestión; evento de historial; galería; campo de ubicación; coincidencia; selector de fotos; botón de observación; seguir; aviso contextual; estado vacío; formulario con error; comparación de revisiones y acción de moderación con motivo.

Separar etiquetas de revisión y seguimiento para que «Pendiente de aprobación» nunca parezca un estado de resolución. Evitar duplicar reglas de negocio en widgets. Mantener adaptadores para datos, ubicación, imágenes y sesión para sustituir simulaciones después.

## 7. Escenarios de demostración

Todos los reportes llevan «Datos de demostración». Usar referencias ficticias y no atribuir reclamos o respuestas a entidades reales. Si el mapa representa El Alto, los puntos simulados siguen claramente diferenciados de incidentes reales.

- Bache sin foto, aprobado y sin confirmaciones.
- Acera deteriorada, confirmada por varios observadores, con reclamo ficticio presentado.
- Luminaria con evidencia aprobada de posible solución, pendiente de verificar.
- Rampa reparada con solución verificada en el escenario.
- Basura con nuevo reporte pendiente de aprobación.
- Señalización con corrección solicitada y versión anterior pública.
- Reporte oculto; reporte duplicado; reporte con autoría retirada.

Los ejemplos de gestiones pueden usar «Junta de demostración» y «Entidad de demostración». No inventar documentos de recepción oficiales.

## 8. Recorridos de validación

1. Entrar sin cuenta → explorar lista/mapa → detalle → gestiones.
2. Reportar → acceso simulado → datos → punto → coincidencias → revisión → envío pendiente.
3. Moderador → revisar envío → solicitar corrección → autor corrige → aprobar → visible para visitante.
4. Editar reporte aprobado → versión nueva pendiente → visitante conserva versión anterior → aprobar actualización.
5. Confirmar un reporte → repetir observación → mismo número de personas → seguir.
6. Equipo registra gestión → resumen aprobado aparece en detalle → seguidor recibe novedad simulada.
7. Proponer solución → aprobar contenido → verificar solución → historial completo.
8. Aportar evidencia contradictoria → revisión → reapertura con motivo.
9. Rechazar GPS → punto manual; interrumpir envío → borrador → reintento sin duplicado.
10. Retirar autoría → reporte anónimo; ocultar como moderador → fuera de vistas públicas.

## 9. Accesibilidad y entrega posterior

Listado equivalente al mapa, nombres accesibles en marcadores, foco lógico, errores anunciados, controles de mínimo 48 × 48, texto al 200 % y reducción de movimiento. Conservar filtros y borradores al navegar. Priorizar texto antes de fotos y no superponer controles a atribución, teclado o navegación del sistema.

La entrega futura del prototipo debe incluir código Flutter ejecutable, instrucciones de ejecución, escenarios disponibles, inventario de funciones reales/simuladas, limitaciones y verificaciones realizadas. No debe afirmar que el backend, los permisos de producción, Google, correo, push o indexación funcionan si solo se han simulado.

Orden recomendado: tema y navegación → explorar/detalle → envío y borradores → revisión y comparación de versiones → comunidad y seguimiento → gestiones y solución → lectura pública de demostración → verificación de recorridos y accesibilidad. No contratar infraestructura ni habilitar el piloto como efecto implícito de construir el prototipo.
