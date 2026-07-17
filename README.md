# Sentinel

**Sentinel** es una aplicación de gamificación de productividad diseñada para supervisores y sus equipos. Permite asignar tareas con puntos, gestionar evidencias, mantener rachas de productividad y canjear recompensas.

## Características

### Gestión de usuarios y roles
- **Registro con roles**: los usuarios se registran como **Supervisor** o **Usuario**
- **Perfiles múltiples**: una misma persona puede tener ambos roles (máx. 2 por cuenta)
- **Vinculación por invitación**: el supervisor invita usuarios por email; el usuario acepta o rechaza
- **Selector de perfil**: al iniciar sesión con múltiples perfiles, se elige cuál usar; se puede cambiar desde el AppBar o la pantalla de perfil

### Tareas y evidencias
- **Asignación de tareas**: el supervisor crea tareas con puntos, descripción opcional y fecha límite
- **4 estados**: pendiente → evidencia subida → completada | rechazada
- **Subida de evidencias**: el usuario sube texto, imagen o documento como evidencia de cumplimiento
- **Aprobación/Rechazo**: el supervisor revisa y aprueba o rechaza con comentario
- **Reenvío**: si es rechazada, el usuario puede reenviar evidencia

### Gamificación
- **Puntos**: cada tarea completada otorga puntos; se descuentan al canjear recompensas
- **Racha (Streak)**: cuenta los días consecutivos con tareas completadas; al completar una tarea antes de su fecha límite, la racha avanza hasta esa fecha
- **Recompensas**: el supervisor crea recompensas asignadas a usuarios específicos; el usuario las canjea con sus puntos
- **Canje**: verificación de puntos suficientes y duplicados

### Visualización
- **Dashboard supervisor**: header con stats (tareas, pendientes, usuarios), búsqueda y filtro de tareas, cards expandibles por usuario
- **Dashboard usuario**: header con puntos y racha, cards de tareas con 4 comportamientos según estado
- **Calendario**: vista mensual con indicadores visuales por día (completadas/pendientes), lista de tareas agrupadas por fecha
- **Perfil**: avatar, puntos, racha, supervisor asignado, modo oscuro, selector de perfiles

### UX/UI
- **Tema claro/oscuro** con paleta de colores moderna (Material 3)
- **Shimmer loading** en listas de tareas
- **Pull-to-refresh** en dashboards
- **Feedback háptico** en acciones clave
- **Animaciones** en cards y botones
- **Validación** en todos los formularios

## Tecnologías

- **Flutter** (Windows Desktop)
- **Supabase** (autenticación, base de datos PostgreSQL, storage)
- **Riverpod** (gestión de estado)
- **GoRouter** (navegación)
- **FilePicker** (subida de archivos)

## Estructura del proyecto

```
lib/
├── core/
│   └── constants.dart          # Enums (EstadoTarea, TipoEvidencia)
├── models/
│   ├── usuario.dart
│   ├── tarea.dart
│   ├── evidencia.dart
│   ├── recompensa.dart
│   ├── canje.dart
│   └── invitacion.dart
├── providers/
│   ├── auth_provider.dart      # currentUserProvider, perfilesProvider, etc.
│   ├── tareas_provider.dart    # tareasUsuarioProvider, tareasSupervisorProvider
│   ├── usuarios_provider.dart  # usuariosSupervisionProvider
│   ├── puntos_provider.dart    # recompensasProvider, canjesProvider
│   ├── invitaciones_provider.dart
│   └── theme_provider.dart     # themeModeProvider
├── services/
│   └── supabase_service.dart   # Lógica de negocio y comunicación con Supabase
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── registro_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── perfil/
│   │   └── perfil_screen.dart
│   ├── tareas/
│   │   ├── tarea_form_screen.dart
│   │   └── tarea_detail_screen.dart
│   ├── evidencias/
│   │   └── evidencia_form_screen.dart
│   └── gamificacion/
│       ├── recompensa_form_screen.dart
│       ├── recompensa_list_screen.dart
│       └── calendario_screen.dart
├── widgets/
│   └── shimmer_loading.dart
└── main.dart                   # Configuración, tema y rutas
```

## Base de datos

El esquema está en `database/schema.sql` e incluye:

- **`usuarios`**: perfiles con auth_user_id, rol, puntos, racha
- **`tareas`**: tareas asignadas con estados y fecha límite
- **`evidencias`**: archivos/texto subidos como evidencia
- **`recompensas`**: premios creados por el supervisor (por usuario)
- **`canjes`**: registro de canjes de recompensas
- **`invitaciones`**: invitaciones pendientes de supervisor a usuario
- **`movimientos_puntos`**: auto-log por triggers (aprobación y canje)
- **RLS**: políticas de seguridad con funciones SECURITY DEFINER

## Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/MiguelAguir/Sentinel.git
   cd Sentinel
   ```

2. Crea un archivo `.env` en la raíz con:
   ```
   SUPABASE_URL=tu_url
   SUPABASE_ANON_KEY=tu_anon_key
   ```

3. Ejecuta el esquema SQL en tu proyecto de Supabase:
   ```bash
   database/schema.sql
   ```

4. Instala dependencias y ejecuta:
   ```bash
   flutter pub get
   flutter run
   ```

## Licencia

MIT
