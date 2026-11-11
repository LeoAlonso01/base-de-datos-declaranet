-- =============================================================
-- 0001_base.sql — Base del esquema
-- Extensiones, esquemas por módulo, dominios de datos y
-- funciones utilitarias compartidas.
-- =============================================================
BEGIN;

-- Extensiones ---------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext;   -- correos sin distinguir mayúsculas
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- hashing y cifrado

-- Esquemas por módulo ------------------------------------------
CREATE SCHEMA IF NOT EXISTS patrimonial;
CREATE SCHEMA IF NOT EXISTS catalogos;
CREATE SCHEMA IF NOT EXISTS seguridad;
CREATE SCHEMA IF NOT EXISTS auditoria;

COMMENT ON SCHEMA patrimonial IS 'Núcleo: funcionarios, nombramientos, declaraciones y anexos';
COMMENT ON SCHEMA catalogos   IS 'Catálogos y listas de valores cerradas';
COMMENT ON SCHEMA seguridad   IS 'Cuentas administrativas, roles y tokens';
COMMENT ON SCHEMA auditoria   IS 'Bitácora de cambios y accesos';

-- Dominios de datos compartidos --------------------------------
-- CURP: 4 letras + fecha AAMMDD + sexo + entidad + consonantes + homoclave.
-- La validación de la entidad federativa es laxa (2 letras) a propósito.
CREATE DOMAIN public.dom_curp AS char(18)
  CONSTRAINT curp_formato CHECK (
    VALUE ~ '^[A-Z][AEIOUX][A-Z]{2}[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[0-9A-Z][0-9]$'
  );

-- RFC de persona física (13 posiciones).
CREATE DOMAIN public.dom_rfc AS varchar(13)
  CONSTRAINT rfc_formato CHECK (
    VALUE ~ '^[A-ZÑ&]{4}[0-9]{6}[A-Z0-9]{3}$'
  );

-- Correo electrónico (citext: comparación sin distinguir mayúsculas).
CREATE DOMAIN public.dom_correo AS citext
  CONSTRAINT correo_formato CHECK (
    VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  );

-- Teléfono nacional a 10 dígitos.
CREATE DOMAIN public.dom_telefono AS varchar(10)
  CONSTRAINT telefono_formato CHECK (VALUE ~ '^[0-9]{10}$');

-- Nombres y apellidos: texto no vacío.
CREATE DOMAIN public.dom_nombre AS varchar(100)
  CONSTRAINT nombre_no_vacio CHECK (btrim(VALUE) <> '');

-- Utilidades ----------------------------------------------------

-- Trigger BEFORE UPDATE: mantiene actualizado_en al día.
CREATE OR REPLACE FUNCTION public.actualizar_marca_tiempo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en := now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.actualizar_marca_tiempo()
  IS 'Trigger BEFORE UPDATE que actualiza la columna actualizado_en';

COMMIT;
