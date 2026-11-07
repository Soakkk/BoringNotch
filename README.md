# BoringNotch Personal

Variante personal de [TheBoringNotch](https://github.com/TheBoredTeam/boring.notch), mantenida por Soakkk. Conserva la licencia GPLv3, los créditos de sus autores y las licencias de terceros. [Documentación original](README.upstream.md).

## Qué cambia

- Panel abierto de **640×190 puntos**, con la misma ventana de 640 × 210 incluyendo sombra.
- Distribución adaptativa: más espacio para música cuando la agenda está vacía y un reproductor más compacto al pausar. Agenda legible de tres filas. La vista de detalle usa el mismo espacio y permite navegar por los días.
- Tres temas estáticos: Esencial, Grafito y Ámbar, seleccionables en Apariencia.
- Ahorro inteligente según batería, bajo consumo, temperatura y reposo de pantalla. El reproductor y las letras detienen sus refrescos al pausar. Las animaciones decorativas cancelan sus tareas al desaparecer y respetan Reducir movimiento.
- Calendarios y recordatorios a través de Calendario de macOS: incluye las cuentas de Google que tengas añadidas al sistema.
- Aplicación independiente de FocusNotch, con identificadores y catálogo de actualizaciones propios.

## Instalación y actualizaciones

macOS 15 o posterior; Apple Silicon e Intel. Descarga el instalador de [Releases](https://github.com/Soakkk/BoringNotch/releases). La versión 3.1.3 (build 301003) introduce una firma personal estable para conservar los permisos entre actualizaciones. El cambio inicial desde la firma anterior puede pedir autorizarlos una vez. Conserva los indicadores segmentados, la distribución musical lateral, la agenda adaptativa, los temas y el ahorro inteligente. Sustituye siempre la misma copia de **BoringNotch Personal.app** en Aplicaciones.

Las comprobaciones y descargas automáticas están activadas por defecto. Se pueden cambiar en los ajustes de la app. El canal estable propio utiliza un appcast firmado y archivos de actualización firmados con Ed25519. Las actualizaciones originales se incorporan revisando el código del proyecto de origen.

La distribución personal usa firma local ad hoc y conserva sandbox y hardened runtime. Los detalles de firma, generación del instalador y publicación verificable están en [Release/README.md](Release/README.md). macOS gestiona por separado los permisos para calendario, recordatorios y control multimedia.

## Desarrollo

Requiere Xcode completo. El workflow manual **Personal build** compila ambos procesadores en GitHub, en un commit explícito; puede generar instaladores firmados y publicar el catálogo después de subir los archivos. Las claves privadas solo se suministran mediante secretos de Actions.

## Licencia

[GNU GPLv3](LICENSE). El código fuente de cada versión corresponde al commit indicado en su manifiesto de publicación. Se mantienen las licencias y atribuciones incluidas por el proyecto original.
