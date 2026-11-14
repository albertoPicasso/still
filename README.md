# Pipelines Drop

App de barra de menú para macOS que muestra un semáforo por entorno (por defecto DEV → `develop` y PRO → `main`) a partir de los workflows de GitHub Actions.

- Verde: libre. Ámbar: hay pipelines en marcha o en cola. Rojo: el último run de algún workflow falló (durante las horas configuradas).
- Pulsa en un pipeline para abrirlo en GitHub.

## Requisitos

- macOS 15 o superior
- Command Line Tools (`xcode-select --install`); no hace falta Xcode
- [GitHub CLI](https://cli.github.com) con sesión iniciada: `brew install gh` y `gh auth login`

La app usa la sesión de `gh` del ordenador; no guarda tokens propios.

## Instalar

```bash
./build.sh --install
```

Compila, copia la app a `/Applications` y la abre. Para solo compilar: `./build.sh` (deja la app en `build/`).

## Configurar

Abre el desplegable → **Ajustes**:

- **Perfiles**: cada perfil es una cuenta u organización con sus repos y entornos. Cambia de perfil desde el desplegable.
- **Entornos**: nombre, rama y, opcionalmente, un texto que debe contener el nombre del workflow (por ejemplo `PRODUCTION`).
- **Repos vigilados**: marca los repos que quieres seguir. Los repos nuevos no se añaden solos.
- **Preferencias**: frecuencia de consulta, cuántas horas se mantiene el rojo y abrir al iniciar sesión.

## Arquitectura (MVVM)

```
Sources/PipelinesDrop/
├── App/          Composición (AppContainer) y modos de diagnóstico
├── Models/       Profile, EnvStatus y los DTO de la API de GitHub
├── Services/
│   ├── Data/     GitHubClient, GhCLI, ProfileStore, AppPreferences (acceso a datos)
│   └── Domain/   StatusCalculator (lógica pura)
├── ViewModels/   StatusViewModel, SettingsViewModel, ProfileEditorViewModel, EnvPresentation
└── Views/        Popover/, Settings/, Shared/ (tema y ondas)
```

- Las vistas solo leen ViewModels (`@Observable`) y les mandan acciones.
- `StatusCalculator` es lógica pura: de runs de GitHub a estado del semáforo.
- Los servicios se inyectan por protocolo (`GitHubService`, `ProfilePersistence`), así que se pueden sustituir en tests.

## Tests

```bash
./test.sh
```

## Diagnóstico

```bash
build/PipelinesDrop.app/Contents/MacOS/PipelinesDrop --dump                      # estado del perfil activo
build/PipelinesDrop.app/Contents/MacOS/PipelinesDrop --dump <owner> <repo,repo>  # prueba sin tocar los perfiles
build/PipelinesDrop.app/Contents/MacOS/PipelinesDrop --snapshot <dir>            # PNG del desplegable y de Ajustes
```
