-- =============================================================
-- 0007_catalogos_cargos_categoria.sql
-- Ajuste del catálogo de cargos conforme al requerimiento:
--   * Agrega la columna `categoria` (código asignado por la
--     Dirección de Personal), útil para la plataforma nacional
--     de transparencia y las versiones públicas.
--   * Sincroniza los 29 cargos de forma idempotente (solo
--     agrega/actualiza los del listado, sin duplicar ni borrar
--     los existentes).
-- Nota de esquema: en este proyecto los catálogos viven en el
-- esquema `catalogos` (catalogos.cargo), equivalente al
-- `public.cargos` referido en el requerimiento.
-- =============================================================
BEGIN;

-- 1) Espacio para el código de categoría (asignado por RR.HH.)
ALTER TABLE catalogos.cargo
  ADD COLUMN IF NOT EXISTS categoria text;

COMMENT ON COLUMN catalogos.cargo.categoria
  IS 'Código de categoría asignado por la Dirección de Personal; '
     'útil para la plataforma nacional de transparencia y versiones públicas';

-- 2) Sincronización idempotente de los 29 cargos.
--    INSERT ... ON CONFLICT (clave) garantiza "agregar solo los faltantes"
--    y evita duplicados por comparación normalizada (clave).
INSERT INTO catalogos.cargo (clave, nombre, orden, activo) VALUES
  ('ABOGADO_GENERAL',                'Abogado General',                                    1,  true),
  ('ANALISTA_PROGRAMADOR_H',         'Analista Programador “H”',                           2,  true),
  ('ASESOR_JURIDICO',                'Asesor Jurídico',                                    3,  true),
  ('BIBLIOTECARIO_TITULAR',          'Bibliotecario Titular',                              4,  true),
  ('CONTRALOR',                      'Contralor',                                          5,  true),
  ('COORDINADOR_DIVISION',           'Coordinador de División',                            6,  true),
  ('COORDINADOR_INVESTIGACION_CIENTIFICA', 'Coordinador de Investigación Científica',       7,  true),
  ('COORDINADOR_SERVICIO_SOCIAL',    'Coordinador de Servicio Social',                     8,  true),
  ('DIRECTOR_ADMINISTRATIVO',        'Director Administrativo',                            9,  true),
  ('DIRECTOR_ESCUELA_INSTITUTO',     'Director de Escuela o Instituto',                    10, true),
  ('JEFE_BIBLIOTECAS',              'Jefe de Bibliotecas',                               11, true),
  ('JEFE_DEPARTAMENTO',              'Jefe de Departamento',                              12, true),
  ('JEFE_DEPTO_ADMIN_A',             'Jefe de Departamento Administrativo “A”',            13, true),
  ('JEFE_DEPTO_ADMIN_B',             'Jefe de Departamento Administrativo “B”',            14, true),
  ('JEFE_DEPTO_ADMIN_C',             'Jefe de Departamento Administrativo “C”',            15, true),
  ('JEFE_DEPTO_APOYO_DOCENCIA',      'Jefe de Departamento de Apoyo a la Docencia',       16, true),
  ('RECTOR',                         'Rector',                                            17, true),
  ('SECRETARIO_ACADEMICO',           'Secretario Académico',                              18, true),
  ('SECRETARIO_ADMINISTRATIVO',      'Secretario Administrativo',                          19, true),
  ('SECRETARIO_AUXILIAR',            'Secretario Auxiliar',                               20, true),
  ('SECRETARIO_DIFUSION_CULTURAL',   'Secretario de Difusión Cultural',                   21, true),
  ('SECRETARIO_ESCUELA',             'Secretario de Escuela',                             22, true),
  ('SECRETARIO_GENERAL',             'Secretario General',                                23, true),
  ('SECRETARIO_PARTICULAR',          'Secretario Particular',                             24, true),
  ('SECRETARIO_PRIVADO',             'Secretario Privado',                                25, true),
  ('SUBDIRECTOR_ADMINISTRATIVO',     'Subdirector Administrativo',                         26, true),
  ('SUBDIRECTOR_ESCUELA_INSTITUTO',  'Subdirector de Escuela o Instituto',                27, true),
  ('TESORERO',                       'Tesorero',                                          28, true),
  ('VICE_REGENTE',                   'Vice-Regente',                                      29, true)
ON CONFLICT (clave) DO UPDATE SET
  nombre  = EXCLUDED.nombre,
  orden   = EXCLUDED.orden,
  activo  = EXCLUDED.activo;

COMMIT;
