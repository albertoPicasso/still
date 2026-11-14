<p align="center"><img src="Assets/icon.png" alt="still." width="128"></p>

# still.

App de barra de menú para macOS que muestra un semáforo por entorno (por defecto DEV → `develop` y PRO → `main`) a partir de los workflows de GitHub Actions.

- Verde: libre. Ámbar: hay pipelines en marcha o en cola. Rojo: el último run de algún workflow falló (durante las horas configuradas).
- Pulsa en un pipeline para abrirlo en GitHub.

## Requisitos

- macOS 15 o superior
- Command Line Tools (`xcode-select --install`); no hace falta Xcode
- [GitHub CLI](https://cli.github.com) con sesión iniciada: `brew install gh` y `gh auth login`

**Still necesita que `gh` esté configurado**: instalado y con la sesión iniciada. Comprueba que `gh auth status` muestra tu cuenta. La app detecta esa sesión sola y la usa para leer tus pipelines; sin ella no verá nada. No guarda tokens propios.

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
