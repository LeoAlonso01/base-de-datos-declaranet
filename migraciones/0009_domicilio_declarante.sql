-- =============================================================
-- 0009_domicilio_declarante.sql
-- Sección "Domicilio del declarante" + catálogos geográficos:
--   * catalogos.entidad_federativa (32, oficiales)
--   * catalogos.municipio (estructura; carga completa vía COPY/INEGI)
--   * catalogos.tipo_asentamiento (tipos de asentamiento/colonia)
--   * catalogos.codigo_postal (estructura; carga completa vía COPY/SEPOMEX)
--   * catalogos.asentamiento (colonia/asentamiento; carga completa vía COPY/SEPOMEX)
--   * patrimonial.domicilio (nacional o extranjero, con aclaraciones)
-- Regla permanente: toda tabla que represente un formulario o
-- apartado de una declaración incluye aclaraciones_observaciones TEXT.
-- =============================================================
BEGIN;

-- =============================================================
-- 1) Entidades federativas de México (32, oficiales)
-- =============================================================
CREATE TABLE catalogos.entidad_federativa (
  id     smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave  text     NOT NULL UNIQUE,   -- clave INEGI de 2 dígitos
  nombre text     NOT NULL,
  activo boolean  NOT NULL DEFAULT true,
  CONSTRAINT entidad_federativa_clave_formato CHECK (clave ~ '^[0-9]{2}$'),
  CONSTRAINT entidad_federativa_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

COMMENT ON TABLE catalogos.entidad_federativa
  IS 'Entidades federativas de México (32). Fuente: INEGI (Catálogo Único de Claves Geoestadísticas)';

INSERT INTO catalogos.entidad_federativa (clave, nombre) VALUES
  ('01','Aguascalientes'),
  ('02','Baja California'),
  ('03','Baja California Sur'),
  ('04','Campeche'),
  ('05','Coahuila'),
  ('06','Colima'),
  ('07','Chiapas'),
  ('08','Chihuahua'),
  ('09','Ciudad de México'),
  ('10','Durango'),
  ('11','Guanajuato'),
  ('12','Guerrero'),
  ('13','Hidalgo'),
  ('14','Jalisco'),
  ('15','México'),
  ('16','Michoacán'),
  ('17','Morelos'),
  ('18','Nayarit'),
  ('19','Nuevo León'),
  ('20','Oaxaca'),
  ('21','Puebla'),
  ('22','Querétaro'),
  ('23','Quintana Roo'),
  ('24','San Luis Potosí'),
  ('25','Sinaloa'),
  ('26','Sonora'),
  ('27','Tabasco'),
  ('28','Tamaulipas'),
  ('29','Tlaxcala'),
  ('30','Veracruz'),
  ('31','Yucatán'),
  ('32','Zacatecas');

-- =============================================================
-- 2) Municipios / alcaldías (estructura; carga completa vía INEGI)
-- =============================================================
CREATE TABLE catalogos.municipio (
  id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entidad_federativa_id  smallint NOT NULL REFERENCES catalogos.entidad_federativa (id),
  clave                  text     NOT NULL,   -- clave INEGI (2 estado + 3 municipio)
  nombre                 text     NOT NULL,
  activo                 boolean  NOT NULL DEFAULT true,
  CONSTRAINT municipio_clave_uk UNIQUE (entidad_federativa_id, clave),
  CONSTRAINT municipio_clave_formato CHECK (clave ~ '^[0-9]{3,5}$'),
  CONSTRAINT municipio_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

COMMENT ON TABLE catalogos.municipio
  IS 'Municipios y alcaldías de México. Estructura lista; la carga completa se realiza '
     'desde el Catálogo Único de Claves Geoestadísticas (INEGI). Ver docs/carga-catalogos-domicilio.md';

CREATE INDEX municipio_entidad_idx ON catalogos.municipio (entidad_federativa_id);

-- =============================================================
-- 3) Tipos de asentamiento (colonia, fraccionamiento, etc.)
-- =============================================================
CREATE TABLE catalogos.tipo_asentamiento (
  id     smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave  text     NOT NULL UNIQUE,
  nombre text     NOT NULL,
  activo boolean  NOT NULL DEFAULT true,
  CONSTRAINT tipo_asentamiento_clave_formato CHECK (clave ~ '^[A-Z0-9_]+$'),
  CONSTRAINT tipo_asentamiento_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

COMMENT ON TABLE catalogos.tipo_asentamiento
  IS 'Tipos de asentamiento/colonia (fuente: SEPOMEX)';

INSERT INTO catalogos.tipo_asentamiento (clave, nombre) VALUES
  ('COLONIA','Colonia'),
  ('FRACCIONAMIENTO','Fraccionamiento'),
  ('PUEBLO','Pueblo'),
  ('EJIDO','Ejido'),
  ('BARRIO','Barrio'),
  ('UNIDAD_HABITACIONAL','Unidad habitacional'),
  ('CONDOMINIO','Condominio'),
  ('RANCHERIA','Ranchería'),
  ('AMPLIACION','Ampliación'),
  ('ZONA_INDUSTRIAL','Zona industrial'),
  ('CONJUNTO_HABITACIONAL','Conjunto habitacional'),
  ('HACIENDA','Hacienda'),
  ('RESIDENCIAL','Residencial');

-- =============================================================
-- 4) Códigos postales (estructura; carga completa vía SEPOMEX)
-- =============================================================
CREATE TABLE catalogos.codigo_postal (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  municipio_id bigint NOT NULL REFERENCES catalogos.municipio (id),
  codigo     text   NOT NULL,
  activo     boolean NOT NULL DEFAULT true,
  CONSTRAINT codigo_postal_formato CHECK (codigo ~ '^[0-9]{5}$'),
  CONSTRAINT codigo_postal_municipio_uk UNIQUE (municipio_id, codigo)
);

