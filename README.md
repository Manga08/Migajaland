# Migajaland

Repositorio oficial de archivos y actualizaciones de **Migajaland**.

## Pasar Migajaland a otro computador

La carpeta [`migracion-portatil`](migracion-portatil/) contiene una herramienta
para trasladar una instalación personal de Migajaland entre dos computadores sin
publicar datos privados en Internet.

Conserva:

- mods y actualizador automático;
- controles, gráficos, audio y distancia de renderizado;
- shaders y sus ajustes;
- mapas y waypoints de JourneyMap;
- skins locales de Quick Skin;
- emotes, resource packs e imágenes de Immersive Paintings;
- servidores guardados, capturas y mundos individuales.

El inventario, posición, niveles, habilidades, accesorios, misiones y homes del
servidor no se copian porque ya están guardados en el servidor de Migajaland.

### Resumen rápido

1. Descarga este repositorio desde **Code > Download ZIP** y descomprímelo en el
   computador donde ya juegas.
2. Cierra Minecraft y Freesm Launcher.
3. Abre `migracion-portatil\1-EXPORTAR-MIGAJALAND.bat`.
4. Pasa el ZIP generado al portátil mediante USB o almacenamiento privado.
5. Instala y abre Freesm Launcher una vez en el portátil; después ciérralo.
6. Coloca el ZIP junto a `2-INSTALAR-EN-PORTATIL.bat` y ejecuta el BAT.
7. Abre Freesm, crea o selecciona el usuario **Manga** y juega.

Lee las [instrucciones completas](migracion-portatil/README.md) antes de comenzar.

> El ZIP de migración contiene información personal, mapas, waypoints, skins y
> mundos. No lo publiques en GitHub ni lo compartas con otras personas.

## Actualizaciones

La instancia utiliza Unsup + Packwiz. Al iniciar Migajaland, Unsup comprueba el
canal oficial y descarga las actualizaciones necesarias antes de abrir Minecraft.
Los ajustes personales como `options.txt` y `servers.dat` se conservan.

