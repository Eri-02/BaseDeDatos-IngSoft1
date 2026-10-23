-- Marketplace de Alojamientos - Creación de tablas (PostgreSQL)


-- Catálogos simples (sin llaves foráneas)

CREATE TABLE rol (
    id_rol  SERIAL      PRIMARY KEY,
    nombre  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE estado_cuenta (
    id_estado_cuenta  SERIAL      PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE estado_publicacion (
    id_estado_publicacion  SERIAL      PRIMARY KEY,
    nombre                 VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE estado_reserva (
    id_estado_reserva  SERIAL      PRIMARY KEY,
    nombre             VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE estado_pago (
    id_estado_pago  SERIAL      PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE tipo_periodo (
    id_tipo_periodo  SERIAL      PRIMARY KEY,
    nombre           VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE accion_moderacion (
    id_accion_moderacion  SERIAL      PRIMARY KEY,
    nombre                VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE tipo_notificacion (
    id_tipo_notificacion  SERIAL      PRIMARY KEY,
    nombre                VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE resultado_auditoria (
    id_resultado_auditoria  SERIAL      PRIMARY KEY,
    nombre                  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE tipo_entidad (
    id_tipo_entidad  SERIAL      PRIMARY KEY,
    nombre           VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE departamento (
    id_departamento  SERIAL       PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE tipo_alojamiento (
    id_tipo_alojamiento  SERIAL      PRIMARY KEY,
    nombre               VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE servicio (
    id_servicio  SERIAL      PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE politica_cancelacion (
    id_politica_cancelacion  SERIAL       PRIMARY KEY,
    nombre                   VARCHAR(80)  NOT NULL UNIQUE,
    descripcion              VARCHAR(500) NOT NULL
);


-- Tablas que dependen de los catálogos

CREATE TABLE accion_auditoria (
    id_accion_auditoria  SERIAL      PRIMARY KEY,
    nombre               VARCHAR(80) NOT NULL UNIQUE,
    id_tipo_entidad      INTEGER     NOT NULL,
    FOREIGN KEY (id_tipo_entidad) REFERENCES tipo_entidad (id_tipo_entidad)
);

CREATE TABLE ciudad (
    id_ciudad        SERIAL       PRIMARY KEY,
    id_departamento  INTEGER      NOT NULL,
    nombre           VARCHAR(100) NOT NULL,
    UNIQUE (id_departamento, nombre),
    FOREIGN KEY (id_departamento) REFERENCES departamento (id_departamento)
);

CREATE TABLE regla_politica_cancelacion (
    id_regla_politica        SERIAL       PRIMARY KEY,
    id_politica_cancelacion  INTEGER      NOT NULL,
    dias_antes_minimo        INTEGER      NOT NULL,
    porcentaje_devolucion    NUMERIC(5,2) NOT NULL,
    UNIQUE (id_politica_cancelacion, dias_antes_minimo),
    FOREIGN KEY (id_politica_cancelacion) REFERENCES politica_cancelacion (id_politica_cancelacion)
);

CREATE TABLE usuario (
    id_usuario          SERIAL       PRIMARY KEY,
    primer_nombre       VARCHAR(60)  NOT NULL,
    segundo_nombre      VARCHAR(60),
    primer_apellido     VARCHAR(60)  NOT NULL,
    segundo_apellido    VARCHAR(60),
    correo_electronico  VARCHAR(150) NOT NULL UNIQUE,
    contrasena_cifrada  VARCHAR(255) NOT NULL,
    telefono            VARCHAR(30),
    id_rol              INTEGER      NOT NULL,
    id_estado_cuenta    INTEGER      NOT NULL,
    fecha_creacion      TIMESTAMP    NOT NULL,
    FOREIGN KEY (id_rol)           REFERENCES rol (id_rol),
    FOREIGN KEY (id_estado_cuenta) REFERENCES estado_cuenta (id_estado_cuenta)
);


-- Tablas que dependen de usuario

CREATE TABLE token_recuperacion (
    id_token_recuperacion  SERIAL       PRIMARY KEY,
    id_usuario             INTEGER      NOT NULL,
    codigo                 VARCHAR(255) NOT NULL UNIQUE,
    fecha_expiracion       TIMESTAMP    NOT NULL,
    usado                  BOOLEAN      NOT NULL,
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

CREATE TABLE parametro_configuracion (
    clave                VARCHAR(80)  PRIMARY KEY,
    valor                VARCHAR(200) NOT NULL,
    descripcion          VARCHAR(300) NOT NULL,
    fecha_actualizacion  TIMESTAMP    NOT NULL,
    actualizado_por      INTEGER      NOT NULL,
    FOREIGN KEY (actualizado_por) REFERENCES usuario (id_usuario)
);


-- Publicación

CREATE TABLE publicacion (
    id_publicacion           SERIAL        PRIMARY KEY,
    id_anfitrion             INTEGER       NOT NULL,
    id_tipo_alojamiento      INTEGER       NOT NULL,
    id_politica_cancelacion  INTEGER       NOT NULL,
    id_ciudad                INTEGER       NOT NULL,
    id_estado_publicacion    INTEGER       NOT NULL,
    titulo                   VARCHAR(150)  NOT NULL,
    descripcion              TEXT          NOT NULL,
    ubicacion_texto          VARCHAR(300)  NOT NULL,
    capacidad                INTEGER       NOT NULL,
    precio_noche             NUMERIC(12,2) NOT NULL,
    tarifa_limpieza          NUMERIC(12,2) NOT NULL,
    reserva_inmediata        BOOLEAN       NOT NULL,
    fecha_creacion           TIMESTAMP     NOT NULL,
    FOREIGN KEY (id_anfitrion)            REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_tipo_alojamiento)     REFERENCES tipo_alojamiento (id_tipo_alojamiento),
    FOREIGN KEY (id_politica_cancelacion) REFERENCES politica_cancelacion (id_politica_cancelacion),
    FOREIGN KEY (id_ciudad)               REFERENCES ciudad (id_ciudad),
    FOREIGN KEY (id_estado_publicacion)   REFERENCES estado_publicacion (id_estado_publicacion),
    -- HU-015 CA1/CA3 (RF-019): la tarifa de limpieza debe ser mayor o igual a 0 COP.
    CONSTRAINT chk_publicacion_tarifa_limpieza CHECK (tarifa_limpieza >= 0)
);


-- Tablas que dependen de publicación

-- Tabla intermedia
CREATE TABLE publicacion_servicio (
    id_publicacion  INTEGER NOT NULL,
    id_servicio     INTEGER NOT NULL,
    PRIMARY KEY (id_publicacion, id_servicio),
    FOREIGN KEY (id_publicacion) REFERENCES publicacion (id_publicacion),
    FOREIGN KEY (id_servicio)    REFERENCES servicio (id_servicio)
);

CREATE TABLE regla_alojamiento (
    id_regla_alojamiento  SERIAL       PRIMARY KEY,
    id_publicacion        INTEGER      NOT NULL,
    descripcion           VARCHAR(300) NOT NULL,
    FOREIGN KEY (id_publicacion) REFERENCES publicacion (id_publicacion)
);

CREATE TABLE imagen_alojamiento (
    id_imagen       SERIAL       PRIMARY KEY,
    id_publicacion  INTEGER      NOT NULL,
    ruta            VARCHAR(500) NOT NULL,
    orden           INTEGER      NOT NULL,
    es_principal    BOOLEAN      NOT NULL,
    UNIQUE (id_publicacion, orden),
    FOREIGN KEY (id_publicacion) REFERENCES publicacion (id_publicacion)
);

CREATE TABLE servicio_adicional (
    id_servicio_adicional  SERIAL        PRIMARY KEY,
    id_publicacion         INTEGER       NOT NULL,
    nombre                 VARCHAR(100)  NOT NULL,
    costo                  NUMERIC(12,2) NOT NULL,
    UNIQUE (id_publicacion, nombre),
    FOREIGN KEY (id_publicacion) REFERENCES publicacion (id_publicacion)
);

CREATE TABLE descuento (
    id_descuento    SERIAL       PRIMARY KEY,
    id_publicacion  INTEGER      NOT NULL,
    noches_minimas  INTEGER      NOT NULL,
    porcentaje      NUMERIC(5,2) NOT NULL,
    -- HU-015 CA2/CA3 (RF-019): descuento por estancia larga entre 0 % y 50 % desde al menos 1 noche.
    CONSTRAINT chk_descuento_noches_minimas CHECK (noches_minimas >= 1),
    CONSTRAINT chk_descuento_porcentaje     CHECK (porcentaje BETWEEN 0 AND 50),
    UNIQUE (id_publicacion, noches_minimas),
    FOREIGN KEY (id_publicacion) REFERENCES publicacion (id_publicacion)
);

CREATE TABLE periodo_disponibilidad (
    id_periodo       SERIAL  PRIMARY KEY,
    id_publicacion   INTEGER NOT NULL,
    id_tipo_periodo  INTEGER NOT NULL,
    fecha_inicio     DATE    NOT NULL,
    fecha_fin        DATE    NOT NULL,
    FOREIGN KEY (id_publicacion)  REFERENCES publicacion (id_publicacion),
    FOREIGN KEY (id_tipo_periodo) REFERENCES tipo_periodo (id_tipo_periodo)
);


-- Reserva

CREATE TABLE reserva (
    id_reserva               SERIAL        PRIMARY KEY,
    id_huesped               INTEGER       NOT NULL,
    id_publicacion           INTEGER       NOT NULL,
    id_politica_cancelacion  INTEGER       NOT NULL,
    id_estado_reserva        INTEGER       NOT NULL,
    fecha_llegada            DATE          NOT NULL,
    fecha_salida             DATE          NOT NULL,
    numero_huespedes         INTEGER       NOT NULL,
    precio_base              NUMERIC(12,2) NOT NULL,
    tarifa_limpieza          NUMERIC(12,2) NOT NULL,
    tarifa_servicio          NUMERIC(12,2) NOT NULL,
    descuento                NUMERIC(12,2) NOT NULL,
    total                    NUMERIC(12,2) NOT NULL,
    clave_idempotencia       VARCHAR(100)  NOT NULL UNIQUE,
    fecha_creacion           TIMESTAMP     NOT NULL,
    FOREIGN KEY (id_huesped)              REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_publicacion)          REFERENCES publicacion (id_publicacion),
    FOREIGN KEY (id_politica_cancelacion) REFERENCES politica_cancelacion (id_politica_cancelacion),
    FOREIGN KEY (id_estado_reserva)       REFERENCES estado_reserva (id_estado_reserva)
);


-- Tablas que dependen de reserva (y del resto)

-- Tabla intermedia
CREATE TABLE reserva_servicio_adicional (
    id_reserva             INTEGER       NOT NULL,
    id_servicio_adicional  INTEGER       NOT NULL,
    cantidad               INTEGER       NOT NULL,
    costo_aplicado         NUMERIC(12,2) NOT NULL,
    PRIMARY KEY (id_reserva, id_servicio_adicional),
    FOREIGN KEY (id_reserva)            REFERENCES reserva (id_reserva),
    FOREIGN KEY (id_servicio_adicional) REFERENCES servicio_adicional (id_servicio_adicional)
);

CREATE TABLE historial_estado_reserva (
    id_historial        SERIAL    PRIMARY KEY,
    id_reserva          INTEGER   NOT NULL,
    id_usuario          INTEGER   NOT NULL,
    id_estado_anterior  INTEGER,
    id_estado_nuevo     INTEGER   NOT NULL,
    fecha               TIMESTAMP NOT NULL,
    FOREIGN KEY (id_reserva)         REFERENCES reserva (id_reserva),
    FOREIGN KEY (id_usuario)         REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_estado_anterior) REFERENCES estado_reserva (id_estado_reserva),
    FOREIGN KEY (id_estado_nuevo)    REFERENCES estado_reserva (id_estado_reserva)
);

CREATE TABLE pago (
    id_pago                     SERIAL        PRIMARY KEY,
    id_reserva                  INTEGER       NOT NULL,
    id_estado_pago              INTEGER       NOT NULL,
    identificador_pago_externo  VARCHAR(120)  NOT NULL UNIQUE,
    monto                       NUMERIC(12,2) NOT NULL,
    fecha                       TIMESTAMP     NOT NULL,
    FOREIGN KEY (id_reserva)     REFERENCES reserva (id_reserva),
    FOREIGN KEY (id_estado_pago) REFERENCES estado_pago (id_estado_pago)
);

CREATE TABLE cancelacion (
    id_cancelacion    SERIAL        PRIMARY KEY,
    id_reserva        INTEGER       NOT NULL UNIQUE,
    id_usuario        INTEGER       NOT NULL,
    id_estado_final   INTEGER       NOT NULL,
    fecha             TIMESTAMP     NOT NULL,
    motivo            VARCHAR(500)  NOT NULL,
    valor_devolucion  NUMERIC(12,2) NOT NULL,
    FOREIGN KEY (id_reserva)      REFERENCES reserva (id_reserva),
    FOREIGN KEY (id_usuario)      REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_estado_final) REFERENCES estado_reserva (id_estado_reserva)
);

CREATE TABLE resena (
    id_resena     SERIAL        PRIMARY KEY,
    id_reserva    INTEGER       NOT NULL UNIQUE,
    calificacion  INTEGER       NOT NULL,
    comentario    VARCHAR(2000),
    fecha         TIMESTAMP     NOT NULL,
    visible       BOOLEAN       NOT NULL,
    FOREIGN KEY (id_reserva) REFERENCES reserva (id_reserva)
);

CREATE TABLE notificacion (
    id_notificacion       SERIAL       PRIMARY KEY,
    id_usuario            INTEGER      NOT NULL,
    id_tipo_notificacion  INTEGER      NOT NULL,
    mensaje               VARCHAR(500) NOT NULL,
    leida                 BOOLEAN      NOT NULL,
    fecha                 TIMESTAMP    NOT NULL,
    FOREIGN KEY (id_usuario)           REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_tipo_notificacion) REFERENCES tipo_notificacion (id_tipo_notificacion)
);

CREATE TABLE moderacion_publicacion (
    id_moderacion         SERIAL       PRIMARY KEY,
    id_publicacion        INTEGER      NOT NULL,
    id_administrador      INTEGER      NOT NULL,
    id_accion_moderacion  INTEGER      NOT NULL,
    motivo                VARCHAR(500) NOT NULL,
    fecha                 TIMESTAMP    NOT NULL,
    FOREIGN KEY (id_publicacion)       REFERENCES publicacion (id_publicacion),
    FOREIGN KEY (id_administrador)     REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_accion_moderacion) REFERENCES accion_moderacion (id_accion_moderacion)
);

-- id_entidad_afectada no tiene llave foránea: apunta a distintas tablas
CREATE TABLE evento_auditoria (
    id_evento               SERIAL    PRIMARY KEY,
    id_usuario_actor        INTEGER,
    id_accion_auditoria     INTEGER   NOT NULL,
    id_resultado_auditoria  INTEGER   NOT NULL,
    id_entidad_afectada     INTEGER,
    detalle                 TEXT,
    fecha                   TIMESTAMP NOT NULL,
    FOREIGN KEY (id_usuario_actor)       REFERENCES usuario (id_usuario),
    FOREIGN KEY (id_accion_auditoria)    REFERENCES accion_auditoria (id_accion_auditoria),
    FOREIGN KEY (id_resultado_auditoria) REFERENCES resultado_auditoria (id_resultado_auditoria)
);
