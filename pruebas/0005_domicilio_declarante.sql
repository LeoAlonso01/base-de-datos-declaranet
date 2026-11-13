-- =============================================================
-- Pruebas de la sección Domicilio del declarante.
-- Uso:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0005_domicilio_declarante.sql
-- =============================================================
BEGIN;

DO $$
DECLARE
  v_entidad_id smallint;
  v_municipio_id bigint;
  v_cp_id bigint;
  v_asentamiento_id bigint;
  v_pais_id smallint;
  v_domicilio_id bigint;
BEGIN
  -- 1) 32 entidades federativas
  IF (SELECT count(*) FROM catalogos.entidad_federativa) <> 32 THEN
    RAISE EXCEPTION 'FALLO: se esperaban 32 entidades, hay %', (SELECT count(*) FROM catalogos.entidad_federativa);
  END IF;

  -- 2) Michoacán presente
  SELECT id INTO v_entidad_id FROM catalogos.entidad_federativa WHERE clave = '16';
  IF v_entidad_id IS NULL THEN
    RAISE EXCEPTION 'FALLO: falta Michoacán';
  END IF;

  -- 3) Tipos de asentamiento sembrados
  IF (SELECT count(*) FROM catalogos.tipo_asentamiento) < 5 THEN
    RAISE EXCEPTION 'FALLO: tipos de asentamiento incompletos';
  END IF;

  -- Datos temporales para probar el domicilio nacional (se revierten al final)
  INSERT INTO catalogos.municipio (entidad_federativa_id, clave, nombre)
  VALUES (v_entidad_id, '053', 'Morelia') RETURNING id INTO v_municipio_id;

  INSERT INTO catalogos.codigo_postal (municipio_id, codigo)
  VALUES (v_municipio_id, '58000') RETURNING id INTO v_cp_id;

  INSERT INTO catalogos.asentamiento (codigo_postal_id, nombre)
  VALUES (v_cp_id, 'Centro') RETURNING id INTO v_asentamiento_id;

  -- 4) Domicilio en México válido
  INSERT INTO patrimonial.domicilio
    (tipo_domicilio, calle, numero_exterior, numero_interior,
     entidad_federativa_id, municipio_id, codigo_postal, colonia_id,
     aclaraciones_observaciones)
  VALUES
    ('MEXICO', 'Av. Madero', '123', '4B', v_entidad_id, v_municipio_id,
     '58000', v_asentamiento_id, 'Domicilio de prueba')
  RETURNING id INTO v_domicilio_id;

  -- 5) codigo_postal debe ser de 5 dígitos
  BEGIN
    INSERT INTO patrimonial.domicilio
      (tipo_domicilio, calle, numero_exterior, entidad_federativa_id,
       municipio_id, codigo_postal, colonia_id)
    VALUES
      ('MEXICO', 'Calle X', '1', v_entidad_id, v_municipio_id, '123', v_asentamiento_id);
    RAISE EXCEPTION 'FALLO: se permitió un código postal inválido';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 6) Domicilio en México sin municipio debe fallar
  BEGIN
    INSERT INTO patrimonial.domicilio
      (tipo_domicilio, calle, numero_exterior, entidad_federativa_id,
       codigo_postal, colonia_id)
    VALUES
      ('MEXICO', 'Calle X', '1', v_entidad_id, '58000', v_asentamiento_id);
    RAISE EXCEPTION 'FALLO: se permitió domicilio nacional sin municipio';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 7) Domicilio en el extranjero válido
  SELECT id INTO v_pais_id FROM catalogos.pais WHERE iso2 = 'ES';
  INSERT INTO patrimonial.domicilio
    (tipo_domicilio, calle, numero_exterior, numero_interior,
     ciudad, estado_region, codigo_postal_extranjero, pais_id,
     aclaraciones_observaciones)
  VALUES
    ('EXTRANJERO', 'Calle Mayor', '10', NULL, 'Madrid', 'Comunidad de Madrid',
     '28013', v_pais_id, NULL);

  -- 8) Extranjero con campos de México debe fallar (exclusividad)
  BEGIN
    INSERT INTO patrimonial.domicilio
      (tipo_domicilio, calle, numero_exterior, entidad_federativa_id,
       municipio_id, codigo_postal, colonia_id, pais_id, ciudad)
    VALUES
      ('EXTRANJERO', 'Calle X', '1', v_entidad_id, v_municipio_id, '58000',
       v_asentamiento_id, v_pais_id, 'Madrid');
    RAISE EXCEPTION 'FALLO: se permitió mezclar campos nacionales y extranjeros';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 9) Extranjero sin país debe fallar
  BEGIN
    INSERT INTO patrimonial.domicilio
      (tipo_domicilio, calle, numero_exterior, ciudad)
    VALUES
      ('EXTRANJERO', 'Calle X', '1', 'Madrid');
    RAISE EXCEPTION 'FALLO: se permitió domicilio extranjero sin país';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 10) aclaraciones_observaciones es opcional (NULL permitido)
  IF NOT EXISTS (
    SELECT 1 FROM patrimonial.domicilio WHERE aclaraciones_observaciones IS NULL
  ) THEN
    RAISE EXCEPTION 'FALLO: aclaraciones_observaciones no admite NULL';
  END IF;

  -- 11) numero_interior es opcional
  IF NOT EXISTS (
    SELECT 1 FROM patrimonial.domicilio WHERE numero_interior IS NULL
  ) THEN
    RAISE EXCEPTION 'FALLO: numero_interior no admite NULL';
  END IF;

  -- 12) Numeros exterior/interior aceptan texto (S/N)
  INSERT INTO patrimonial.domicilio
    (tipo_domicilio, calle, numero_exterior, numero_interior,
     entidad_federativa_id, municipio_id, codigo_postal, colonia_id)
  VALUES
    ('MEXICO', 'Calle S/N', 'S/N', 'A-1', v_entidad_id, v_municipio_id,
     '58000', v_asentamiento_id);

  RAISE NOTICE 'Pruebas de domicilio del declarante: OK';
END $$;

ROLLBACK;
