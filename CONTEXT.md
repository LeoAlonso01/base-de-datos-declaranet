# 📍 CONTEXT.md — Punto de partida y estado del proyecto

> Este archivo es la **primera lectura obligada de cualquier sesión de trabajo** (humana o de IA).
> Contiene el estado actual, las decisiones tomadas y el siguiente paso concreto.
> **Actualízalo al cierre de cada sesión significativa** (ver §6).

Última actualización: **2026-11-10**

## 1. ¿Qué es este proyecto?

Arquitectura de base de datos en **PostgreSQL 16** para la plataforma de **declaraciones
patrimoniales** del personal de la **UMSNH**, al estilo del sistema federal DECLARANET.
Es el diseño de la capa de datos únicamente (modelo, DDL, migraciones, seguridad y
pruebas); **no hay código de aplicación**.

Lectura complementaria:

- [`AGENTS.md`](AGENTS.md) — convenciones, nomenclatura, reglas de migración y seguridad.
  **Obligatorio antes de tocar cualquier SQL.**
- [`README.md`](README.md) — presentación del proyecto y puesta en marcha.

## 2. Estado actual

**Fase: 🚧 diseño de la arquitectura. Todavía no hay DDL ni migraciones.**

Terminado:

- [x] `AGENTS.md`: convenciones completas del proyecto.
- [x] `README.md` representativo del proyecto.
- [x] Repositorio Git publicado en GitHub (rama `main`, push por SSH ya configurado).
- [x] Ambiente local Docker con PostgreSQL 16 (`docker-compose.yml` + `.env.example`).
- [x] Estructura de carpetas creada (`sql/`, `migraciones/`, `pruebas/`, `docs/`).

Pendiente (en orden de ejecución):

1. `docs/modelo-conceptual.md` — entidades, atributos y reglas de negocio.
2. Modelo lógico y diagramas ER en `docs/erd/`.
3. `sql/00_base/` + `migraciones/0001_*.sql` — extensiones, esquemas, roles y dominios de datos.
4. Catálogos normativos (`sql/10_catalogos/` + semillas en `sql/80_semillas/`).
5. Tablas de dominio e historización de declaraciones.
6. Auditoría por triggers y políticas RLS.
7. Suite de pruebas (`pruebas/`).

## 3. Decisiones tomadas (resumen)

| Tema | Decisión | Detalle |
|---|---|---|
| Motor de BD | PostgreSQL 16+ | Justificación completa en `AGENTS.md` §2 |
| Esquemas | `patrimonial`, `catalogos`, `seguridad`, `auditoria` | `AGENTS.md` §5 |
| Nomenclatura | `snake_case`, español, tablas en singular, PK `bigint identity` | `AGENTS.md` §6 |
| Dinero | `NUMERIC(18,2)` + FK a `catalogos.moneda` (nunca `float`) | `AGENTS.md` §6 |
| Historización | Una declaración presentada nunca se modifica; se versiona | `AGENTS.md` §6 |
| Seguridad | RLS + `pgcrypto` + auditoría por triggers | `AGENTS.md` §6 y §8 |
| Migraciones | `NNNN_descripcion.sql`, transaccionales, nunca editar una aplicada | `AGENTS.md` §7 |

## 4. Entorno y comandos

```bash
# Levantar la base de datos local (primera vez: cp .env.example .env)
docker compose up -d

# Conectarse a la BD
docker compose exec db psql -U declaranet -d declaranet

# Publicar cambios en GitHub (SSH ya configurado en ~/.ssh/config)
git push origin main
```

## 5. Cómo continuar una sesión

1. Lee este archivo y `AGENTS.md`.
2. Revisa el último número de migración en `migraciones/` (hoy no existe ninguna).
3. Toma el primer pendiente de §2, propón el plan al usuario y confirma antes de ejecutar.

## 6. Reglas de mantenimiento de este archivo

- Actualiza la fecha de "Última actualización" en cada cambio.
- Marca lo terminado y reordena los pendientes: el siguiente paso siempre debe ser evidente
  sin necesidad de leer el historial de conversaciones.
- Registra aquí toda decisión nueva que afecte el diseño (o crea un ADR en `docs/adr/`).
- Nunca incluyas datos personales reales ni secretos.
