# Paletas de BankOS Mobile

Dashboard, Cuentas, Operaciones y Movimientos usan el acento del banco de la
sesión activa. El directorio y el ingreso siguen usando BankOS, al igual que
el menú y Configuración general. La misma identidad está reservada para
Documentos y certificados y Ayuda. Claro u Oscuro es una preferencia del
dispositivo que se conserva al cerrar sesión.

## Origen de los acentos

Los hexadecimales de referencia corresponden a recursos de las páginas
oficiales consultadas. Las columnas Claro y Oscuro indican el acento que
efectivamente se usa en la app.

| Banco | Referencia de marca | Claro | Oscuro |
| --- | --- | --- | --- |
| Bancolombia | Verde `#00C389` y carbón `#2C2A29` observados en el HTML y los estilos de su página de evolución. El verde claro de la marca se oscurece para los controles sobre fondo claro. [Evolución Bancolombia](https://www.bancolombia.com/centro-de-ayuda/evolucion-bancolombia) | `#00694E` | `#00C389` |
| Nu | El artículo identifica el morado saturado como base y sus estilos usan `#820AD1`. La app lo aclara para superficies oscuras. [Brand Refresh de Nubank](https://www.blog.nubank.com.br/brand-refresh-como-renovamos-a-identidade-visual-do-nubank/) | `#820AD1` | `#C98BFF` |
| DaviPlata | El distintivo SVG publicado en su página de inicio usa rojo `#FF0000` y rosa `#FF60AA`. La app usa dos variantes del rojo ajustadas al contraste. [DaviPlata](https://www.daviplata.com/) | `#A6192E` | `#FF8899` |
| Falabella | Sus estilos web usan el verde `#3B9326`, el verde oscuro `#347B23` y el verde suave `#9ED389`. La app oscurece el acento en modo claro y usa el verde suave publicado en modo oscuro. [Banco Falabella Colombia](https://www.bancofalabella.com.co/) | `#2B6A1D` | `#9ED389` |
| Banco Andino | Azul de demostración definido para BankOS. | `#145EA3` | `#78B9FF` |
| Cooperativa Caribe | Turquesa de demostración definido para BankOS. | `#006E79` | `#61D2D6` |
| Uno | Bronce provisional de BankOS mientras se confirma la identidad oficial. | `#7B4A15` | `#F3B469` |
| BankOS | Verde `#00D68F` y azul `#041126` del tema existente. El verde se oscurece para el modo claro. | `#007553` | `#00D68F` |

La app identifica las paletas conocidas por el nombre normalizado que conserva
la sesión. Una institución sin paleta configurada utiliza BankOS.

## Ajustes de contraste

Los textos, bordes y superficies son colores funcionales de la app. En modo
oscuro se mantienen las bases de BankOS `#041126`, `#0D1F3C` y `#142A4F`.
En modo claro se usan `#F5F8FC`, `#FFFFFF` y `#E9EFF6`. Las secciones
bancarias tiñen esas bases con su acento al 3,5 %, 2,5 % y 5,5 %,
respectivamente. Los acentos secundarios y terciarios de cada banco se
mezclan con el color del texto principal al 18 % y 32 %.

| Rol funcional | Claro | Oscuro | Origen |
| --- | --- | --- | --- |
| Texto principal y secundario | `#142338`, `#455970` | `#F8FAFC`, `#9CB4C9` | Neutros de la app. Los tonos oscuros de fondo conservan los textos del tema BankOS. |
| Pistas y bordes de campos | `#53677D`, `#65788D` | `#8FA6BE`, `#687F9A` | Ajustes de contraste sobre las superficies de entrada. |
| Texto sobre botones con acento | `#FFFFFF` | `#041126` | Blanco o azul BankOS para contrastar con el relleno. |
| Error de campo | `#A6203E` | `#FF7588` | Rojos funcionales comunes. Se mantienen separados del acento de cada banco. |
| Acentos secundarios de BankOS | `#006B72`, `#075B84` | `#00A8A8`, `#38BDF8` | Turquesa y azul del tema previo, oscurecidos en modo claro. |

Las pruebas comprueban al menos 4,5:1 para texto y botones y 3:1 para
límites de campos e íconos de acciones en los dos modos.
