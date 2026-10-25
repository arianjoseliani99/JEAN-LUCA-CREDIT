# JEAN LUCAS CREDIT

Aplicación Flutter para gestionar préstamos, cuotas y cotizaciones.

## Acceso local

Al abrir la app por primera vez, crea y confirma un PIN numérico de 4 dígitos. En las siguientes aperturas, ingresa ese PIN para entrar. Los préstamos, borradores y el PIN se guardan localmente en el dispositivo; por ahora no se requiere configuración de Firebase ni hay sincronización entre dispositivos.

El PIN local es una barrera de acceso básica, no sustituye el bloqueo del dispositivo ni protege contra alguien con acceso técnico a sus datos. Si olvidas el PIN, por ahora no hay recuperación; reinstalar la app borra también los datos locales.

Desde Configuración puedes alternar entre modo día y noche, y en Apariencia elegir una de cinco paletas y tres tamaños de texto. Los cambios se aplican inmediatamente y se guardan en el dispositivo.

## Desarrollo

```sh
flutter pub get
flutter run
```

## Pruebas

```sh
flutter test
```
