# 📍 CONTEXT.md — Punto de partida y estado del proyecto

> Este archivo es la **primera lectura obligada de cualquier sesión de trabajo** (humana o de IA).
> Contiene el estado actual, las decisiones tomadas y el siguiente paso concreto.
> **Actualízalo al cierre de cada sesión significativa** (ver §6).

Última actualización: **2026-11-11**

## 1. ¿Qué es este proyecto?

Arquitectura de base de datos en **PostgreSQL 16** para la plataforma de **declaraciones
patrimoniales** del personal de la **UMSNH**, al estilo del sistema federal DECLARANET.
Es el diseño de la capa de datos únicamente (modelo, DDL, migraciones, seguridad y
pruebas); **no hay código de aplicación**.

Lectura complementaria:

- [`AGENTS.md`](AGENTS.md) — convenciones, nomenclatura, reglas de migración y seguridad.
  **Obligatorio antes de tocar cualquier SQL.**
- [`README.md`](README.md) — presentación del proyecto y puesta en marcha.
- [`docs/modelo-conceptual.md`](docs/modelo-conceptual.md) — entidades y reglas de negocio.

## 2. Estado actual

**Fase: 🚧 diseño de la arquitectura. Sección de usuarios refinada (autenticación simple +
datos 1:1 + sesión de 35 minutos); catálogo de cargos de la UMSNH con columna `categoria`;
catálogos de Datos Generales; domicilio del declarante (nacional/extranjero) con
aclaraciones/observaciones; declaraciones en diseño.**

Terminado:

- [x] `AGENTS.md`, `README.md`, `CONTEXT.md` y ambiente Docker local.
- [x] Migración `0001_base.sql`: extensiones, esquemas, dominios y función de marcas de tiempo.
- [x] Migración `0002_catalogos.sql`: catálogos iniciales (`tipo_declaracion` con 5 trámites,
  `estado_cuenta`, `rol_administrador`, `sexo`, `tipo_token`).
- [x] Migración `0003_usuarios.sql`: usuarios **separados** `patrimonial.funcionario` y
  `seguridad.administrador`, más `seguridad.token_usuario`.
- [x] Migración `0004_auditoria.sql`: auditoría genérica por triggers
  (`auditoria.registro_evento`), sin material sensible.
- [x] Migración `0005_refactor_usuarios_datos.sql`: tablas 1:1 de datos personales/contacto/sesión,
  migración de datos existentes, eliminación de columnas redundantes, sesión ≤ 35 minutos.
- [x] Migración `0006_catalogos_cargos.sql`: catálogo de cargos de la UMSNH (29 puestos).
- [x] Migración `0007_catalogos_cargos_categoria.sql`: columna `categoria` (código de RR.HH.) +
  sincronización idempotente de los 29 cargos.
- [x] Migración `0008_catalogos_datos_generales.sql`: catálogos de Datos Generales
  (prefijos telefónicos E.164, estado civil con 6 opciones, países ISO 3166-1,
  nacionalidades) + alineación no destructiva de `funcionario_datos`.
- [x] Migración `0009_domicilio_declarante.sql`: catálogos geográficos (entidad federativa,
  municipio, tipo de asentamiento, código postal, asentamiento) + tabla `patrimonial.domicilio`
  (nacional/extranjero) con `aclaraciones_observaciones`.
- [x] Pruebas `pruebas/0001_usuarios.sql`, `pruebas/0002_catalogos_cargos.sql`,
  `pruebas/0003_catalogos_cargos_categoria.sql`, `pruebas/0004_catalogos_datos_generales.sql` y
  `pruebas/0005_domicilio_declarante.sql` en verde.

**Última migración aplicable: `0009_domicilio_declarante.sql`.** La siguiente debe llamarse `0010_*.sql`.

Pendiente (en orden de ejecución):

1. Catálogos adicionales restantes que deben quedar en la base: tipo de bien, tipo de ingreso,
   moneda, parentesco, nivel de estudio, etc. (catálogos de Datos Generales y cargos ya están).
2. Nombramientos, dependencias y puestos (relación funcionario ↔ cargo).
3. Declaraciones y sus 5 tipos de trámite, con folio y acuse.
4. Anexos patrimoniales (inmuebles, vehículos, cuentas, adeudos, empresas, fideicomisos, ingresos).
5. Roles de aplicación y políticas RLS.
6. Ampliación de la suite de pruebas.

## 3. Decisiones tomadas (resumen)

| Tema | Decisión | Detalle |
|---|---|---|
| Motor de BD | PostgreSQL 16+ | `AGENTS.md` §2 |
| Aclaraciones/Observaciones | Campo obligatorio en tablas de formularios/apartados | `AGENTS.md` §6 |
| Esquemas | `patrimonial`, `catalogos`, `seguridad`, `auditoria` | `AGENTS.md` §5 |
| Usuarios | **Dos tablas separadas**: `funcionario` y `administrador` | `migraciones/0003_usuarios.sql` |
| Datos personales | Tabla 1:1 (`funcionario_datos`, `administrador_datos`) | `migraciones/0005_refactor_usuarios_datos.sql` |
| Sesión | Duración máxima **35 minutos**, validada por `CHECK`; renovación por token | `migraciones/0005_refactor_usuarios_datos.sql` |
| Trámites | 5 tipos en `catalogos.tipo_declaracion` | `migraciones/0002_catalogos.sql` |
| Autenticación | `password_hash` + tokens de un solo uso (guardados como hash) | `migraciones/0003_usuarios.sql` |
| Auditoría | Triggers AFTER, sin `password_hash`, `token_hash` ni `token_sesion_hash` | `migraciones/0004_auditoria.sql` y `0005` |
| Nomenclatura | `snake_case`, español, tablas en singular, PK `bigint identity` | `AGENTS.md` §6 |
| Dinero | `NUMERIC(18,2)` + FK a `catalogos.moneda` (nunca `float`) | `AGENTS.md` §6 |
| Migraciones | **Fuente de verdad ejecutable** | `docs/adr/001-migraciones-fuente-de-verdad.md` |

## 4. Entorno y comandos

```bash
# Levantar la base de datos local (primera vez: cp .env.example .env)
docker compose up -d

# Conectarse a la BD
docker compose exec db psql -U declaranet -d declaranet

# Aplicar todas las migraciones en orden
for f in migraciones/*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f" || break
done

# Ejecutar las pruebas (terminan en ROLLBACK, no dejan datos)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f pruebas/0001_usuarios.sql

# Publicar cambios en GitHub (SSH ya configurado en ~/.ssh/config)
git push origin main
```

## 5. Cómo continuar una sesión

1. Lee este archivo y `AGENTS.md`.
2. Revisa el último número de migración en `migraciones/` (hoy: `0005_refactor_usuarios_datos.sql`).
3. Toma el primer pendiente de §2, propón el plan al usuario y confirma antes de ejecutar.

## 6. Reglas de mantenimiento de este archivo

- Actualiza la fecha de "Última actualización" en cada cambio.
- Marca lo terminado y reordena los pendientes: el siguiente paso siempre debe ser evidente
  sin necesidad de leer el historial de conversaciones.
- Registra aquí toda decisión nueva que afecte el diseño (o crea un ADR en `docs/adr/`).
- Nunca incluyas datos personales reales ni secretos.
