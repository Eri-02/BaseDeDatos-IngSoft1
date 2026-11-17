# Base de Datos — Marketplace de Alojamientos (Inversiones LR / StayHub)

Modelo relacional en **PostgreSQL 16** del marketplace de alojamientos: tablas, relaciones, restricciones y triggers con las reglas de negocio. Incluye un `docker-compose.yml` para levantar la base localmente y cargar el esquema automáticamente.

> **Relación con la aplicación.** La API ([stayhub-api](https://github.com/Malzap12/stayhub-api)) **no usa este esquema en ejecución**: crea y mantiene sus propias tablas en el esquema `stayhub` mediante migraciones de TypeORM al arrancar. Este repositorio documenta el modelo de datos de diseño del proyecto y sus reglas a nivel de base de datos. El despliegue de la aplicación (`stayhub-api/deploy/`) no monta estos scripts.

## Contenido

```
docker-compose.yml        PostgreSQL 16 con carga automática de db/init
.env.example              Variables de la base (usuario, contraseña, nombre)
db/init/
├── 01_tablas.sql         Tablas, llaves, índices y restricciones CHECK (esquema public)
└── 02_triggers.sql       Funciones y triggers con reglas de negocio
```

## Ejecución local

Requiere Docker y Docker Compose.

```bash
cp .env.example .env      # define DB_USER, DB_PASSWORD y DB_NAME (no dejes "cambiar")
docker compose up -d
```

- La base queda en `localhost:5432` (contenedor `postgres-dev`).
- En el **primer arranque**, PostgreSQL ejecuta en orden alfabético los scripts de `db/init/` (`01_tablas.sql` y luego `02_triggers.sql`).

Conectarse con `psql`:

```bash
docker compose exec db psql -U "$DB_USER" -d "$DB_NAME"
\dt                       -- listar tablas
\df                       -- listar funciones
```

**Volver a cargar los scripts.** PostgreSQL solo ejecuta `docker-entrypoint-initdb.d` cuando el volumen está vacío. Si cambias un `.sql`, recrea el volumen (esto **borra los datos**):

```bash
docker compose down -v
docker compose up -d
```

**Conflicto de puerto.** Si el puerto 5432 está ocupado (por ejemplo, por el compose de desarrollo de la API), detén el otro contenedor o cambia el mapeo de puertos a `"5433:5432"`.

## Modelo de datos

El script crea 36 tablas en el esquema `public`, con llaves `SERIAL`.

### Catálogos

| Tabla | Contenido |
|---|---|
| `rol` | Roles: huésped, anfitrión, administrador |
| `estado_cuenta`, `estado_publicacion`, `estado_reserva`, `estado_pago` | Estados de cada entidad |
| `tipo_periodo`, `tipo_alojamiento`, `tipo_notificacion`, `tipo_entidad` | Tipos |
| `accion_moderacion`, `accion_auditoria`, `resultado_auditoria` | Valores de moderación y auditoría |
| `departamento`, `ciudad` | Ubicación geográfica |
| `servicio` | Servicios / amenidades |
| `politica_cancelacion`, `regla_politica_cancelacion` | Políticas de cancelación y sus tramos de reembolso |

### Usuarios y configuración

| Tabla | Contenido |
|---|---|
| `usuario` | Cuentas, con rol y estado |
| `token_recuperacion` | Tokens de recuperación de contraseña |
| `parametro_configuracion` | Parámetros de la plataforma (por ejemplo, la comisión) |

### Publicaciones

| Tabla | Contenido |
|---|---|
| `publicacion` | Alojamiento: anfitrión, ciudad, tipo, capacidad, precios y estado |
| `publicacion_servicio` | Servicios del alojamiento (N:M) |
| `regla_alojamiento` | Reglas de la casa |
| `imagen_alojamiento` | Imágenes |
| `servicio_adicional` | Servicios con costo adicional |
| `descuento` | Descuentos (por ejemplo, por estancia larga) |
| `periodo_disponibilidad` | Periodos disponibles o bloqueados |
| `moderacion_publicacion` | Decisiones de moderación del administrador |

### Reservas y operación

| Tabla | Contenido |
|---|---|
| `reserva` | Reserva: huésped, publicación, fechas, huéspedes, valores y estado |
| `reserva_servicio_adicional` | Servicios adicionales contratados en la reserva |
| `historial_estado_reserva` | Cambios de estado de la reserva |
| `pago` | Pagos |
| `cancelacion` | Cancelaciones y reembolsos |
| `resena` | Reseñas de estancias |
| `notificacion` | Notificaciones a los usuarios |
| `evento_auditoria` | Bitácora de auditoría |

## Reglas de negocio (triggers)

Definidas en `db/init/02_triggers.sql`:

| Trigger | Tabla | Regla |
|---|---|---|
| `trg_publicacion_anfitrion` | `publicacion` | Solo un usuario con rol `ANFITRION` puede ser dueño de una publicación |
| `trg_publicacion_activacion` | `publicacion` | Para pasar a `ACTIVA`, la publicación debe tener al menos una imagen, un servicio y una regla |
| `trg_publicacion_bloqueo` | `publicacion` | Al bloquear una publicación, sus reservas futuras pasan a `EN_REVISION_MANUAL` |
| `trg_reserva_validar` | `reserva` | Al crear o confirmar: solo un `HUESPED` reserva, solo en publicaciones `ACTIVA`, sin superar la capacidad, dentro de un periodo disponible, sin cruzarse con periodos bloqueados ni con otras reservas |
| `trg_resena_validar` | `resena` | Solo se puede reseñar una reserva `COMPLETADA` |
| `trg_politica_inmutable`, `trg_regla_politica_inmutable` | `politica_cancelacion`, `regla_politica_cancelacion` | Las políticas de cancelación no se pueden modificar ni borrar |

> **Datos iniciales.** Los scripts no insertan filas en los catálogos. Los triggers buscan valores por nombre (por ejemplo `'ANFITRION'`, `'ACTIVA'`, `'BLOQUEADA'`, `'EN_REVISION_MANUAL'`, `'DISPONIBLE'`, `'COMPLETADA'`). Antes de insertar publicaciones o reservas, carga esos valores en `rol`, `estado_publicacion`, `estado_reserva`, `tipo_periodo` y las demás tablas de catálogo.

## Flujo de trabajo

- No se hace push directo a `main`. Cada cambio va en una rama `feature/HU-XXX-...`, `feature/TA-XX-...` o `fix/...` con un Pull Request.
- Los commits siguen Conventional Commits con el ID de Jira, por ejemplo `feat(HU-015): ... (CA3)`.
- Cada cambio al esquema se agrega a `db/init/` y se verifica recreando el volumen (`docker compose down -v && docker compose up -d`).
