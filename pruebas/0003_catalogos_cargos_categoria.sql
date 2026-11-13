-- =============================================================
-- Pruebas del ajuste del catálogo de cargos (categoría + idempotencia).
-- Uso:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0003_catalogos_cargos_categoria.sql
-- =============================================================
BEGIN;

DO $$
BEGIN
  -- 1) La columna categoria existe y es nullable
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'catalogos' AND table_name = 'cargo'
      AND column_name = 'categoria'
  ) THEN
    RAISE EXCEPTION 'FALLO: falta la columna categoria en catalogos.cargo';
  END IF;

  -- 2) Sigue habiendo exactamente 29 cargos (sin duplicados)
  IF (SELECT count(*) FROM catalogos.cargo) <> 29 THEN
    RAISE EXCEPTION 'FALLO: se esperaban 29 cargos, hay %', (SELECT count(*) FROM catalogos.cargo);
  END IF;

  -- 3) categoria acepta NULL (pendiente de asignación por RR.HH.)
  INSERT INTO catalogos.cargo (clave, nombre, categoria)
  VALUES ('CARGO_PRUEBA_CAT', 'Cargo de prueba', NULL);
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.cargo WHERE clave = 'CARGO_PRUEBA_CAT' AND categoria IS NULL
  ) THEN
    RAISE EXCEPTION 'FALLO: categoria no acepta NULL';
  END IF;
  DELETE FROM catalogos.cargo WHERE clave = 'CARGO_PRUEBA_CAT';

  -- 4) categoria acepta un código asignado
  UPDATE catalogos.cargo SET categoria = 'CAT-001' WHERE clave = 'RECTOR';
  IF NOT EXISTS (
    SELECT 1 FROM catalogos.cargo WHERE clave = 'RECTOR' AND categoria = 'CAT-001'
  ) THEN
    RAISE EXCEPTION 'FALLO: no se pudo asignar categoria';
  END IF;
  -- Restaurar
  UPDATE catalogos.cargo SET categoria = NULL WHERE clave = 'RECTOR';

  RAISE NOTICE 'Pruebas de categoría de cargos: OK';
END $$;

ROLLBACK;