COMMENT ON TABLE catalogos.codigo_postal
  IS 'Códigos postales de México (5 dígitos). Estructura lista; la carga completa se '
     'realiza desde el catálogo de Correos de México/SEPOMEX. Ver docs/carga-catalogos-domicilio.md';

CREATE INDEX codigo_postal_codigo_idx ON catalogos.codigo_postal (codigo);
CREATE INDEX codigo_postal_municipio_idx ON catalogos.codigo_postal (municipio_id);

-- =============================================================
-- 5) Asentamientos / colonias (estructura; carga completa vía SEPOMEX)
-- =============================================================
CREATE TABLE catalogos.asentamiento (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo_postal_id     bigint NOT NULL REFERENCES catalogos.codigo_postal (id),
  tipo_asentamiento_id smallint REFERENCES catalogos.tipo_asentamiento (id),
  nombre               text   NOT NULL,
  activo               boolean NOT NULL DEFAULT true,
  CONSTRAINT asentamiento_nombre_no_vacio CHECK (btrim(nombre) <> '')
);

COMMENT ON TABLE catalogos.asentamiento
  IS 'Colonias/asentamientos por código postal. Un CP puede tener varias colonias. '
     'Carga completa vía SEPOMEX. Ver docs/carga-catalogos-domicilio.md';

CREATE INDEX asentamiento_cp_idx ON catalogos.asentamiento (codigo_postal_id);
CREATE INDEX asentamiento_nombre_idx ON catalogos.asentamiento (nombre);

-- =============================================================
-- 6) Domicilio del declarante (nacional o extranjero)
-- =============================================================
CREATE TABLE patrimonial.domicilio (
  id                        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_domicilio            text    NOT NULL,
  -- Campos comunes
  calle                     text    NOT NULL,
  numero_exterior           text    NOT NULL,
  numero_interior           text,
  aclaraciones_observaciones text,
  -- México
  entidad_federativa_id     smallint REFERENCES catalogos.entidad_federativa (id),
  municipio_id              bigint   REFERENCES catalogos.municipio (id),
  codigo_postal             text,
  colonia_id                bigint   REFERENCES catalogos.asentamiento (id),
  -- Extranjero
  ciudad                    text,
  estado_region             text,
  codigo_postal_extranjero  text,
  pais_id                   smallint REFERENCES catalogos.pais (id),
  creado_en                 timestamptz NOT NULL DEFAULT now(),
  actualizado_en            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT domicilio_tipo_valido CHECK (tipo_domicilio IN ('MEXICO','EXTRANJERO')),
  -- México: campos obligatorios y exclusividad
  CONSTRAINT domicilio_mexico_campos CHECK (
    tipo_domicilio <> 'MEXICO' OR (
      entidad_federativa_id IS NOT NULL AND
      municipio_id IS NOT NULL AND
      codigo_postal IS NOT NULL AND codigo_postal ~ '^[0-9]{5}$' AND
      colonia_id IS NOT NULL AND
      ciudad IS NULL AND estado_region IS NULL AND
      codigo_postal_extranjero IS NULL AND pais_id IS NULL
    )
  ),
  -- Extranjero: campos obligatorios y exclusividad
  CONSTRAINT domicilio_extranjero_campos CHECK (
    tipo_domicilio <> 'EXTRANJERO' OR (
      ciudad IS NOT NULL AND
      pais_id IS NOT NULL AND
      entidad_federativa_id IS NULL AND municipio_id IS NULL AND
      codigo_postal IS NULL AND colonia_id IS NULL
    )
  )
);

COMMENT ON TABLE patrimonial.domicilio
  IS 'Domicilio del declarante: nacional (México) o extranjero. '
     'Conserva los datos del momento de presentación (historización por declaración). '
     'Incluye aclaraciones/observaciones (regla permanente).';

CREATE TRIGGER domicilio_marca_tiempo
  BEFORE UPDATE ON patrimonial.domicilio
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_marca_tiempo();

COMMIT;
