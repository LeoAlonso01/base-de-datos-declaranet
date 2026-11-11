-- =============================================================
-- 0003_usuarios.sql — Sección de usuarios
-- Dos tipos de usuario COMPLETAMENTE SEPARADOS:
--   * patrimonial.funcionario  → usuarios-funcionarios
--   * seguridad.administrador  → usuarios-administradores
-- Además, tokens de un solo uso para recuperación de contraseña
-- y verificación de correo.
-- =============================================================
BEGIN;

-- Usuarios-funcionarios ----------------------------------------
-- Persona que crea su cuenta, presenta declaraciones y obtiene
-- su declaración y acuse.
CREATE TABLE patrimonial.funcionario (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  curp                public.dom_curp     NOT NULL,
  rfc                 public.dom_rfc      NOT NULL,
  nombres             public.dom_nombre   NOT NULL,
  apellido_paterno    public.dom_nombre   NOT NULL,
  apellido_materno    public.dom_nombre,
  fecha_nacimiento    date                NOT NULL,
  sexo_id             smallint            NOT NULL REFERENCES catalogos.sexo (id),
  correo              public.dom_correo   NOT NULL,
  telefono            public.dom_telefono,
  password_hash       text                NOT NULL,
  estado_cuenta_id    smallint            NOT NULL
                        DEFAULT catalogos.id_estado_cuenta('PENDIENTE_VERIFICACION')
                        REFERENCES catalogos.estado_cuenta (id),
  correo_verificado_en timestamptz,
  ultimo_acceso_en    timestamptz,
  creado_en           timestamptz         NOT NULL DEFAULT now(),
  actualizado_en      timestamptz         NOT NULL DEFAULT now(),
  CONSTRAINT funcionario_curp_uk   UNIQUE (curp),
  CONSTRAINT funcionario_rfc_uk    UNIQUE (rfc),
  CONSTRAINT funcionario_correo_uk UNIQUE (correo),
  CONSTRAINT funcionario_fecha_nacimiento_valida
    CHECK (fecha_nacimiento >= DATE '1900-01-01'),
  -- Rechaza contraseñas en claro (un hash real mide 60+ caracteres).
  CONSTRAINT funcionario_password_hash_valido
    CHECK (length(password_hash) >= 20)
);

COMMENT ON TABLE patrimonial.funcionario
  IS 'Cuenta y datos personales de un usuario-funcionario (crea declaraciones)';
COMMENT ON COLUMN patrimonial.funcionario.password_hash
  IS 'Hash de contraseña (bcrypt/argon2id). Nunca se almacena la contraseña en claro';
COMMENT ON COLUMN patrimonial.funcionario.estado_cuenta_id
  IS 'Estado de la cuenta; inicia en PENDIENTE_VERIFICACION';

-- Usuarios-administradores -------------------------------------
-- Personal que gestiona funcionarios, revisa información,
-- genera reportes y actualiza datos personales a solicitud.
CREATE TABLE seguridad.administrador (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_usuario      citext              NOT NULL,
  correo              public.dom_correo   NOT NULL,
  password_hash       text                NOT NULL,
  nombres             public.dom_nombre   NOT NULL,
  apellido_paterno    public.dom_nombre   NOT NULL,
  apellido_materno    public.dom_nombre,
  rol_id              smallint            NOT NULL REFERENCES catalogos.rol_administrador (id),
  activo              boolean             NOT NULL DEFAULT true,
  ultimo_acceso_en    timestamptz,
  creado_en           timestamptz         NOT NULL DEFAULT now(),
  actualizado_en      timestamptz         NOT NULL DEFAULT now(),
  CONSTRAINT administrador_nombre_usuario_formato
    CHECK (nombre_usuario ~ '^[a-z0-9._-]{3,50}$'),
  CONSTRAINT administrador_nombre_usuario_uk UNIQUE (nombre_usuario),
  CONSTRAINT administrador_correo_uk         UNIQUE (correo),
  CONSTRAINT administrador_password_hash_valido
    CHECK (length(password_hash) >= 20)
);

COMMENT ON TABLE seguridad.administrador
  IS 'Cuenta de un usuario-administrador (gestiona funcionarios y declaraciones)';
COMMENT ON COLUMN seguridad.administrador.password_hash
  IS 'Hash de contraseña (bcrypt/argon2id). Nunca se almacena la contraseña en claro';

-- Tokens de un solo uso ----------------------------------------
-- Recuperación de contraseña y verificación de correo.
-- Cada token pertenece a exactamente un usuario, sea funcionario
-- o administrador (las tablas de usuario están separadas).
CREATE TABLE seguridad.token_usuario (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_token_id    smallint      NOT NULL REFERENCES catalogos.tipo_token (id),
  funcionario_id   bigint        REFERENCES patrimonial.funcionario (id) ON DELETE CASCADE,
  administrador_id bigint        REFERENCES seguridad.administrador (id) ON DELETE CASCADE,
  token_hash       text          NOT NULL,
  expira_en        timestamptz   NOT NULL,
  usado_en         timestamptz,
  ip_solicitud     inet,
  creado_en        timestamptz   NOT NULL DEFAULT now(),
  -- Exactamente uno de los dos propietarios debe estar presente.
  CONSTRAINT token_un_propietario CHECK ((funcionario_id IS NULL) <> (administrador_id IS NULL)),
  CONSTRAINT token_hash_uk        UNIQUE (token_hash),
  -- Se guarda el hash del token, nunca el token en claro.
  CONSTRAINT token_hash_valido    CHECK (length(token_hash) >= 32),
  CONSTRAINT token_vigencia       CHECK (expira_en > creado_en)
);

CREATE INDEX token_usuario_funcionario_idx
  ON seguridad.token_usuario (funcionario_id, expira_en)
  WHERE funcionario_id IS NOT NULL;

CREATE INDEX token_usuario_administrador_idx
  ON seguridad.token_usuario (administrador_id, expira_en)
  WHERE administrador_id IS NOT NULL;

COMMENT ON TABLE seguridad.token_usuario
  IS 'Tokens de un solo uso (recuperación de contraseña / verificación de correo)';
COMMENT ON COLUMN seguridad.token_usuario.token_hash
  IS 'Hash del token. El token en claro solo se envía al usuario, nunca se almacena';

-- Mantener actualizado_en --------------------------------------
CREATE TRIGGER funcionario_marca_tiempo
  BEFORE UPDATE ON patrimonial.funcionario
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_marca_tiempo();

CREATE TRIGGER administrador_marca_tiempo
  BEFORE UPDATE ON seguridad.administrador
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_marca_tiempo();

COMMIT;
