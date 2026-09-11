# Registro de módulos extra

Este documento describe todos los elementos instalables que aparecen en los menús destinados al modelo `K1`, que es el flujo que usaremos como base para la K1C con firmware CFS.

El menú principal separa las opciones en `Install`, `Remove`, `Customize`, `Backup & Restore`, `Tools`, `Information` y `System`. Este registro se centra en los 24 módulos de `Install` y los 3 componentes instalables de `Customize`, porque son los elementos que debemos decidir conservar, adaptar o retirar.

## Estados de decisión

- `PENDIENTE`: aún no hemos decidido si se conserva, adapta o elimina.
- `CONSERVAR`: aprobado para permanecer en el proyecto.
- `ELIMINAR`: se ha decidido retirarlo.
- `REEMPLAZAR`: se retirará y tendrá un sustituto definido.

## Menú `Install` — `ESSENTIALS`

### 1. Moonraker y Nginx — `PENDIENTE`

Script: `scripts/moonraker_nginx.sh`. Instala y configura Moonraker, que proporciona la API y los servicios de control de Klipper, junto con Nginx, que sirve las interfaces web y actúa como servidor HTTP para la impresora. Es la base de Fluidd, Mainsail y varias integraciones remotas, por lo que cualquier cambio en este módulo debe revisarse antes de modificar los demás instaladores.

### 2. Fluidd — `PENDIENTE`

Script: `scripts/fluidd.sh`. Instala la interfaz web Fluidd y la publica en el puerto `4408`, permitiendo controlar la impresora, consultar estados, administrar archivos y ejecutar tareas de Klipper desde un navegador. Depende de Moonraker y Nginx, y también es una de las interfaces que pueden necesitar las integraciones de acceso remoto.

### 3. Mainsail — `PENDIENTE`

Script: `scripts/mainsail.sh`. Instala la interfaz web Mainsail y la publica en el puerto `4409`, ofreciendo otra forma de administrar Klipper, los trabajos de impresión, los archivos y la configuración. Depende de Moonraker y Nginx; normalmente se usa como alternativa a Fluidd, aunque el menú permite instalar ambas.

## Menú `Install` — `UTILITIES`

### 4. Entware — `PENDIENTE`

Script: `scripts/entware.sh`. Instala Entware, un sistema de paquetes que añade herramientas y utilidades Linux al entorno de la impresora. Otros módulos lo utilizan como dependencia para instalar Git, ejecutar servicios o disponer de binarios que no forman parte del firmware original, por lo que retirarlo puede afectar a Git Backup, Timelapse, USB Camera y varias integraciones remotas.

### 5. Klipper Gcode Shell Command — `PENDIENTE`

Script: `scripts/gcode_shell_command.sh`. Añade a Klipper la posibilidad de ejecutar comandos o scripts del sistema desde macros G-code. Es una dependencia compartida por Buzzer Support, Camera Settings Control, Improved Shapers Calibrations, Useful Macros y Git Backup, de modo que debe analizarse como componente base antes de eliminar cualquier módulo que lo utilice.

## Menú `Install` — `IMPROVEMENTS`

### 6. Klipper Adaptive Meshing & Purging (KAMP) — `PENDIENTE`

Script: `scripts/kamp.sh`. Instala KAMP para generar un mallado y una purga adaptados al área real de la pieza que se va a imprimir. En esta variante del repositorio también incorpora ajustes relacionados con `START_PRINT` y el firmware CFS, por lo que habrá que comprobar si esas modificaciones siguen siendo necesarias cuando se definan los flujos propios de Power Screen y CFS.

### 7. Buzzer Support — `PENDIENTE`

Script: `scripts/buzzer_support.sh`. Añade soporte para emitir avisos sonoros desde macros o eventos de Klipper, de forma que la impresora pueda informar al usuario cuando termina una tarea o requiere intervención. El instalador depende de Klipper Gcode Shell Command y debe conservarse solo si el hardware y el firmware CFS exponen correctamente el mecanismo de sonido.

### 8. Nozzle Cleaning Fan Control — `PENDIENTE`

Script: `scripts/nozzle_cleaning_fan_control.sh`. Instala la configuración y los archivos necesarios para controlar el ventilador asociado al proceso de limpieza de la boquilla. Su objetivo es separar el comportamiento de ese ventilador del resto de ventiladores de impresión, por lo que habrá que verificar que los nombres de ventilador, macros y pines coincidan con la K1C/CFS.

### 9. Fans Control Macros — `PENDIENTE`

Script: `scripts/fans_control_macros.sh`. Instala macros para controlar de forma más directa los ventiladores de la impresora desde Klipper o desde las interfaces web. Aporta controles y comandos adicionales, pero debe revisarse para evitar conflictos con la configuración original de la K1C y con cualquier control de ventiladores que incorpore Power Screen.

### 10. Improved Shapers Calibrations — `PENDIENTE`

