-- =============================================================
-- 0005_refactor_usuarios_datos.sql
-- Refactor de la sección de usuarios:
--   * El usuario de autenticación queda SIMPLE (CURP + contraseña).
--   * Los datos personales y de sesión viven en una tabla 1:1
--     (patrimonial.funcionario_datos / seguridad.administrador_datos).
--   * Las sesiones duran como máximo 35 minutos (CHECK).
--   * Se migran los datos existentes y se eliminan columnas redundantes.
-- =============================================================
BEGIN;

-- 1) Tabla de datos del funcionario (1:1) ----------------------
CREATE TABLE patrimonial.funcionario_datos (
  funcionario_id      bigint      PRIMARY KEY
                                  REFERENCES patrimonial.funcionario (id) ON DELETE CASCADE,
  rfc                 public.dom_rfc      NOT NULL,
  nombre_completo     text                NOT NULL
                                          CHECK (btrim(nombre_completo) <> ''),
  correo              public.dom_correo   NOT NULL,
  correo_secundario   public.dom_correo,
  telefono            public.dom_telefono,
  correo_verificado_en timestamptz,
  -- Datos de sesión (una sesión activa por usuario)
  token_sesion_hash   text,
  sesion_emitida_en   timestamptz,
  sesion_expira_en    timestamptz,
  creado_en           timestamptz         NOT NULL DEFAULT now(),
  actualizado_en      timestamptz         NOT NULL DEFAULT now(),
  CONSTRAINT funcionario_datos_rfc_uk    UNIQUE (rfc),
  CONSTRAINT funcionario_datos_correo_uk UNIQUE (correo),
  -- Una sesión dura a lo sumo 35 minutos.
  CONSTRAINT funcionario_datos_sesion_vigencia
    CHECK (sesion_expira_en IS NULL
           OR (sesion_expira_en - sesion_emitida_en) <= interval '35 minutes'),
  -- Si hay sesión, debe tener hash y fecha de emisión.
  CONSTRAINT funcionario_datos_sesion_completa
    CHECK ((token_sesion_hash IS NULL) = (sesion_emitida_en IS NULL)
           AND (token_sesion_hash IS NULL) = (sesion_expira_en IS NULL))
);

COMMENT ON TABLE patrimonial.funcionario_datos
  IS 'Datos personales, de contacto y de sesión de un funcionario (1:1)';
COMMENT ON COLUMN patrimonial.funcionario_datos.token_sesion_hash
  IS 'Hash del token de sesión. La sesión dura a lo sumo 35 minutos';

-- 2) Tabla de datos del administrador (1:1) --------------------
CREATE TABLE seguridad.administrador_datos (
  administrador_id    bigint      PRIMARY KEY
                                  REFERENCES seguridad.administrador (id) ON DELETE CASCADE,
  nombre_completo     text                NOT NULL
                                          CHECK (btrim(nombre_completo) <> ''),
  correo              public.dom_correo   NOT NULL,
  correo_secundario   public.dom_correo,
  telefono            public.dom_telefono,
  -- Datos de sesión (una sesión activa por administrador)
  token_sesion_hash   text,
  sesion_emitida_en   timestamptz,
  sesion_expira_en    timestamptz,
  creado_en           timestamptz         NOT NULL DEFAULT now(),
  actualizado_en      timestamptz         NOT NULL DEFAULT now(),
  CONSTRAINT administrador_datos_correo_uk UNIQUE (correo),
  CONSTRAINT administrador_datos_sesion_vigencia
    CHECK (sesion_expira_en IS NULL
           OR (sesion_expira_en - sesion_emitida_en) <= interval '35 minutes'),
  CONSTRAINT administrador_datos_sesion_completa
    CHECK ((token_sesion_hash IS NULL) = (sesion_emitida_en IS NULL)
           AND (token_sesion_hash IS NULL) = (sesion_expira_en IS NULL))
);

