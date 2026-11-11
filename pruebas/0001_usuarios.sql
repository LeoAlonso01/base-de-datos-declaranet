-- =============================================================
-- Pruebas de la sección de usuarios (esquema refinado).
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
  -- 1) Alta mínima de funcionario (solo CURP + contraseña)
  INSERT INTO patrimonial.funcionario (curp, password_hash)
  VALUES ('LOPL900101HDFXXX01', repeat('x', 60))
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
    INSERT INTO patrimonial.funcionario (curp, password_hash)
    VALUES ('LOPL900101HDFXXX01', repeat('x', 60));
    RAISE EXCEPTION 'FALLO: se permitió una CURP duplicada';
  EXCEPTION WHEN unique_violation THEN
    NULL; -- comportamiento esperado
  END;

  -- 3) Alta de los datos personales (1:1) del funcionario
  INSERT INTO patrimonial.funcionario_datos
    (funcionario_id, rfc, nombre_completo, correo, correo_secundario, telefono)
  VALUES
    (v_funcionario_id, 'LOPL900101AB1', 'LUCIA LOPEZ PEREZ',
     'lucia.lopez@example.com', 'lucia.secundario@example.com', '4431234567');

  -- 4) RFC duplicado en datos debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, password_hash) VALUES ('PEPJ850505MDFRRR02', repeat('x', 60));
    INSERT INTO patrimonial.funcionario_datos
      (funcionario_id, rfc, nombre_completo, correo)
    VALUES
      ((SELECT id FROM patrimonial.funcionario WHERE curp = 'PEPJ850505MDFRRR02'),
       'LOPL900101AB1', 'OTRA PERSONA', 'otra@example.com');
    RAISE EXCEPTION 'FALLO: se permitió un RFC duplicado';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- 5) Correo duplicado (sin distinguir mayúsculas) en datos debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, password_hash) VALUES ('PEPJ850505MDFRRR02', repeat('x', 60));
    INSERT INTO patrimonial.funcionario_datos
      (funcionario_id, rfc, nombre_completo, correo)
    VALUES
      ((SELECT id FROM patrimonial.funcionario WHERE curp = 'PEPJ850505MDFRRR02'),
       'PEPJ850505EF3', 'JUANA PEREZ', 'LUCIA.LOPEZ@EXAMPLE.COM');
    RAISE EXCEPTION 'FALLO: se permitió un correo duplicado';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- 6) RFC con formato inválido debe fallar
  BEGIN
    INSERT INTO patrimonial.funcionario
      (curp, password_hash) VALUES ('PEPJ850505MDFRRR03', repeat('x', 60));
    INSERT INTO patrimonial.funcionario_datos
      (funcionario_id, rfc, nombre_completo, correo)
    VALUES
      ((SELECT id FROM patrimonial.funcionario WHERE curp = 'PEPJ850505MDFRRR03'),
       'INVALIDO', 'JUANA PEREZ', 'juana@example.com');
    RAISE EXCEPTION 'FALLO: se permitió un RFC inválido';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 7) Alta válida de administrador
  INSERT INTO seguridad.administrador
    (nombre_usuario, password_hash, rol_id)
  VALUES
    ('admin.prueba', repeat('x', 60),
     (SELECT id FROM catalogos.rol_administrador WHERE clave = 'SUPERADMINISTRADOR'))
  RETURNING id INTO v_administrador_id;

  INSERT INTO seguridad.administrador_datos
    (administrador_id, nombre_completo, correo, correo_secundario)
  VALUES
    (v_administrador_id, 'ADMIN PRUEBA', 'admin.prueba@example.com',
     'admin.secundario@example.com');

  -- 8) Token de recuperación válido para el funcionario
  INSERT INTO seguridad.token_usuario
    (tipo_token_id, funcionario_id, token_hash, expira_en)
  VALUES
    ((SELECT id FROM catalogos.tipo_token WHERE clave = 'RECUPERACION_PASSWORD'),
     v_funcionario_id, repeat('t', 64), now() + interval '1 hour');

  -- 9) Token con dos propietarios debe fallar
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

  -- 10) Token sin propietario debe fallar
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

  -- 11) Sesión de 35 minutos o menos es válida
  UPDATE patrimonial.funcionario_datos
     SET token_sesion_hash = repeat('s', 64),
         sesion_emitida_en = now(),
         sesion_expira_en = now() + interval '35 minutes'
   WHERE funcionario_id = v_funcionario_id;

  -- 12) Sesión de más de 35 minutos debe fallar
  BEGIN
    UPDATE patrimonial.funcionario_datos
       SET sesion_expira_en = sesion_emitida_en + interval '40 minutes'
     WHERE funcionario_id = v_funcionario_id;
    RAISE EXCEPTION 'FALLO: se permitió una sesión mayor a 35 minutos';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 13) Sesión parcial (solo hash sin fechas) debe fallar
  BEGIN
    UPDATE patrimonial.funcionario_datos
       SET sesion_emitida_en = NULL, sesion_expira_en = NULL,
           token_sesion_hash = repeat('z', 64)
     WHERE funcionario_id = v_funcionario_id;
    RAISE EXCEPTION 'FALLO: se permitió una sesión parcial';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- 14) La auditoría registra el alta del funcionario
  IF NOT EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE esquema = 'patrimonial' AND tabla = 'funcionario'
      AND operacion = 'I' AND registro_id = v_funcionario_id
  ) THEN
    RAISE EXCEPTION 'FALLO: no se registró la auditoría del alta de funcionario';
  END IF;

  -- 15) La auditoría no expone material sensible
  IF EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE datos_anteriores ? 'password_hash'
       OR datos_nuevos ? 'password_hash'
       OR datos_anteriores ? 'token_sesion_hash'
       OR datos_nuevos ? 'token_sesion_hash'
  ) THEN
    RAISE EXCEPTION 'FALLO: la auditoría expone material sensible';
  END IF;

  -- 16) Un cambio en datos genera evento 'U' con el diff esperado
  UPDATE patrimonial.funcionario_datos
     SET telefono = '4437654321'
   WHERE funcionario_id = v_funcionario_id;

  IF NOT EXISTS (
    SELECT 1 FROM auditoria.registro_evento
    WHERE esquema = 'patrimonial' AND tabla = 'funcionario_datos'
      AND operacion = 'U' AND registro_id = v_funcionario_id
      AND datos_anteriores ->> 'telefono' = '4431234567'
      AND datos_nuevos ->> 'telefono' = '4437654321'
  ) THEN
    RAISE EXCEPTION 'FALLO: la auditoría del cambio no contiene el diff esperado';
  END IF;

  RAISE NOTICE 'Pruebas de usuarios: OK';
END $$;

ROLLBACK;