Script: `scripts/improved_shapers.sh`. Instala herramientas, scripts y configuraciones para realizar calibraciones mejoradas de input shaper y analizar las resonancias de la impresora. El módulo utiliza Klipper Gcode Shell Command y comparte archivos o funcionalidades con Guppy Screen, por lo que su eliminación o conservación debe decidirse separadamente de la pantalla, comprobando primero sus dependencias directas.

### 11. Useful Macros — `PENDIENTE`

Script: `scripts/useful_macros.sh`. Instala un conjunto de macros de uso general para simplificar tareas frecuentes de Klipper, como operaciones de impresión, movimiento o gestión de la máquina. Requiere Klipper Gcode Shell Command y deberá revisarse macro por macro para descartar comandos incompatibles con el flujo CFS o duplicados por futuras funciones de Power Screen.

### 12. Save Z-Offset Macros — `PENDIENTE`

Script: `scripts/save_zoffset_macros.sh`. Añade macros para guardar, recuperar y aplicar el valor de Z-offset de la impresora sin tener que editar manualmente la configuración. Es un módulo relativamente independiente, pero se debe confirmar que sus nombres de macro y ubicación de archivos no interfieran con la configuración de calibración original de la K1C.

### 13. Screws Tilt Adjust Support — `PENDIENTE`

Script: `scripts/screws_tilt_adjust.sh`. Instala el script y la configuración necesarios para usar `SCREWS_TILT_CALCULATE`, que ayuda a nivelar la cama calculando cuánto debe ajustarse cada tornillo. Su utilidad depende de la geometría y la configuración de la cama de cada modelo, así que antes de conservarlo hay que validar que los puntos definidos correspondan a la K1C.

### 14. M600 Support — `PENDIENTE`

Script: `scripts/m600_support.sh`. Añade soporte para el comando `M600` y el flujo de cambio manual de filamento, incluyendo las macros y configuraciones que pausan la impresión y permiten continuarla. En una K1C con CFS debe revisarse cuidadosamente para no crear conflictos con la carga, descarga, sensores y macros de filamento que ya proporciona el firmware CFS.

### 15. Git Backup — `PENDIENTE`

Script: `scripts/git_backup.sh`. Instala un mecanismo para guardar versiones de la configuración de Klipper mediante Git y recuperar cambios anteriores cuando sea necesario. Requiere Entware y Klipper Gcode Shell Command, y puede ser útil para conservar copias antes de modificar macros, instalar Power Screen o probar cambios en los módulos.

## Menú `Install` — `CAMERA`

### 16. Moonraker Timelapse — `PENDIENTE`

Script: `scripts/moonraker_timelapse.sh`. Instala el componente de Moonraker que captura imágenes durante la impresión y las combina en un vídeo timelapse al finalizar. Requiere Entware y una cámara funcional; habrá que revisar consumo de almacenamiento, rutas de salida y compatibilidad con la cámara instalada en la K1C.

### 17. Camera Settings Control — `PENDIENTE`

Script: `scripts/camera_settings_control.sh`. Añade configuraciones y comandos para controlar desde Moonraker o Klipper parámetros de la cámara, como exposición, enfoque u otras opciones disponibles en el hardware. Depende de Klipper Gcode Shell Command y no todas las cámaras exponen las mismas capacidades, por lo que debe validarse con el modelo concreto de cámara de la K1C.

### 18. USB Camera Support — `PENDIENTE`

Script: `scripts/usb_camera.sh`. Configura el soporte para una cámara conectada por USB, incluyendo los servicios y archivos necesarios para que Moonraker o la interfaz web puedan utilizarla. Requiere Entware y debe revisarse junto con el tipo de cámara, el dispositivo V4L2 detectado y las diferencias entre las revisiones de hardware de la K1C.

## Menú `Install` — `REMOTE ACCESS`

### 19. OctoEverywhere — `PENDIENTE`

Script: `scripts/octoeverywhere.sh`. Instala la integración de OctoEverywhere para acceder y monitorizar la impresora de forma remota mediante sus servicios. Requiere Moonraker, Nginx, Fluidd o Mainsail y Entware, por lo que su instalador debe comprobar correctamente esas dependencias y no dejar servicios activos después de una desinstalación incompleta.

### 20. Moonraker Obico — `PENDIENTE`

Script: `scripts/moonraker_obico.sh`. Instala el componente que conecta Moonraker con Obico para ofrecer acceso remoto y funciones de monitorización asociadas a esa plataforma. Requiere Moonraker, Nginx, Fluidd o Mainsail y Entware; antes de conservarlo hay que decidir si este proyecto seguirá ofreciendo integraciones externas de terceros.

### 21. GuppyFLO — `PENDIENTE`

Script: `scripts/guppyflo.sh`. Instala GuppyFLO, un componente relacionado con el control del flujo y las funciones de purga dentro del ecosistema Guppy. Requiere Moonraker y Nginx, y su lógica debe revisarse junto con KAMP, el firmware CFS y Power Screen para evitar conservar funciones duplicadas o dependencias de Guppy Screen que ya hemos decidido retirar.

