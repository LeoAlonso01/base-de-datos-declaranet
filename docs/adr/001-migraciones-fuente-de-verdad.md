# ADR 001 — Las migraciones son la fuente de verdad

- **Fecha:** 2026-11-11
- **Estado:** aceptado

## Contexto

`AGENTS.md` define una carpeta `sql/` organizada por capas (base, catálogos, tablas,
restricciones, índices, funciones, vistas, políticas y semillas) y una carpeta
`migraciones/` con scripts numerados. Mantener el mismo DDL en ambos lugares provoca
divergencia y errores difíciles de rastrear.

## Decisión

La **fuente de verdad ejecutable** son los archivos `migraciones/NNNN_descripcion.sql`,
aplicados en orden secuencial sobre una base nueva o ya migrada. La carpeta `sql/` queda
como material de referencia por capas (documentación, snippets y consultas de verificación)
y **no se aplica** en despliegues.

## Consecuencias

- Todo cambio de esquema requiere una migración nueva; nunca se edita una migración aplicada.
- `sql/` puede quedar desactualizada y no debe usarse para desplegar.
- Las pruebas (`pruebas/`) se ejecutan después de aplicar las migraciones.
- El número de la última migración es el punto de partida de cualquier sesión (ver
  `CONTEXT.md`).
