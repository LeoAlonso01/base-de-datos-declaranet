# Modelo conceptual

Estado: **sección de usuarios refinada** (autenticación simple + tabla de datos 1:1
con sesión de 35 minutos); declaraciones y anexos en diseño.
Última actualización: 2026-11-11.

## 1. Actores

### Funcionario (usuario-funcionario)

Persona que labora o ha ocupado un cargo en la UMSNH. Puede:

- Crear su cuenta (con verificación de correo).
- Recuperar su contraseña.
- Crear declaraciones de los 5 tipos de trámite.
- Obtener su declaración y su acuse.

Inicia sesión con su **CURP** y contraseña.

### Administrador (usuario-administrador)

Personal autorizado que opera la plataforma. Puede:

- Gestionar cuentas de funcionarios.
- Revisar y validar la información declarada.
- Generar reportes.
- Actualizar datos personales de funcionarios a solicitud.

Inicia sesión con su **nombre de usuario** y contraseña.

Ambos tipos de usuario son **independientes**: tablas separadas, credenciales separadas
y tokens separados (aunque compartan el catálogo de tipos de token).

## 2. Entidades

### `patrimonial.funcionario` (autenticación simple)

| Atributo | Tipo | Regla |
|---|---|---|
| `id` | `bigint identity` | PK |
| `curp` | `dom_curp` | único, formato CURP (clave de inicio de sesión) |
| `password_hash` | `text` | hash; mínimo 20 caracteres |
| `estado_cuenta_id` | FK `catalogos.estado_cuenta` | inicia en `PENDIENTE_VERIFICACION` |
| `creado_en` / `actualizado_en` | `timestamptz` | |

### `patrimonial.funcionario_datos` (datos personales, contacto y sesión, 1:1)

| Atributo | Tipo | Regla |
|---|---|---|
| `funcionario_id` | `bigint` | PK, FK `patrimonial.funcionario` (ON DELETE CASCADE) |
| `rfc` | `dom_rfc` | único, RFC de persona física |
| `nombre_completo` | `text` | no vacío |
| `correo` | `dom_correo` | único, sin distinguir mayúsculas |
| `correo_secundario` | `dom_correo` | opcional |
| `telefono` | `dom_telefono` | 10 dígitos, opcional |
| `correo_verificado_en` | `timestamptz` | al verificar el correo |
| `token_sesion_hash` | `text` | hash del token de sesión |
| `sesion_emitida_en` | `timestamptz` | emisión de la sesión |
| `sesion_expira_en` | `timestamptz` | emisión + a lo sumo 35 minutos |
| `creado_en` / `actualizado_en` | `timestamptz` | `actualizado_en` por trigger |

### `seguridad.administrador` (autenticación simple)

| Atributo | Tipo | Regla |
|---|---|---|
| `id` | `bigint identity` | PK |
| `nombre_usuario` | `citext` | único, `^[a-z0-9._-]{3,50}$` (clave de inicio de sesión) |
| `password_hash` | `text` | hash; mínimo 20 caracteres |
| `rol_id` | FK `catalogos.rol_administrador` | |
| `activo` | `boolean` | baja lógica |
| `creado_en` / `actualizado_en` | `timestamptz` | |

### `seguridad.administrador_datos` (datos personales, contacto y sesión, 1:1)

| Atributo | Tipo | Regla |
|---|---|---|
| `administrador_id` | `bigint` | PK, FK `seguridad.administrador` (ON DELETE CASCADE) |
| `nombre_completo` | `text` | no vacío |
| `correo` | `dom_correo` | único, sin distinguir mayúsculas |
| `correo_secundario` | `dom_correo` | opcional |
| `telefono` | `dom_telefono` | 10 dígitos, opcional |
| `token_sesion_hash` | `text` | hash del token de sesión |
| `sesion_emitida_en` | `timestamptz` | emisión de la sesión |
| `sesion_expira_en` | `timestamptz` | emisión + a lo sumo 35 minutos |
| `creado_en` / `actualizado_en` | `timestamptz` | |

### `seguridad.token_usuario`

Token de un solo uso para recuperación de contraseña o verificación de correo.

| Atributo | Regla |
|---|---|
| `tipo_token_id` | FK `catalogos.tipo_token` |
| `funcionario_id` / `administrador_id` | exactamente uno presente (`CHECK`) |
| `token_hash` | único, ≥ 32 caracteres; nunca se guarda el token en claro |
| `expira_en` | > `creado_en` |
| `usado_en` | marca de consumo (un solo uso) |
| `ip_solicitud` | `inet`, opcional |

## 3. Catálogos

| Catálogo | Valores |
|---|---|
| `tipo_declaracion` | `INICIO`, `MODIFICACION`, `CONCLUSION`, `NOTA_ACLARATORIA`, `CAMBIO_DEPENDENCIA` |
| `estado_cuenta` | `PENDIENTE_VERIFICACION`, `ACTIVA`, `BLOQUEADA`, `BAJA` |
| `rol_administrador` | `SUPERADMINISTRADOR`, `ADMINISTRADOR`, `REVISOR`, `CONSULTA` |
| `sexo` | `H`, `M` |
| `tipo_token` | `RECUPERACION_PASSWORD`, `VERIFICACION_CORREO` |

## 4. Relaciones

```mermaid
erDiagram
    funcionario ||--|| funcionario_datos : "1:1"
    administrador ||--|| administrador_datos : "1:1"
    funcionario ||--o{ token_usuario : solicita
    administrador ||--o{ token_usuario : solicita
    estado_cuenta ||--o{ funcionario : "estado de"
    rol_administrador ||--o{ administrador : asigna
    tipo_token ||--o{ token_usuario : tipifica
```

## 5. Reglas transversales

- Las contraseñas se guardan **solo como hash** (bcrypt/argon2id); la base rechaza valores
  de menos de 20 caracteres.
- Los tokens se guardan **solo como hash**, caducan y son de un solo uso.
- La **sesión dura a lo sumo 35 minutos**: `sesion_expira_en - sesion_emitida_en ≤ 35 min`,
  validado por `CHECK`. Al expirar, la aplicación pregunta al usuario si desea renovar el
  token de sesión.
- Cada usuario tiene una sola sesión activa (los datos de sesión viven en la tabla 1:1).
  Si en el futuro se requieren sesiones concurrentes, promover a una tabla `seguridad.sesion`.
- Toda alta, cambio o baja en `funcionario`, `administrador` y sus tablas de datos se
  registra en `auditoria.registro_evento`, **sin** `password_hash`, `token_hash` ni
  `token_sesion_hash`.
- El correo es único sin distinguir mayúsculas (`citext`).
- CURP y RFC son únicos y validados por dominio.
- Pendiente: nombramientos/dependencias, declaraciones y anexos patrimoniales.
