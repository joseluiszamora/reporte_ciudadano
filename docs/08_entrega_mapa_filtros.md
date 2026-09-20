# Octava entrega — mapa esquemático y filtros

Versión **0.8.0+8**. Continúa la [séptima entrega](07_entrega_privacidad_contenido.md), según la [especificación](01_especificacion_proyecto_v0.2.md) y el [diseño](02_prototipo_flutter_v0.2.md). Todos los contenidos son ficticios.

## Alcance y escenarios

1. **Explorar → Ver mapa**: agrupaciones de reportes públicos por celdas, norte arriba y tarjetas al seleccionar un marcador. **Ver lista** conserva los mismos filtros. El número de un marcador representa reportes agrupados, no confirmaciones.
2. Desplazar con botones norte/sur/este/oeste o acercar/alejar. **Buscar en esta zona** aplica el rectángulo visible a ambas vistas; mover el mapa por sí solo no cambia el filtro. **Quitar filtro de esta zona** recupera el conjunto anterior. Los reportes sin coordenadas permanecen en la lista sin filtro de área.
3. **Filtros** permite combinar categorías y estados de seguimiento, con fecha inicial/final inclusivas de última observación en Bolivia. Sin categorías seleccionadas se incluyen todas; sin estados, ninguno. Atrás cancela cambios; Aplicar los conserva y Restablecer recupera problemas abiertos sin límite de fecha. La búsqueda continúa limitada a zona/referencia.
4. **Usar ubicación simulada** centra el esquema y ordena por cercanía; **Ensayar GPS rechazado** mantiene disponibles los controles manuales. **Volver al área inicial** restablece centro y orden reciente. No pide permisos reales ni rastrea ubicación.
5. Abrir una tarjeta y volver conserva filtros, modo y posición de exploración. Los resultados se recalculan al cambiar la proyección pública; retirar contenido elimina también su selección. Las observaciones comunitarias más recientes intervienen en orden, fecha y metadatos de tarjeta.

## Arquitectura y simulaciones

- `ExploreFilter` concentra reglas de consulta sobre `ReportRepository`, siempre restringidas a reportes aprobados y visibles. `ExploreArea` representa un rectángulo de coordenadas; no acredita pertenencia a El Alto.
- `DemoReportMap` dibuja una representación esquemática sin proveedor, calles, fronteras, rutas ni geocodificación. Agrupa por celdas de pantalla para mantener objetivos de 48 × 48. El agrupamiento desplaza los marcadores al centro de su celda: no sirve para localizar un lugar real con precisión.
- El adaptador de ubicación se inyecta desde `PrototypeServices`; continúa siendo de demostración. No se añadieron dependencias ni servicios de red.
- Los filtros y el encuadre se conservan durante la sesión, no tras reiniciar la aplicación. La instantánea de datos permanece en **JSON v5**, compatible con las versiones anteriores.
- El mapa usa botones para desplazamiento y zoom; no incorpora gestos de arrastre o pellizco. Ofrece listado equivalente y etiquetas semánticas, sin animaciones automáticas.

## Ejecutar

Desde la raíz del proyecto, con los requisitos descritos en [README](../README.md):

```powershell
flutter pub get
flutter run
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --target-platform android-x64
```

## Validación y pendientes

Las pruebas nuevas comprueban filtros combinados, aislamiento de contenido no público, límites de fecha de Bolivia, observación comunitaria, cercanía y área; selección invalidada al retirar contenido, aplicar/cancelar filtros, alternar mapa/lista y GPS simulado. La interfaz se prueba al 200 % en 360 × 800, 390 × 844, 412 × 915 y 1440 × 900.

Resultados finales de análisis, regresión y compilación: pendientes de registrar al cerrar esta entrega.

El recorrido 1 del diseño incorpora mapa esquemático; se conservan los otros nueve recorridos de las entregas previas. No se acredita cartografía real. Siguen pendientes el minimapa de detalle, el ajuste gráfico del punto de envío (el formulario conserva entrada manual de coordenadas), la validación manual integral en teléfono y lector de pantalla, y la compilación ARM. El proveedor cartográfico, fuente territorial y búsquedas geográficas siguen pendientes de decisión.

La siguiente entrega debe completar las representaciones geográficas de detalle/envío y la validación del prototipo. El piloto requiere infraestructura y controles reales; esta entrega no lo habilita.