COMMENT ON TABLE seguridad.administrador_datos
  IS 'Datos personales, de contacto y de sesión de un administrador (1:1)';

-- 3) Migrar los datos existentes ------------------------------
INSERT INTO patrimonial.funcionario_datos
  (funcionario_id, rfc, nombre_completo, correo, telefono, correo_verificado_en,
   creado_en, actualizado_en)
SELECT id,
       rfc,
       btrim(nombres || ' ' || apellido_paterno || COALESCE(' ' || apellido_materno, '')),
       correo,
       telefono,
       correo_verificado_en,
       creado_en,
       actualizado_en
FROM patrimonial.funcionario
ON CONFLICT (funcionario_id) DO NOTHING;

INSERT INTO seguridad.administrador_datos
  (administrador_id, nombre_completo, correo, creado_en, actualizado_en)
SELECT id,
       btrim(nombres || ' ' || apellido_paterno || COALESCE(' ' || apellido_materno, '')),
       correo,
       creado_en,
       actualizado_en
FROM seguridad.administrador
ON CONFLICT (administrador_id) DO NOTHING;

-- 4) Eliminar columnas redundantes de las tablas de autenticación
ALTER TABLE patrimonial.funcionario
  DROP COLUMN IF EXISTS rfc,
  DROP COLUMN IF EXISTS nombres,
  DROP COLUMN IF EXISTS apellido_paterno,
  DROP COLUMN IF EXISTS apellido_materno,
  DROP COLUMN IF EXISTS fecha_nacimiento,
  DROP COLUMN IF EXISTS sexo_id,
  DROP COLUMN IF EXISTS correo,
  DROP COLUMN IF EXISTS telefono,
  DROP COLUMN IF EXISTS correo_verificado_en,
  DROP COLUMN IF EXISTS ultimo_acceso_en;

ALTER TABLE seguridad.administrador
  DROP COLUMN IF EXISTS nombres,
  DROP COLUMN IF EXISTS apellido_paterno,
  DROP COLUMN IF EXISTS apellido_materno,
  DROP COLUMN IF EXISTS correo,
  DROP COLUMN IF EXISTS ultimo_acceso_en;

-- 5) Triggers de marca de tiempo ------------------------------
CREATE TRIGGER funcionario_datos_marca_tiempo
  BEFORE UPDATE ON patrimonial.funcionario_datos
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_marca_tiempo();

CREATE TRIGGER administrador_datos_marca_tiempo
  BEFORE UPDATE ON seguridad.administrador_datos
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_marca_tiempo();

-- 6) Auditoría: ampliar el enmascaramiento y auditar datos ----
-- (CREATE OR REPLACE actualiza la función sin tocar el historial).
CREATE OR REPLACE FUNCTION auditoria.registrar_cambio()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_anterior jsonb;
  v_nuevo    jsonb;
  -- Columna PK de la tabla (se pasa como argumento del trigger;
  -- por defecto 'id').
  v_pk_col   text := COALESCE(TG_ARGV[0], 'id');
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_anterior := to_jsonb(OLD);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_nuevo := to_jsonb(NEW);
  END IF;

  -- Nunca registrar material sensible.
  v_anterior := v_anterior
    - 'password_hash' - 'token_hash' - 'token_sesion_hash';
  v_nuevo := v_nuevo
    - 'password_hash' - 'token_hash' - 'token_sesion_hash';

  INSERT INTO auditoria.registro_evento
    (esquema, tabla, operacion, registro_id, datos_anteriores, datos_nuevos)
  VALUES (
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    left(TG_OP, 1),
    COALESCE((v_nuevo ->> v_pk_col)::bigint, (v_anterior ->> v_pk_col)::bigint),
    v_anterior,
    v_nuevo
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER funcionario_datos_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON patrimonial.funcionario_datos
  FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('funcionario_id');

CREATE TRIGGER administrador_datos_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON seguridad.administrador_datos
  FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('administrador_id');

COMMIT;