### 22. Mobileraker Companion — `PENDIENTE`

Script: `scripts/mobileraker_companion.sh`. Instala el servicio auxiliar que permite conectar la impresora con la aplicación Mobileraker para consultar su estado y controlarla remotamente. Requiere Moonraker, Nginx, Fluidd o Mainsail y Entware, por lo que debe evaluarse según si se desea mantener soporte para aplicaciones móviles externas.

### 23. OctoApp Companion — `PENDIENTE`

Script: `scripts/octoapp_companion.sh`. Instala el componente que comunica Moonraker con OctoApp y permite usar las funciones remotas de esa aplicación. Requiere Moonraker, Nginx, Fluidd o Mainsail y Entware; su permanencia dependerá de si se considera necesario mantener varias integraciones móviles en la versión personalizada.

### 24. SimplyPrint — `PENDIENTE`

Script: `scripts/simplyprint.sh`. Añade la integración con SimplyPrint para supervisar y gestionar la impresora desde su plataforma remota. Requiere Moonraker, Nginx y Fluidd o Mainsail, y modifica la configuración de Moonraker, por lo que cualquier eliminación debe limpiar también la sección `[simplyprint]` y sus archivos asociados.

## Menú `Customize`

Estas opciones no aparecen dentro de `Install`, pero son componentes instalables que el menú K1 ofrece desde `Customize` y por eso también forman parte del inventario.

### 25. Custom Boot Display — `PENDIENTE`

Script: `scripts/custom_boot_display.sh`. Sustituye la pantalla o animación de arranque original por una versión personalizada y permite restaurarla posteriormente mediante el menú. Debe revisarse si Power Screen utilizará el mismo flujo de arranque, porque podría ser necesario conservarlo, adaptarlo o separarlo para que no modifique archivos que la nueva pantalla necesite.

### 26. Guppy Screen — `ELIMINAR` / `REEMPLAZAR POR POWER SCREEN`

Script: `scripts/guppy_screen.sh`. Instala una interfaz táctil alternativa basada en Guppy Screen, junto con su servicio de arranque, módulos auxiliares, archivos de configuración, bibliotecas y enlaces dentro de Klipper. La decisión es retirarlo del proyecto para implementar Power Screen; todavía no se debe borrar físicamente el código hasta definir el instalador, las rutas, las dependencias, la gestión del servicio y el mecanismo de backup/rollback de Power Screen.

### 27. Creality Dynamic Logos for Fluidd — `PENDIENTE`

Script: `scripts/creality_dynamic_logos.sh`. Reemplaza o personaliza los logotipos que aparecen en Fluidd para mostrar la identidad visual de Creality. Requiere Fluidd y modifica sus archivos de interfaz, por lo que habrá que decidir si se conserva como personalización independiente o si se integra dentro de la futura identidad visual de Power Screen.

## Acciones del menú que no son módulos instalables

### `Remove`

El menú `Remove` no instala componentes nuevos; ejecuta las rutinas inversas de los módulos disponibles para deshacer sus cambios. Debe mantenerse sincronizado con cualquier modificación del menú `Install`, especialmente al retirar Guppy Screen o al añadir Power Screen, para que cada módulo tenga una desinstalación segura y reversible.

### `Backup & Restore`

Este menú gestiona copias y restauraciones de archivos de configuración de Klipper y de la base de datos de Moonraker. No representa un módulo extra independiente, pero será importante usarlo como protección antes de cambiar macros, servicios, archivos de configuración o módulos relacionados con CFS.

### `Tools`

Este menú contiene acciones de mantenimiento, como bloquear o permitir actualizaciones de Klipper, corregir la impresión de archivos G-code desde una carpeta, habilitar o deshabilitar ajustes de cámara, reiniciar servicios, actualizar paquetes de Entware, limpiar caché y logs, restaurar firmware anterior o restablecer la impresora. Son operaciones sobre módulos o sobre el sistema, no módulos que debamos seleccionar para conservar o eliminar.

### `Information` y `System`

Estos menús muestran información del estado de la impresora, el firmware, la red, el uso de CPU, la memoria, el almacenamiento y el tiempo de actividad. No instalan componentes y no forman parte de la lista de decisiones de módulos.

## Decisiones confirmadas

1. Retirar `Guppy Screen` del conjunto de módulos del proyecto.
2. Implementar `Power Screen` como reemplazo de la interfaz táctil.
3. Mantener todos los demás elementos en estado `PENDIENTE` hasta revisarlos individualmente.

## Siguiente paso

La siguiente revisión debe comenzar por las dependencias de `Guppy Screen` y por el diseño de `Power Screen`; después podremos decidir cada módulo con evidencia de sus scripts, archivos instalados, dependencias y rutina de desinstalación.
