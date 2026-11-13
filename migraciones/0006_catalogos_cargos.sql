-- =============================================================
-- 0006_catalogos_cargos.sql — Catálogo de cargos de la UMSNH
-- Puestos / cargos que puede ocupar un funcionario. Se modelan
-- como catálogo (tabla editable) porque la institución los
-- administra y pueden cambiar con el tiempo.
-- =============================================================
BEGIN;

CREATE TABLE catalogos.cargo (
  id      smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave   text     NOT NULL UNIQUE,
  nombre  text     NOT NULL,
  orden   smallint NOT NULL DEFAULT 0,
  activo  boolean  NOT NULL DEFAULT true,
  CONSTRAINT cargo_clave_formato
    CHECK (clave ~ '^[A-Z0-9_]+$'),
  CONSTRAINT cargo_nombre_no_vacio
    CHECK (btrim(nombre) <> '')
);

COMMENT ON TABLE catalogos.cargo
  IS 'Cargos / puestos que puede ocupar un funcionario de la UMSNH';

-- Cargos de la Universidad Michoacana de San Nicolás de Hidalgo.
INSERT INTO catalogos.cargo (id, clave, nombre, orden) OVERRIDING SYSTEM VALUE VALUES
  (1,  'ABOGADO_GENERAL',                'Abogado General',                                    1),
  (2,  'ANALISTA_PROGRAMADOR_H',         'Analista Programador “H”',                           2),
  (3,  'ASESOR_JURIDICO',                'Asesor Jurídico',                                    3),
  (4,  'BIBLIOTECARIO_TITULAR',          'Bibliotecario Titular',                              4),
  (5,  'CONTRALOR',                      'Contralor',                                          5),
  (6,  'COORDINADOR_DIVISION',           'Coordinador de División',                            6),
  (7,  'COORDINADOR_INVESTIGACION_CIENTIFICA', 'Coordinador de Investigación Científica',       7),
  (8,  'COORDINADOR_SERVICIO_SOCIAL',    'Coordinador de Servicio Social',                     8),
  (9,  'DIRECTOR_ADMINISTRATIVO',        'Director Administrativo',                            9),
  (10, 'DIRECTOR_ESCUELA_INSTITUTO',     'Director de Escuela o Instituto',                    10),
  (11, 'JEFE_BIBLIOTECAS',              'Jefe de Bibliotecas',                               11),
  (12, 'JEFE_DEPARTAMENTO',              'Jefe de Departamento',                              12),
  (13, 'JEFE_DEPTO_ADMIN_A',             'Jefe de Departamento Administrativo “A”',            13),
  (14, 'JEFE_DEPTO_ADMIN_B',             'Jefe de Departamento Administrativo “B”',            14),
  (15, 'JEFE_DEPTO_ADMIN_C',             'Jefe de Departamento Administrativo “C”',            15),
  (16, 'JEFE_DEPTO_APOYO_DOCENCIA',      'Jefe de Departamento de Apoyo a la Docencia',       16),
  (17, 'RECTOR',                         'Rector',                                            17),
  (18, 'SECRETARIO_ACADEMICO',           'Secretario Académico',                              18),
  (19, 'SECRETARIO_ADMINISTRATIVO',      'Secretario Administrativo',                          19),
  (20, 'SECRETARIO_AUXILIAR',            'Secretario Auxiliar',                               20),
  (21, 'SECRETARIO_DIFUSION_CULTURAL',   'Secretario de Difusión Cultural',                   21),
  (22, 'SECRETARIO_ESCUELA',             'Secretario de Escuela',                             22),
  (23, 'SECRETARIO_GENERAL',             'Secretario General',                                23),
  (24, 'SECRETARIO_PARTICULAR',          'Secretario Particular',                             24),
  (25, 'SECRETARIO_PRIVADO',             'Secretario Privado',                                25),
  (26, 'SUBDIRECTOR_ADMINISTRATIVO',     'Subdirector Administrativo',                         26),
  (27, 'SUBDIRECTOR_ESCUELA_INSTITUTO',  'Subdirector de Escuela o Instituto',                27),
  (28, 'TESORERO',                       'Tesorero',                                          28),
  (29, 'VICE_REGENTE',                   'Vice-Regente',                                      29);

SELECT setval(pg_get_serial_sequence('catalogos.cargo', 'id'), 29, true);

COMMIT;
