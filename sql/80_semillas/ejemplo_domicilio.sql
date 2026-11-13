-- =============================================================
-- EJEMPLO / DESARROLLO — NO es una migración.
-- Datos ilustrativos para probar las relaciones del domicilio
-- (Michoacán, CDMX, Jalisco). NO usar como solución definitiva:
-- la carga completa se realiza desde fuentes oficiales (INEGI/SEPOMEX).
-- Ver docs/carga-catalogos-domicilio.md
-- =============================================================
BEGIN;

-- Municipios de ejemplo
INSERT INTO catalogos.municipio (entidad_federativa_id, clave, nombre)
SELECT e.id, m.clave, m.nombre
FROM catalogos.entidad_federativa e
JOIN (VALUES
  ('16','053','Morelia'),
  ('16','093','Uruapan'),
  ('16','108','Zamora'),
  ('09','002','Azcapotzalco'),
  ('09','015','Coyoacán'),
  ('09','007','Iztapalapa'),
  ('09','017','Cuauhtémoc'),
  ('14','039','Guadalajara'),
  ('14','120','Zapopan')
) m(clave_entidad, clave, nombre) ON m.clave_entidad = e.clave
ON CONFLICT (entidad_federativa_id, clave) DO NOTHING;

-- Códigos postales de ejemplo
INSERT INTO catalogos.codigo_postal (municipio_id, codigo)
SELECT m.id, c.codigo
FROM catalogos.municipio m
JOIN catalogos.entidad_federativa e ON e.id = m.entidad_federativa_id
JOIN (VALUES
  ('16','053','58000'),
  ('16','093','60000'),
  ('16','108','59600'),
  ('09','015','04000'),
  ('09','007','09000'),
  ('09','017','06000'),
  ('14','039','44100'),
  ('14','120','45000')
) c(clave_entidad, clave_municipio, codigo)
  ON c.clave_entidad = e.clave AND c.clave_municipio = m.clave
ON CONFLICT (municipio_id, codigo) DO NOTHING;

-- Asentamientos de ejemplo
INSERT INTO catalogos.asentamiento (codigo_postal_id, nombre)
SELECT cp.id, a.nombre
FROM catalogos.codigo_postal cp
JOIN catalogos.municipio m ON m.id = cp.municipio_id
JOIN catalogos.entidad_federativa e ON e.id = m.entidad_federativa_id
JOIN (VALUES
  ('16','053','58000','Centro'),
  ('16','053','58000','Chapultepec'),
  ('09','015','04000','Del Carmen'),
  ('14','039','44100','Centro')
) a(clave_entidad, clave_municipio, codigo, nombre)
  ON a.clave_entidad = e.clave AND a.clave_municipio = m.clave AND a.codigo = cp.codigo
ON CONFLICT DO NOTHING;

COMMIT;
