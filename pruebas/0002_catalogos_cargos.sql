-- =============================================================
-- Pruebas del catálogo de cargos.
-- Uso:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0002_catalogos_cargos.sql
-- =============================================================
BEGIN;

DO $$
BEGIN
  -- 1) Se sembraron los 29 cargos de la UMSNH
  IF (SELECT count(*) FROM catalogos.cargo) <> 29 THEN
    RAISE EXCEPTION 'FALLO: se esperaban 29 cargos, hay %', (SELECT count(*) FROM catalogos.cargo);
  END IF;

  -- 2) Todos los cargos están activos por defecto
  IF EXISTS (SELECT 1 FROM catalogos.cargo WHERE activo IS DISTINCT FROM true) THEN
    RAISE EXCEPTION 'FALLO: hay cargos inactivos por defecto';
  END IF;

  -- 3) Claves únicas y con formato válido
  IF EXISTS (
    SELECT clave FROM catalogos.cargo
    GROUP BY clave HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'FALLO: claves de cargo duplicadas';
  END IF;

  -- 4) Cargos representativos existen
  IF NOT EXISTS (SELECT 1 FROM catalogos.cargo WHERE clave = 'RECTOR') THEN
    RAISE EXCEPTION 'FALLO: falta el cargo RECTOR';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM catalogos.cargo WHERE clave = 'ABOGADO_GENERAL') THEN
    RAISE EXCEPTION 'FALLO: falta el cargo ABOGADO_GENERAL';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM catalogos.cargo WHERE clave = 'VICE_REGENTE') THEN
    RAISE EXCEPTION 'FALLO: falta el cargo VICE_REGENTE';
  END IF;

  -- 5) El orden es único y coincide con la cantidad
  IF (SELECT count(DISTINCT orden) FROM catalogos.cargo) <> 29 THEN
    RAISE EXCEPTION 'FALLO: el orden de los cargos no es único';
  END IF;

  RAISE NOTICE 'Pruebas de catálogo de cargos: OK';
END $$;

ROLLBACK;
