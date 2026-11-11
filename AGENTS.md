# AGENTS.md — Plataforma de Declaraciones Patrimoniales UMSNH

Instrucciones y convenciones para agentes de IA (y humanos) que trabajan en este repositorio.
**Lee este archivo completo antes de modificar cualquier cosa.**

> 📍 **Punto de partida:** consulta [`CONTEXT.md`](CONTEXT.md) — estado actual del proyecto,
> decisiones tomadas y siguiente paso concreto. Se actualiza al cierre de cada sesión.

---

## 1. Propósito del proyecto

Diseñar e implementar la arquitectura de base de datos para una plataforma que gestiona el
ciclo de vida completo de las **declaraciones patrimoniales** del personal de la
**Universidad Michoacana de San Nicolás de Hidalgo (UMSNH)**:

- Registro de funcionarios y su historial de cargos.
- Captura de declaraciones por secciones (bienes, ingresos, adeudos, etc.).
- Validación, presentación, revisión y historial de versiones.
- Auditoría de accesos y cambios.
- Reportes y consultas para los órganos de control.

## 2. Decisión de arquitectura: motor de base de datos

**Motor elegido: PostgreSQL 16 o superior** (primera opción del proyecto, confirmada).

Por qué PostgreSQL y no MySQL/MariaDB u otros:

| Criterio | PostgreSQL | MySQL / MariaDB |
|---|---|---|
| Row-Level Security (RLS) | Nativo y maduro | No disponible |
| Cifrado por columna | `pgcrypto` incluido | Limitado a la capa de app |
| JSONB + índices GIN | Excelente | JSON menos potente |
| Constraints avanzados (CHECK complejos, deferrable, EXCLUDE) | Sí | Limitado |
| Particionamiento declarativo | Sí | Limitado |
| Extensiones (`pg_trgm`, `citext`, `uuid`) | Ecosistema amplio | Limitado |
| Licenciamiento | PostgreSQL License (tipo BSD) | GPL / propiedad de Oracle |

Para un sistema con datos personales sensibles (patrimonio de servidores públicos),
**RLS + pgcrypto + auditoría con JSONB** son capacidades decisivas y justifican la elección.

## 3. Marco normativo (contexto obligatorio de dominio)

- **Ley General de Responsabilidades Administrativas (LGRA), arts. 32–47.** La plataforma
  modela **cinco tipos de trámite** (`catalogos.tipo_declaracion`):
  1. **INICIO** — declaración inicial, dentro de los 60 días naturales siguientes a la toma de posesión.
  2. **MODIFICACION** — declaración anual de modificación patrimonial, durante mayo de cada año.
  3. **CONCLUSION** — dentro de los 60 días naturales siguientes a la separación del cargo.
  4. **NOTA_ACLARATORIA** — aclaración sobre una declaración presentada (trámite interno UMSNH).
  5. **CAMBIO_DEPENDENCIA** — cambio de adscripción o dependencia (trámite interno UMSNH).
- Secciones típicas de contenido: datos curriculares, datos del empleo/cargo/comisión,
  ingresos, bienes inmuebles, vehículos, bienes muebles (joyas, obras de arte, colecciones),
  inversiones y cuentas bancarias, adeudos y pasivos, participación en empresas,
  fideicomisos, apoyos y beneficios públicos.
- **LGPDPPSO** (Ley General de Protección de Datos Personales en Posesión de Sujetos
  Obligados): minimización de datos, cifrado de datos sensibles, acceso por roles y
  bitácora de consultas.

> Regla de oro: cuando el diseño de datos entre en tensión con la norma, **la norma gana**.
> Documenta la decisión en `docs/adr/`.

## 4. Estructura del repositorio (objetivo)

```
declaraciones-patrimoniales/
├── AGENTS.md                  # Este archivo
├── README.md                  # Guía rápida de instalación y uso
├── docs/
│   ├── modelo-conceptual.md  # Entidades y reglas de negocio
│   ├── modelo-logico.md      # Tablas, columnas, relaciones
│   ├── erd/                  # Diagramas entidad-relación (mermaid, dbdiagram)
│   └── adr/                  # Decisiones de arquitectura (ADR-NNN-*.md)
├── sql/
│   ├── 00_base/              # Extensiones, esquemas, roles, dominios de datos
│   ├── 10_catalogos/         # Catálogos / listas de valores
│   ├── 20_tablas/            # DDL por módulo funcional
│   ├── 30_restricciones/     # FKs, CHECKs, UNIQUEs
│   ├── 40_indices/           # Índices secundarios
│   ├── 50_funciones/         # Funciones y triggers (auditoría, folios, estados)
│   ├── 60_vistas/            # Vistas de consulta y reportes
│   ├── 70_politicas/         # Políticas de Row-Level Security
│   └── 80_semillas/          # Datos iniciales (catálogos, roles)
├── migraciones/              # Scripts versionados: NNNN_descripcion.sql
└── pruebas/                  # Scripts de verificación / asserts SQL
```

## 5. Módulos funcionales previstos

