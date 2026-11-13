-- =============================================================
-- Pruebas de los catálogos de Datos Generales.
-- Uso:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0004_catalogos_datos_generales.sql
-- =============================================================
BEGIN;

DO $$
BEGIN
  -- 1) Exactamente los 6 estados civiles solicitados
  IF (SELECT count(*) FROM catalogos.estado_civil) <> 6 THEN
    RAISE EXCEPTION 'FALLO: se esperaban 6 estados civiles, hay %', (SELECT count(*) FROM catalogos.estado_civil);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM catalogos.estado_civil WHERE clave = 'SOLTERO') THEN
    RAISE EXCEPTION 'FALLO: falta SOLTERO';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM catalogos.estado_civil WHERE clave = 'SOCIEDAD_CONVIVENCIA') THEN
    RAISE EXCEPTION 'FALLO: falta SOCIEDAD_CONVIVENCIA';
  END IF;

  -- 2) Países: catálogo amplio (ISO 3166-1, ~245)
  IF (SELECT count(*) FROM catalogos.pais) < 200 THEN
    RAISE EXCEPTION 'FALLO: catálogo de países incompleto (%)', (SELECT count(*) FROM catalogos.pais);
  END IF;

  -- 3) México presente con sus códigos
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.pais
    WHERE iso2 = 'MX' AND iso3 = 'MEX' AND nombre = 'México'
  ) THEN
    RAISE EXCEPTION 'FALLO: México no está correctamente registrado';
  END IF;

  -- 4) Una nacionalidad por país (misma cantidad)
  IF (SELECT count(*) FROM catalogos.nacionalidad) <> (SELECT count(*) FROM catalogos.pais) THEN
    RAISE EXCEPTION 'FALLO: nacionalidades (%) != países (%)',
      (SELECT count(*) FROM catalogos.nacionalidad), (SELECT count(*) FROM catalogos.pais);
  END IF;

  -- 5) Nacionalidad de México = Mexicana
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.nacionalidad n JOIN catalogos.pais p ON p.id = n.pais_id
    WHERE p.iso2 = 'MX' AND n.nombre = 'Mexicana'
  ) THEN
    RAISE EXCEPTION 'FALLO: nacionalidad de México incorrecta';
  END IF;

  -- 6) Prefijos: México +52, Estados Unidos +1, España +34
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.prefijo_telefonico t JOIN catalogos.pais p ON p.id = t.pais_id
    WHERE p.iso2 = 'MX' AND t.prefijo = '+52'
  ) THEN
    RAISE EXCEPTION 'FALLO: prefijo de México incorrecto';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.prefijo_telefonico t JOIN catalogos.pais p ON p.id = t.pais_id
    WHERE p.iso2 = 'US' AND t.prefijo = '+1'
  ) THEN
    RAISE EXCEPTION 'FALLO: prefijo de Estados Unidos incorrecto';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.prefijo_telefonico t JOIN catalogos.pais p ON p.id = t.pais_id
    WHERE p.iso2 = 'ES' AND t.prefijo = '+34'
  ) THEN
    RAISE EXCEPTION 'FALLO: prefijo de España incorrecto';
  END IF;

  -- 7) Varios países comparten prefijo +1
  IF (SELECT count(*) FROM catalogos.prefijo_telefonico WHERE prefijo = '+1') < 5 THEN
    RAISE EXCEPTION 'FALLO: se esperaban varios países con prefijo +1';
  END IF;

  -- 8) funcionario_datos tiene las nuevas columnas (nullable)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'patrimonial' AND table_name = 'funcionario_datos'
      AND column_name = 'estado_civil_id'
  ) THEN
    RAISE EXCEPTION 'FALLO: falta estado_civil_id en funcionario_datos';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'patrimonial' AND table_name = 'funcionario_datos'
      AND column_name = 'pais_nacimiento_id'
  ) THEN
    RAISE EXCEPTION 'FALLO: falta pais_nacimiento_id en funcionario_datos';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'patrimonial' AND table_name = 'funcionario_datos'
      AND column_name = 'nacionalidad_id'
  ) THEN
    RAISE EXCEPTION 'FALLO: falta nacionalidad_id en funcionario_datos';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'patrimonial' AND table_name = 'funcionario_datos'
      AND column_name = 'lada_celular_id'
  ) THEN
    RAISE EXCEPTION 'FALLO: falta lada_celular_id en funcionario_datos';
  END IF;

  RAISE NOTICE 'Pruebas de catálogos de Datos Generales: OK';
END $$;

ROLLBACK;
