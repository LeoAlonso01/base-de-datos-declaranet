-- =============================================================
-- Pruebas de la sección de usuarios
-- Uso:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0001_usuarios.sql
-- Todo corre dentro de una transacción que termina en ROLLBACK:
-- no deja datos de prueba en la base.
-- =============================================================
BEGIN;

DO $$
DECLARE
  v_funcionario_id   bigint;
  v_administrador_id bigint;
BEGIN
  -- 1) Alta válida de funcionario (datos sintéticos)
  INSERT INTO patrimonial.funcionario
    (curp, rfc, nombres, apellido_paterno, apellido_materno, fecha_nacimiento,
     sexo_id, correo, telefono, password_hash)
  VALUES
    ('LOPL900101HDFXXX01', 'LOPL900101AB1', 'LUCIA', 'LOPEZ', 'PEREZ',
     DATE '1990-01-01',
     (SELECT id FROM catalogos.sexo WHERE clave = 'M'),
     'lucia.lopez@example.com', '4431234567', repeat('x', 60))
  RETURNING id INTO v_funcionario_id;

  -- El estado inicial debe ser PENDIENTE_VERIFICACION
  IF NOT EXISTS (
    SELECT 1
    FROM patrimonial.funcionario f
    JOIN catalogos.estado_cuenta e ON e.id = f.estado_cuenta_id
    WHERE f.id = v_funcionario_id AND e.clave = 'PENDIENTE_VERIFICACION'
  ) THEN
    RAISE EXCEPTION 'FALLO: el estado inicial de la cuenta no es PENDIENTE_VERIFICACION';
  END IF;

  -- 2) CURP duplicada debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, rfc, nombres, apellido_paterno, fecha_nacimiento, sexo_id,
       correo, password_hash)
    VALUES
      ('LOPL900101HDFXXX01', 'LOPL900101CD2', 'OTRA', 'PERSONA',
       DATE '1985-05-05', (SELECT id FROM catalogos.sexo WHERE clave = 'H'),
       'otra@example.com', repeat('x', 60));
    RAISE EXCEPTION 'FALLO: se permitió una CURP duplicada';
  EXCEPTION WHEN unique_violation THEN
    NULL; -- comportamiento esperado
  END;

  -- 3) Correo duplicado (sin distinguir mayúsculas) debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, rfc, nombres, apellido_paterno, fecha_nacimiento, sexo_id,
       correo, password_hash)
    VALUES
      ('PEPJ850505MDFRRR02', 'PEPJ850505EF3', 'JUANA', 'PEREZ',
       DATE '1985-05-05', (SELECT id FROM catalogos.sexo WHERE clave = 'M'),
       'LUCIA.LOPEZ@EXAMPLE.COM', repeat('x', 60));
    RAISE EXCEPTION 'FALLO: se permitió un correo duplicado';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- 4) RFC con formato inválido debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, rfc, nombres, apellido_paterno, fecha_nacimiento, sexo_id,
       correo, password_hash)
    VALUES
      ('PEPJ850505MDFRRR02', 'INVALIDO', 'JUANA', 'PEREZ',
       DATE '1985-05-05', (SELECT id FROM catalogos.sexo WHERE clave = 'M'),
       'juana@example.com', repeat('x', 60));
    RAISE EXCEPTION 'FALLO: se permitió un RFC inválido';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 5) Alta válida de administrador
  INSERT INTO seguridad.administrador
    (nombre_usuario, correo, password_hash, nombres, apellido_paterno, rol_id)
  VALUES
    ('admin.prueba', 'admin.prueba@example.com', repeat('x', 60), 'ADMIN',
     'PRUEBA',
     (SELECT id FROM catalogos.rol_administrador WHERE clave = 'SUPERADMINISTRADOR'))
  RETURNING id INTO v_administrador_id;

  -- 6) Token de recuperación válido para el funcionario
  INSERT INTO seguridad.token_usuario
    (tipo_token_id, funcionario_id, token_hash, expira_en)
  VALUES
    ((SELECT id FROM catalogos.tipo_token WHERE clave = 'RECUPERACION_PASSWORD'),
     v_funcionario_id, repeat('t', 64), now() + interval '1 hour');

  -- 7) Token con dos propietarios debe fallar
  BEGIN
    INSERT INTO seguridad.token_usuario
      (tipo_token_id, funcionario_id, administrador_id, token_hash, expira_en)
    VALUES
      ((SELECT id FROM catalogos.tipo_token WHERE clave = 'RECUPERACION_PASSWORD'),
       v_funcionario_id, v_administrador_id, repeat('u', 64), now() + interval '1 hour');
    RAISE EXCEPTION 'FALLO: se permitió un token con dos propietarios';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 8) Token sin propietario debe fallar
  BEGIN
    INSERT INTO seguridad.token_usuario
      (tipo_token_id, token_hash, expira_en)
    VALUES
      ((SELECT id FROM catalogos.tipo_token WHERE clave = 'RECUPERACION_PASSWORD'),
       repeat('v', 64), now() + interval '1 hour');
    RAISE EXCEPTION 'FALLO: se permitió un token sin propietario';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 9) La auditoría registra el alta del funcionario
  IF NOT EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE esquema = 'patrimonial' AND tabla = 'funcionario'
      AND operacion = 'I' AND registro_id = v_funcionario_id
  ) THEN
    RAISE EXCEPTION 'FALLO: no se registró la auditoría del alta de funcionario';
  END IF;

  -- 10) La auditoría no expone material sensible
  IF EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE datos_anteriores ? 'password_hash'
       OR datos_nuevos ? 'password_hash'
  ) THEN
    RAISE EXCEPTION 'FALLO: la auditoría expone password_hash';
  END IF;

  -- 11) Un cambio genera evento 'U' con el diff esperado
  UPDATE patrimonial.funcionario
     SET telefono = '4437654321'
   WHERE id = v_funcionario_id;

  IF NOT EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE esquema = 'patrimonial' AND tabla = 'funcionario'
      AND operacion = 'U' AND registro_id = v_funcionario_id
      AND datos_anteriores ->> 'telefono' = '4431234567'
      AND datos_nuevos ->> 'telefono' = '4437654321'
  ) THEN
    RAISE EXCEPTION 'FALLO: la auditoría del cambio no contiene el diff esperado';
  END IF;

  RAISE NOTICE 'Pruebas de usuarios: OK';
END $$;

ROLLBACK;
