# Migrar Migajaland a un portátil

Esta herramienta crea una copia portátil de la instancia personal de Migajaland.
No descarga una configuración genérica: traslada los archivos de la instalación
que ya utilizas para que el resultado sea lo más idéntico posible.

## Qué necesitas

- El computador en el que Migajaland ya funciona.
- El portátil de destino con Windows.
- Freesm Launcher instalado en ambos equipos.
- Espacio suficiente para el archivo de migración. JourneyMap ocupa alrededor de
  915 MB en la instalación actual, por lo que el proceso puede tardar varios
  minutos.
- Una memoria USB, disco externo o nube privada para trasladar el ZIP.

## Parte 1: crear la copia en el computador actual

1. Cierra Minecraft y Freesm Launcher completamente.
2. Ejecuta `1-EXPORTAR-MIGAJALAND.bat`.
3. El programa buscará las instancias de Migajaland instaladas en Freesm. Si hay
   más de una, mostrará una lista para elegir.
4. Espera hasta que indique que terminó. En el mismo directorio aparecerán:
   - `Migajaland-Copia-Personal-AAAA-MM-DD_HH-mm-ss.zip`
   - el mismo nombre terminado en `.sha256.txt`
5. Conserva ambos archivos juntos y pásalos al portátil.

El exportador excluye solamente archivos prescindibles: registros, reportes de
errores, descargas temporales y copias antiguas del actualizador. No modifica la
instancia original.

## Parte 2: instalar la copia en el portátil

1. Instala Freesm Launcher.
2. Ábrelo una vez para que cree sus carpetas y después ciérralo completamente.
3. Copia a una misma carpeta:
   - `2-INSTALAR-EN-PORTATIL.bat`;
   - `Instalar-Copia-Migajaland.ps1`;
   - el ZIP personal creado en el primer computador;
   - su archivo `.sha256.txt`.
4. Ejecuta `2-INSTALAR-EN-PORTATIL.bat`. También puedes arrastrar el ZIP sobre
   este BAT.
5. El instalador verifica el SHA-256 cuando encuentra el archivo correspondiente.
6. La nueva instancia se instala como `Migajaland-Portatil`. Si ya existe una
   instancia con ese nombre, el instalador se detendrá sin sobrescribirla.
7. La herramienta elimina la ruta de Java del computador anterior y deja que
   Freesm seleccione Java 21 automáticamente.
8. La memoria queda ajustada automáticamente:
   - menos de 12 GB de RAM física: máximo 4 GB para Minecraft;
   - 12 GB o más: máximo 6 GB para Minecraft.
9. Abre Freesm y selecciona `Migajaland-Portatil`.

## Cuenta que debes utilizar

En el portátil debes agregar la misma clase de cuenta y utilizar el nombre
exactamente como en el computador original:

```text
Manga
```

Respeta la mayúscula inicial. En modo offline, cambiar una sola letra cambia el
UUID y el servidor podría tratarte como un jugador diferente.

La cuenta del launcher no se copia deliberadamente: sus credenciales pertenecen
al almacenamiento global de Freesm y no deben guardarse dentro del ZIP.

Al entrar al servidor utiliza la misma contraseña existente:

```text
/login TuContraseña
```

No vuelvas a utilizar `/register` si estás entrando con el mismo nombre.

## Qué queda guardado en el servidor

No necesitas trasladar manualmente:

- inventario y ender chest;
- posición y punto de aparición;
- experiencia, habilidades y árbol de la tecla K;
- accesorios y equipamiento;
- progreso de misiones y logros;
- homes, equipos y demás datos multijugador.

Esos datos reaparecen cuando el servidor reconoce el mismo usuario/UUID.

## Privacidad

El ZIP personal puede contener coordenadas de bases, waypoints, capturas,
mundos, skins y direcciones de servidores. No debe subirse a este repositorio ni
publicarse como un Release. Usa una memoria USB o un enlace privado.

## Si la instancia no aparece

Comprueba que la carpeta resultante sea:

```text
%APPDATA%\FreesmLauncher\instances\Migajaland-Portatil
```

Dentro deben existir `instance.cfg`, `mmc-pack.json` y la carpeta `minecraft`.
Después cierra completamente Freesm y vuelve a abrirlo.

