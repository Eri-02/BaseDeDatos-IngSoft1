-- Marketplace de Alojamientos - Triggers (PostgreSQL)
-- Ejecutar después de crear_tablas.sql


-- Solo un ANFITRION puede ser dueño de una publicación

CREATE OR REPLACE FUNCTION fn_validar_anfitrion_publicacion()
RETURNS TRIGGER AS $$
DECLARE
    v_rol VARCHAR(50);
BEGIN
    SELECT r.nombre INTO v_rol
    FROM usuario u
    JOIN rol r ON r.id_rol = u.id_rol
    WHERE u.id_usuario = NEW.id_anfitrion;

    IF v_rol IS DISTINCT FROM 'ANFITRION' THEN
        RAISE EXCEPTION 'Solo un usuario con rol ANFITRION puede ser dueño de una publicación';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_publicacion_anfitrion
BEFORE INSERT OR UPDATE OF id_anfitrion ON publicacion
FOR EACH ROW EXECUTE FUNCTION fn_validar_anfitrion_publicacion();


-- Para activar una publicación debe tener imagen, servicio y regla

CREATE OR REPLACE FUNCTION fn_validar_activacion_publicacion()
RETURNS TRIGGER AS $$
DECLARE
    v_estado VARCHAR(50);
BEGIN
    SELECT nombre INTO v_estado
    FROM estado_publicacion
    WHERE id_estado_publicacion = NEW.id_estado_publicacion;

    IF v_estado = 'ACTIVA' THEN
        IF NOT EXISTS (SELECT 1 FROM imagen_alojamiento
                       WHERE id_publicacion = NEW.id_publicacion) THEN
            RAISE EXCEPTION 'No se puede activar: la publicación necesita al menos una imagen';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM publicacion_servicio
                       WHERE id_publicacion = NEW.id_publicacion) THEN
            RAISE EXCEPTION 'No se puede activar: la publicación necesita al menos un servicio';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM regla_alojamiento
                       WHERE id_publicacion = NEW.id_publicacion) THEN
            RAISE EXCEPTION 'No se puede activar: la publicación necesita al menos una regla del alojamiento';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_publicacion_activacion
BEFORE INSERT OR UPDATE OF id_estado_publicacion ON publicacion
FOR EACH ROW EXECUTE FUNCTION fn_validar_activacion_publicacion();


-- Al bloquear una publicación, sus reservas futuras pasan a EN_REVISION_MANUAL

CREATE OR REPLACE FUNCTION fn_bloqueo_publicacion()
RETURNS TRIGGER AS $$
DECLARE
    v_estado VARCHAR(50);
BEGIN
    SELECT nombre INTO v_estado
    FROM estado_publicacion
    WHERE id_estado_publicacion = NEW.id_estado_publicacion;

    IF v_estado = 'BLOQUEADA' THEN
        UPDATE reserva
        SET id_estado_reserva = (SELECT id_estado_reserva
                                 FROM estado_reserva
                                 WHERE nombre = 'EN_REVISION_MANUAL')
        WHERE id_publicacion = NEW.id_publicacion
          AND fecha_llegada >= CURRENT_DATE
          AND id_estado_reserva IN (SELECT id_estado_reserva
                                    FROM estado_reserva
                                    WHERE nombre IN ('PENDIENTE_PAGO',
                                                     'CONFIRMADA',
                                                     'PENDIENTE_APROBACION'));
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_publicacion_bloqueo
AFTER UPDATE OF id_estado_publicacion ON publicacion
FOR EACH ROW
WHEN (OLD.id_estado_publicacion IS DISTINCT FROM NEW.id_estado_publicacion)
EXECUTE FUNCTION fn_bloqueo_publicacion();


-- Validaciones de la reserva (al crear y al confirmar)

CREATE OR REPLACE FUNCTION fn_validar_reserva()
RETURNS TRIGGER AS $$
DECLARE
    v_rol            VARCHAR(50);
    v_estado_pub     VARCHAR(50);
    v_capacidad      INTEGER;
    v_estado_reserva VARCHAR(50);