| Módulo | Esquema PG | Contenido |
|---|---|---|
| Núcleo | `patrimonial` | funcionario (usuario), dependencia, puesto, nombramiento |
| Declaración | `patrimonial` | declaracion, version, secciones y anexos |
| Catálogos | `catalogos` | tipo_declaracion, estado_cuenta, rol_administrador, sexo, tipo_token… |
| Seguridad | `seguridad` | administrador (usuario), roles y tokens |
| Auditoría | `auditoria` | bitácora de cambios y de consultas |

## 6. Convenciones de diseño

### Nomenclatura
- Identificadores en `snake_case`, **sin acentos ni "ñ"** (`declaracion`, no `declaración`).
- Nombres de dominio en **español** (la norma y los usuarios hablan español).
- Tablas en **singular**; claves foráneas como `<tabla>_id`
  (ej. `funcionario_id`, `declaracion_id`).
- PK técnica: `id BIGINT GENERATED ALWAYS AS IDENTITY`.
  Claves de negocio (CURP, RFC, folio) van en columnas aparte con `UNIQUE` + `CHECK`,
  nunca como PK.
- Prefijo natural por esquema, no por prefijo en el nombre de la tabla.

### Tipos de datos
- Fechas/horas: `TIMESTAMPTZ` siempre; `DATE` solo para fechas legales
  (fecha de presentación, de toma de posesión).
- Dinero: `NUMERIC(18,2)` + FK a `catalogos.moneda` (default MXN). **Nunca** `float`.
- Identificadores legales: `DOMAIN` validados (`dom_curp`, `dom_rfc`, `dom_telefono`).
- Correos: extensión `citext`.
- Estructuras semiestructuradas (anexos que varían por ejercicio fiscal): `JSONB`
  con validación vía `CHECK (...)::jsonb @> ...`.
- Datos especialmente sensibles (número de cuenta, saldos): cifrar con `pgcrypto`
  si la sección lo requiere; evaluar primero minimización.

### Reglas de negocio en la base
- La integridad se declara en la BD, no solo en la app: FKs, CHECKs, UNIQUEs.
- Historización: una declaración presentada **no se modifica**; se genera nueva versión.
  El estado (`borrador`, `presentada`, `en_revision`, `validada`, `rechazada`) es una
  máquina de estados cuyas transiciones valida un trigger.
- Auditoría: toda tabla de dominio dispara a `auditoria.registro_evento`
  (JSONB con diff old/new, usuario de BD, timestamp).
- RLS obligatorio en tablas con datos personales; la aplicación nunca conecta
  con superusuario.
- Particionamiento por año fiscal para tablas de alto volumen (anexos, bitácora).
- Sesiones: duración máxima de **35 minutos**, validada por `CHECK` en las tablas de
  datos (`funcionario_datos`, `administrador_datos`); la renovación se gestiona por token.

## 7. Convenciones de migraciones

- La **fuente de verdad ejecutable** son las migraciones (`migraciones/`). La carpeta `sql/`
  conserva material de referencia por capas y no se aplica directamente
  (ver `docs/adr/001-migraciones-fuente-de-verdad.md`).
- Una migración por cambio lógico: `migraciones/NNNN_descripcion.sql`, numeración
  secuencial creciente, sin huecos.
- **Nunca edites una migración ya aplicada**: crea una nueva.
- Cada migración transaccional (`BEGIN; ... COMMIT;`).
- Toda migración debe funcionar sobre una BD recién creada **y** sobre una BD ya migrada.
- Aplicar: `psql "$DATABASE_URL" -f migraciones/NNNN_*.sql`; después ejecutar `pruebas/`.

## 8. Reglas de seguridad y datos

- **Prohibido** usar datos personales reales en semillas, pruebas o ejemplos.
  Genera CURP, RFC y nombres sintéticos.
- No commitear credenciales. Usar `DATABASE_URL` y variables de entorno.
- Contraseñas de roles de BD vía variables de `psql` (`\set` / `-v`), nunca hardcodeadas.
- Cualquier consulta masiva sobre datos personales debe quedar registrada en auditoría.

## 9. Definición de terminado (por entrega de esquema)

1. DDL aplicado sin errores en una BD limpia (PostgreSQL 16, Docker).
2. Migración numerada y pruebas en verde.
3. ERD actualizado en `docs/erd/`.
4. ADR creado si hubo una decisión relevante no obvia.

## 10. Flujo de trabajo del agente

- Comienza leyendo `CONTEXT.md` (estado actual y siguiente paso) y manténlo actualizado
  al cerrar la sesión.
- Antes de tocar `sql/` o `migraciones/`, identifica el último número de migración existente.
- Prueba todo contra una BD local (contenedor Docker) antes de darlo por bueno.
- Cambios pequeños y revisables; un propósito por entrega.
- Ante ambigüedad de dominio (criterios internos UMSNH, plazos, secciones obligatorias),
  **pregunta antes de inventar**.
- No mezclar cambios de esquema con cambios de datos de prueba.
