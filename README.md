# Reporte Ciudadano

Base Flutter del prototipo para consultar problemas persistentes de El Alto. Interfaz en español, orientada a Android. Todos los hechos, referencias, personas y gestiones son ficticios y están identificados como **Datos de demostración**.

## Ejecutar

Entorno utilizado: Flutter **3.47.3** estable y Dart **3.13.3**. Se necesita el SDK Android y un teléfono con depuración USB o un emulador iniciado. No se necesitan cuentas, claves ni servicios externos para utilizar los datos locales.

Desde la raíz del repositorio:

```powershell
flutter pub get
flutter devices
flutter run -d <id-del-dispositivo-android>
```

Sustituir el identificador por el mostrado en `flutter devices`. Si no hay un dispositivo Android conectado, iniciar uno desde Android Studio o conectar un teléfono. Solo está generada la plataforma Android; no se incluye un destino web, Windows o iOS.

Para generar un APK de desarrollo:

```powershell
flutter build apk --debug
```

El resultado se guarda en `build/app/outputs/flutter-apk/app-debug.apk`. Es una compilación de demostración, sin configuración de publicación en tiendas.

La compilación comprobada en esta entrega fue para **Android x64**, apropiada para emuladores de esa arquitectura:

```powershell
flutter build apk --debug --target-platform android-x64
```

El APK generado actualmente es x64, no para teléfonos ARM. La compilación general se interrumpió durante la descarga lenta de los motores ARM de Flutter; para un teléfono ARM hay que ejecutar la compilación general y permitir que esas descargas terminen.

## Qué incluye esta entrega

- Tema Material con Roboto, paleta, tipografía, espaciado y radios basados en el diseño v0.2.
- Navegación Explorar, Reportar, Siguiendo y Perfil. Reportar abre una ruta sin barra inferior; los últimos tres destinos explican honestamente las funciones todavía no implementadas.
- Explorar en lista, búsqueda local por zona/referencia, abiertos por defecto y opción de incluir soluciones verificadas. Orden por observación más reciente, sin GPS.
- Conservación de búsqueda, filtro y desplazamiento al volver del detalle o cambiar de destino.
- Detalle con categoría, descripción, autoría, ubicación textual ficticia, fechas, conteo simulado de observadores, ausencia de fotos, gestiones, actualizaciones, comentarios e historial públicos.
- Carga, error con reintento, búsqueda vacía y reporte no disponible.
- Seis reportes públicos de ejemplo: bache, acera con gestión, luminaria con solución reportada, rampa con solución verificada, señalización con edición privada y banco con autoría retirada. La rampa se muestra al incluir soluciones verificadas.
- Casos internos pendiente, oculto y duplicado para comprobar que no aparecen en consultas públicas.

## Qué está simulado y qué falta

| Capacidad | Estado |
| --- | --- |
| Navegación, búsqueda, filtros y detalle | Funcionan localmente. |
| Reportes, observaciones, fechas, conteos, gestiones e historial | Datos estáticos de demostración en memoria; no representan hechos reales. |
| Aprobación, ocultamiento y solución verificada | Estados precargados. No hay operaciones de moderación. |
| Consulta pública | Filtrado local y proyección sin revisión pendiente; no constituye autorización de servidor. |
| Sesión | Consulta como visitante, sin autenticación ni recolección de credenciales. |
| Reportar, borradores, confirmar, seguir, aportar y perfil personal | No implementados en esta base; no hay botones de envío que simulen éxito. |
| Mapas, GPS, cámara y fotos | No integrados. Ubicación textual ficticia y «Sin foto adjunta». No se solicitan permisos. |
| Notificaciones, backend, páginas compartibles e indexación | No implementados. |
| Persistencia | No hay base de datos ni almacenamiento permanente; reiniciar restaura los datos y filtros iniciales. |

No se incluyen funciones pospuestas en la especificación, como alertas temporales, zonas seguidas, selector de ciudades, rankings o chat. Esta entrega es una parte de la primera etapa, no el prototipo completo ni un piloto habilitado.

## Organización y sustitución del repositorio

```text
lib/
  main.dart                         # Composición: inyecta DemoReportRepository
  app.dart                          # Aplicación, idioma y navegación principal
  core/theme/app_theme.dart         # Tema y constantes visuales
  features/reports/
    domain/report.dart              # Modelo, revisión, disposición y seguimiento
    domain/report_repository.dart   # Contrato de consultas públicas asíncronas
    data/demo_report_repository.dart
    presentation/                   # Explorar, detalle y componentes
```

Para conectar otra fuente de datos, implementar `ReportRepository` e inyectarla en `ReporteCiudadanoApp` desde `main.dart`. Las pantallas no importan datos de demostración. `listPublicReports` y `getPublicReport` deben devolver exclusivamente versiones aprobadas y visibles, sin revisiones privadas ni notas internas. Un ID no público devuelve `null`; los errores se muestran con reintento.

El modelo separa revisión editorial, disposición pública y seguimiento. La edición pendiente no sustituye la versión pública. Las fechas del ejemplo son UTC y se muestran con UTC−4, correspondiente a `America/La_Paz`; este formateador no pretende resolver zonas horarias de otros territorios. Una futura fuente real deberá aplicar permisos y filtrado en el servidor.

## Verificación

```powershell
flutter analyze
flutter test
```

Pruebas de repositorio: exclusión de pendientes/ocultos/duplicados por lista e ID, conservación de versión aprobada, ausencia de revisión privada en la respuesta, autoría anónima, separación de gestión y solución, conversión de fecha a hora de Bolivia.

Pruebas de widgets: lista → detalle → regreso, conservación de búsqueda, navegación principal, filtro de soluciones, búsqueda vacía, error/reintento, detalle no público y recorridos con texto al 200 % en 360 × 800, 390 × 844 y 412 × 915. Detectaron y permitieron corregir desbordamientos del encabezado y la acción de las tarjetas.

Resultados de esta entrega: `flutter analyze` sin incidencias, **12 pruebas aprobadas** y compilación de APK Android x64 completada. Gradle emitió advertencias del acceso nativo de Java y de la versión XML de las herramientas del SDK, sin impedir esa compilación. No se ha realizado una prueba manual en teléfono/emulador ni una auditoría con lector de pantalla. Los diez recorridos del prototipo completo todavía no son ejecutables porque los flujos de envío, moderación y participación quedan para siguientes entregas.

## Documentación de producto

- [Instrucciones para agentes](AGENTS.md)
- [Especificación v0.2](docs/01_especificacion_proyecto_v0.2.md)
- [Diseño del prototipo v0.2](docs/02_prototipo_flutter_v0.2.md)
