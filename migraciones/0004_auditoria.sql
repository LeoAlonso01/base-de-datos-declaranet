-- =============================================================
-- 0004_auditoria.sql — Auditoría de cambios
-- Bitácora genérica alimentada por triggers AFTER en las tablas
-- de dominio. Nunca registra material sensible (hashes).
-- =============================================================
BEGIN;

CREATE TABLE auditoria.registro_evento (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  esquema           text        NOT NULL,
  tabla             text        NOT NULL,
  operacion         char(1)     NOT NULL,
  registro_id       bigint,
  datos_anteriores  jsonb,
  datos_nuevos      jsonb,
  usuario_bd        text        NOT NULL DEFAULT current_user,
  ocurrido_en       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT auditoria_operacion_valida CHECK (operacion IN ('I', 'U', 'D'))
);

CREATE INDEX auditoria_tabla_idx
  ON auditoria.registro_evento (esquema, tabla, ocurrido_en DESC);

CREATE INDEX auditoria_registro_idx
  ON auditoria.registro_evento (registro_id)
  WHERE registro_id IS NOT NULL;

COMMENT ON TABLE auditoria.registro_evento
  IS 'Bitácora de altas, cambios y bajas de las tablas de dominio';

-- Función genérica de auditoría --------------------------------
CREATE OR REPLACE FUNCTION auditoria.registrar_cambio()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_anterior jsonb;
  v_nuevo    jsonb;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_anterior := to_jsonb(OLD);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_nuevo := to_jsonb(NEW);
  END IF;

  -- Nunca registrar material sensible.
  v_anterior := v_anterior - 'password_hash' - 'token_hash';
  v_nuevo    := v_nuevo    - 'password_hash' - 'token_hash';

  INSERT INTO auditoria.registro_evento
    (esquema, tabla, operacion, registro_id, datos_anteriores, datos_nuevos)
  VALUES (
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    left(TG_OP, 1),
    COALESCE((v_nuevo ->> 'id')::bigint, (v_anterior ->> 'id')::bigint),
    v_anterior,
    v_nuevo
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION auditoria.registrar_cambio()
  IS 'Trigger AFTER INSERT/UPDATE/DELETE: registra el cambio en auditoria.registro_evento sin material sensible';

-- Auditoría de la sección de usuarios --------------------------
CREATE TRIGGER funcionario_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON patrimonial.funcionario
  FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio();

CREATE TRIGGER administrador_auditoria
  AFTER INSERT OR UPDATE OR DELETE ON seguridad.administrador
  FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio();

COMMIT;
