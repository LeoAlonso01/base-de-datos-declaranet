-- =============================================================
-- 0002_catalogos.sql — Catálogos iniciales
-- Listas de valores cerradas con IDs fijos para que las
-- referencias (defaults, pruebas y datos) sean deterministas.
-- =============================================================
BEGIN;

-- Tipos de trámite de declaración que puede crear un funcionario.
-- Los tres primeros provienen de la LGRA; los dos últimos son
-- trámites internos de la plataforma UMSNH.
CREATE TABLE catalogos.tipo_declaracion (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text      NOT NULL UNIQUE,
  descripcion text      NOT NULL,
  activo      boolean   NOT NULL DEFAULT true
);

INSERT INTO catalogos.tipo_declaracion (id, clave, descripcion) OVERRIDING SYSTEM VALUE VALUES
  (1, 'INICIO',             'Declaración inicial al tomar posesión del cargo'),
  (2, 'MODIFICACION',       'Declaración anual de modificación patrimonial'),
  (3, 'CONCLUSION',         'Declaración de conclusión al separarse del cargo'),
  (4, 'NOTA_ACLARATORIA',   'Nota aclaratoria sobre una declaración presentada'),
  (5, 'CAMBIO_DEPENDENCIA', 'Declaración por cambio de adscripción o dependencia');

SELECT setval(pg_get_serial_sequence('catalogos.tipo_declaracion', 'id'), 5, true);

COMMENT ON TABLE catalogos.tipo_declaracion
  IS 'Tipos de trámite de declaración disponibles para los funcionarios';

-- Estados del ciclo de vida de una cuenta de usuario.
CREATE TABLE catalogos.estado_cuenta (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text      NOT NULL UNIQUE,
  descripcion text      NOT NULL,
  activo      boolean   NOT NULL DEFAULT true
);

INSERT INTO catalogos.estado_cuenta (id, clave, descripcion) OVERRIDING SYSTEM VALUE VALUES
  (1, 'PENDIENTE_VERIFICACION', 'Cuenta creada, pendiente de verificar el correo'),
  (2, 'ACTIVA',                 'Cuenta activa y operativa'),
  (3, 'BLOQUEADA',              'Cuenta bloqueada temporalmente'),
  (4, 'BAJA',                   'Cuenta dada de baja');

SELECT setval(pg_get_serial_sequence('catalogos.estado_cuenta', 'id'), 4, true);

COMMENT ON TABLE catalogos.estado_cuenta
  IS 'Estados posibles de una cuenta de usuario';

-- Helper legible para defaults: id de un estado por su clave.
CREATE OR REPLACE FUNCTION catalogos.id_estado_cuenta(p_clave text)
RETURNS smallint
LANGUAGE sql
STABLE
AS $$
  SELECT id FROM catalogos.estado_cuenta WHERE clave = p_clave;
$$;

COMMENT ON FUNCTION catalogos.id_estado_cuenta(text)
  IS 'Devuelve el id de catalogos.estado_cuenta para una clave dada';

-- Roles de los usuarios administradores.
CREATE TABLE catalogos.rol_administrador (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text      NOT NULL UNIQUE,
  descripcion text      NOT NULL,
  activo      boolean   NOT NULL DEFAULT true
);

INSERT INTO catalogos.rol_administrador (id, clave, descripcion) OVERRIDING SYSTEM VALUE VALUES
  (1, 'SUPERADMINISTRADOR', 'Control total de la plataforma y de las cuentas administrativas'),
  (2, 'ADMINISTRADOR',      'Gestión de funcionarios y sus datos personales'),
  (3, 'REVISOR',            'Revisión y validación de declaraciones'),
  (4, 'CONSULTA',           'Acceso de solo lectura y generación de reportes');

SELECT setval(pg_get_serial_sequence('catalogos.rol_administrador', 'id'), 4, true);

COMMENT ON TABLE catalogos.rol_administrador
  IS 'Roles disponibles para los usuarios administradores';

-- Sexo (codificación usada por CURP: H = hombre, M = mujer).
CREATE TABLE catalogos.sexo (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text      NOT NULL UNIQUE,
  descripcion text      NOT NULL,
  activo      boolean   NOT NULL DEFAULT true
);

INSERT INTO catalogos.sexo (id, clave, descripcion) OVERRIDING SYSTEM VALUE VALUES
  (1, 'H', 'Hombre'),
  (2, 'M', 'Mujer');

SELECT setval(pg_get_serial_sequence('catalogos.sexo', 'id'), 2, true);

COMMENT ON TABLE catalogos.sexo IS 'Sexo de la persona (codificación H/M de la CURP)';

-- Tipos de token de un solo uso.
CREATE TABLE catalogos.tipo_token (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text      NOT NULL UNIQUE,
  descripcion text      NOT NULL,
  activo      boolean   NOT NULL DEFAULT true
);

INSERT INTO catalogos.tipo_token (id, clave, descripcion) OVERRIDING SYSTEM VALUE VALUES
  (1, 'RECUPERACION_PASSWORD', 'Token para restablecer la contraseña'),
  (2, 'VERIFICACION_CORREO',   'Token para verificar el correo al crear la cuenta');

SELECT setval(pg_get_serial_sequence('catalogos.tipo_token', 'id'), 2, true);

COMMENT ON TABLE catalogos.tipo_token IS 'Tipos de token de un solo uso';

COMMIT;
