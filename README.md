## TODOs

#### Pantalla LCD
- [X] Comunicación paralela
- [X] Controlador

#### Memoria EEPROM
- [X] Comunicación I2C
- [X] Controlador

#### Acelerómetro MPU
- [X] Comunicación I2C
- [X] Controlador

#### Teclado numérico
- [X] Controlador

#### Sensor de continuidad
- [X] Controlador

#### Contrucción física
- [X] Diseño CAD
- [X] Impresión 3D
- [X] Diseño PCB
- [X] Impresión de circuito




## Controladores
Funciones que se pueden manejar con los controladores

### Pantalla LCD
Diferentes interfeces:
* Turn off
* Authentication
* Unlocked
* Incorrect
* Set sensitivity
* Select Set sensitivity
* Set password
* Confirm password
* Select Set password

### Memoria EEPROM
* Init
* Load password
* Set password

#### Acelerómetro MPU
* Init
* Get acceleration

### I2C driver
Incluye funciones aplicadas al proyecto de la memoria EEPROM y el acelerómetro MPU
* Init
* Load password
* Change password
* Sleep
* Wakeup

#### Teclado numérico
* Get input

#### Sensor de continuidad
* Get input


