# BankOS Mobile

## Sesión

Al entrar sin una sesión activa, **Elige tu banco** consulta
`GET /api/v1/banks`. La selección abre el ingreso del banco y
`POST /api/v1/auth/login` recibe su `bank_id` público, correo y contraseña.
Una vez autenticado, el alcance de las consultas se toma del JWT y de los
identificadores devueltos en la sesión.

En Android e iOS, la app guarda el token y los datos necesarios para identificar
la sesión en el almacenamiento seguro del dispositivo. En iOS, la entrada de
Keychain queda disponible con el dispositivo desbloqueado y está ligada a ese
dispositivo. Web y escritorio conservan la sesión en memoria durante la ejecución.

Al abrir la app se comprueba el vencimiento local y se consulta
`GET /api/v1/auth/me` con el token guardado. El Dashboard se habilita tras
confirmar que el perfil está activo y corresponde al cliente y al banco de la
sesión. Si el token venció o FastAPI lo rechaza, se elimina y se vuelve al
ingreso por tenant. Cerrar sesión también borra el token y descarta los datos
de Cuentas antes de iniciar otra sesión.

Si abres la app sin conexión con un token vigente, la pantalla de verificación
ofrece **Reintentar** o **Borrar sesión e ir al ingreso**. El token permanece
cifrado mientras esperas. Para abrir las pantallas privadas o iniciar una sesión
nueva se necesita conexión con FastAPI.

## Registro por banco

**Crear usuario** conserva la selección del ingreso. Para solicitar o reenviar
un código se envían el `bank_id` público y el correo a
`POST /api/v1/auth/register`. FastAPI devuelve un `registration_id` y su
vigencia. La app usa el identificador más reciente con el código de correo,
el nombre completo y la contraseña en `POST /api/v1/auth/register/verify`.
La verificación habilita el ingreso manual al mismo banco.

## Operaciones

**Transferir** abre el selector de modalidades. **Mismo banco** valida el
número de destino dentro del banco de la sesión. **Otro banco** toma el banco
del directorio y cotiza una transferencia simulada. FastAPI devuelve el
desglose y un `quote_id` para confirmar cada transferencia. Si la cotización
vence o cambia, el usuario debe revisar y confirmar otra. En retiros y
transferencias, la app pide la biometría o la credencial del dispositivo.

Si falla la red o se pierde la respuesta después de confirmar, la operación
queda pendiente. Al reintentar se envían el mismo cuerpo, `Idempotency-Key` y
`X-Correlation-ID`. En Android e iOS el intento queda en almacenamiento seguro
y solo se recupera al autenticarse con el mismo usuario y banco. El reintento
está disponible durante 24 horas desde la confirmación. Después de ese plazo,
la pantalla muestra el identificador para consultar el estado con el banco.

## Movimientos

La pantalla Movimientos consulta `GET /api/v1/transactions` con el token de la sesión.
FastAPI aplica los filtros de cuenta y tipo de operación. La búsqueda por
cuenta o referencia y el alcance de las transferencias se aplican a medida
que se consultan las páginas. **Buscar en más movimientos** permite continuar
cuando las páginas consultadas todavía no contienen coincidencias.