BEGIN
    -- Bloquea la publicación para que reservas simultáneas se verifiquen una a la vez
    PERFORM 1 FROM publicacion WHERE id_publicacion = NEW.id_publicacion FOR UPDATE;

    SELECT nombre INTO v_estado_reserva
    FROM estado_reserva
    WHERE id_estado_reserva = NEW.id_estado_reserva;

    IF TG_OP = 'INSERT' THEN
        SELECT r.nombre INTO v_rol
        FROM usuario u
        JOIN rol r ON r.id_rol = u.id_rol
        WHERE u.id_usuario = NEW.id_huesped;

        IF v_rol IS DISTINCT FROM 'HUESPED' THEN
            RAISE EXCEPTION 'Solo un usuario con rol HUESPED puede crear una reserva';
        END IF;

        SELECT ep.nombre, p.capacidad INTO v_estado_pub, v_capacidad
        FROM publicacion p
        JOIN estado_publicacion ep ON ep.id_estado_publicacion = p.id_estado_publicacion
        WHERE p.id_publicacion = NEW.id_publicacion;

        IF v_estado_pub IS DISTINCT FROM 'ACTIVA' THEN
            RAISE EXCEPTION 'Solo las publicaciones ACTIVAS pueden recibir reservas';
        END IF;

        IF NEW.numero_huespedes > v_capacidad THEN
            RAISE EXCEPTION 'El número de huéspedes (%) supera la capacidad de la publicación (%)',
                NEW.numero_huespedes, v_capacidad;
        END IF;

        -- Disponibilidad
        IF v_estado_reserva <> 'CANCELADA' THEN
            IF NOT EXISTS (SELECT 1
                           FROM periodo_disponibilidad pd
                           JOIN tipo_periodo tp ON tp.id_tipo_periodo = pd.id_tipo_periodo
                           WHERE pd.id_publicacion = NEW.id_publicacion
                             AND tp.nombre = 'DISPONIBLE'
                             AND pd.fecha_inicio <= NEW.fecha_llegada
                             AND pd.fecha_fin    >= NEW.fecha_salida) THEN
                RAISE EXCEPTION 'Las fechas solicitadas no están dentro de un periodo disponible';
            END IF;

            IF EXISTS (SELECT 1
                       FROM periodo_disponibilidad pd
                       JOIN tipo_periodo tp ON tp.id_tipo_periodo = pd.id_tipo_periodo
                       WHERE pd.id_publicacion = NEW.id_publicacion
                         AND tp.nombre = 'BLOQUEADO'
                         AND pd.fecha_inicio < NEW.fecha_salida
                         AND pd.fecha_fin    > NEW.fecha_llegada) THEN
                RAISE EXCEPTION 'Las fechas solicitadas se cruzan con un periodo bloqueado por el anfitrión';
            END IF;
        END IF;
    END IF;

    -- Reservas superpuestas
    IF v_estado_reserva <> 'CANCELADA' THEN
        IF EXISTS (SELECT 1
                   FROM reserva r
                   JOIN estado_reserva er ON er.id_estado_reserva = r.id_estado_reserva
                   WHERE r.id_publicacion = NEW.id_publicacion
                     AND r.id_reserva <> NEW.id_reserva
                     AND er.nombre <> 'CANCELADA'
                     AND NEW.fecha_llegada < r.fecha_salida
                     AND NEW.fecha_salida  > r.fecha_llegada) THEN
            RAISE EXCEPTION 'Ya existe una reserva para este alojamiento que se cruza con esas fechas';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reserva_validar
BEFORE INSERT OR UPDATE OF id_estado_reserva, fecha_llegada, fecha_salida, id_publicacion ON reserva
FOR EACH ROW EXECUTE FUNCTION fn_validar_reserva();


-- Solo se puede reseñar una reserva COMPLETADA

CREATE OR REPLACE FUNCTION fn_validar_resena()
RETURNS TRIGGER AS $$
DECLARE
    v_estado VARCHAR(50);
BEGIN
    SELECT er.nombre INTO v_estado
    FROM reserva r
    JOIN estado_reserva er ON er.id_estado_reserva = r.id_estado_reserva
    WHERE r.id_reserva = NEW.id_reserva;

    IF v_estado IS DISTINCT FROM 'COMPLETADA' THEN
        RAISE EXCEPTION 'Solo se puede reseñar una reserva en estado COMPLETADA';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resena_validar
BEFORE INSERT ON resena
FOR EACH ROW EXECUTE FUNCTION fn_validar_resena();


-- Las políticas de cancelación no se modifican ni se borran

CREATE OR REPLACE FUNCTION fn_bloquear_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'La tabla % no se puede modificar ni borrar: cree una política nueva', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_politica_inmutable
BEFORE UPDATE OR DELETE ON politica_cancelacion
FOR EACH ROW EXECUTE FUNCTION fn_bloquear_modificacion();

CREATE TRIGGER trg_regla_politica_inmutable
BEFORE UPDATE OR DELETE ON regla_politica_cancelacion
FOR EACH ROW EXECUTE FUNCTION fn_bloquear_modificacion();
