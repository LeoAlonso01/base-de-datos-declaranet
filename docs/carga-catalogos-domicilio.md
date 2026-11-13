# Carga de catálogos geográficos (domicilio)

Los catálogos `catalogos.municipio`, `catalogos.codigo_postal` y
`catalogos.asentamiento` se crean vacíos en la migración `0009` porque su volumen
(miles de municipios y millones de asentamientos) no se puede sembrar de forma
confiable a mano. La carga completa se realiza desde fuentes oficiales.

## Fuentes oficiales

| Catálogo | Fuente | URL de referencia |
|---|---|---|
| `entidad_federativa` | INEGI — Catálogo Único de Claves Geoestadísticas | https://www.inegi.org.mx/app/ageeml/ |
| `municipio` | INEGI — Catálogo Único de Claves Geoestadísticas | https://www.inegi.org.mx/app/ageeml/ |
| `codigo_postal` | Correos de México / SEPOMEX — Catálogo de Códigos Postales | https://www.correosdemexico.gob.mx/SSLServicios/ConsultaCP/Descarga.aspx |
| `asentamiento` | Correos de México / SEPOMEX — Catálogo de Asentamientos | (mismo portal) |
| `tipo_asentamiento` | SEPOMEX | (incluido en el catálogo de asentamientos) |

## Procedimiento de carga (ejemplo con `COPY`)

1. Descargar el archivo oficial y convertirlo a CSV con las columnas esperadas.
2. Cargar en una tabla temporal y luego insertar en las tablas definitivas respetando las FK.

```sql
-- Ejemplo: carga de municipios desde CSV
\copy catalogos.municipio (entidad_federativa_id, clave, nombre) FROM 'municipios.csv' CSV HEADER;

-- Ejemplo: carga de códigos postales
\copy catalogos.codigo_postal (municipio_id, codigo) FROM 'codigos_postales.csv' CSV HEADER;

-- Ejemplo: carga de asentamientos
\copy catalogos.asentamiento (codigo_postal_id, tipo_asentamiento_id, nombre) FROM 'asentamientos.csv' CSV HEADER;
```

3. Verificar conteos y FKs tras la carga:

```sql
SELECT count(*) FROM catalogos.municipio;
SELECT count(*) FROM catalogos.codigo_postal;
SELECT count(*) FROM catalogos.asentamiento;
```

## Datos de ejemplo (solo desarrollo)

El archivo `sql/80_semillas/ejemplo_domicilio.sql` contiene unos cuantos registros
ilustrativos (Michoacán, CDMX, Jalisco) para probar las relaciones. **No es la solución
definitiva** y no debe usarse en producción.

## Documentación

Registrar la fuente y la fecha de actualización del catálogo cargado en este documento
y en `CONTEXT.md` cuando se realice la carga.
