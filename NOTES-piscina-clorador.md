# Diagnóstico piscina — Home Assistant + clorador Fluidra

**Fecha:** 2026-06-30

## Síntoma
En el dashboard de HA (`/home/areas-piscina`), tres tarjetas aparecían con aviso amarillo "No disponible":
**Turbo**, **Modo** y **Cloro Libre**. Sospecha inicial: problema de actualización.

## Diagnóstico (con evidencia)
- **No era actualización.** La integración `fluidra_pool` corre en **v2.43.5** (la última), instalada vía HACS desde el upstream **`foXaCe/Fluidra-pool`**. El fork propio `Pep190272/Fluidra-pool` está ~53 commits atrás y **no es lo que corre** (ignorar).
- El clorador es de la familia thingType **`tecnoLC2`** (salino, mide **ORP/redox**, no cloro libre).
- El volcado de diagnóstico (componentes que el equipo reporta a la nube de Fluidra) tiene **solo 11 componentes, todos ya mapeados**: pH (165), ORP (170), temperatura (172), salinidad (174), nivel de producción (10), consigna pH (16), consigna ORP (20) + identificadores (0,1,2,3).
- **No existe** ningún componente para turbo, modo ni cloro libre. El hardware no los tiene, y la **app oficial de Fluidra tampoco los muestra**.

**Conclusión:** las 3 entidades están permanentemente no disponibles porque el hardware no envía esos datos. Un PR al repo **no puede arreglarlo** (no se puede mapear un dato que no existe).

## Arreglo aplicado
El dashboard `/home/areas-piscina` es **auto-generado por área** (no hay archivo de lovelace editable). La forma nativa de ocultar las tarjetas es **deshabilitar las entidades**:

- `switch.piscina_chlorinator_modo_turbo`
- `select.piscina_chlorinator_modo`
- `sensor.piscina_chlorinator_cloro_libre`

Se pusieron en `disabled_by: "user"` en `core.entity_registry`. Backup:
`/config/.storage/core.entity_registry.bak-fluidra-20260630-111933`

**Reversible:** Ajustes → Dispositivos y servicios → Fluidra Pool → (entidad) → Habilitar.

### Procedimiento técnico (HA en Docker)
HA corre en contenedor `homeassistant`, config en el volumen `ha_config` → `/config`, accesible en `http://localhost:8123`.

> ⚠️ Editar `.storage` con HA **parado**, o al apagarse reescribe el registro desde memoria y pisa el cambio.

```bash
docker stop homeassistant
# backup
docker run --rm -v ha_config:/config alpine sh -c \
  'cp /config/.storage/core.entity_registry /config/.storage/core.entity_registry.bak-$(date +%Y%m%d-%H%M%S)'
# editar (poner disabled_by="user" en las 3 entity_id)
docker run --rm -v ha_config:/config python:3-alpine python3 -c "..."
docker start homeassistant
```

## Problema real (química, no software)
Alarma activa en el equipo: **`PUMPSTOP PH`** — pH medido **7,79** vs consigna **7,60**. La bomba de pH- dosificó sin alcanzar el objetivo y se paró por seguridad.
**Causa:** bidón de pH- vacío. **Solución:** se rellenó el bidón → alarma desaparecida. Llega más pH- el 2026-07-01.
Si vuelve a pasar: revisar nivel del bidón de pH-, cebar la bomba, y alcalinidad del agua (>80 mg/L).

## Estado final
- ✅ Tarjetas fantasma ocultas (Turbo/Modo/Cloro Libre).
- ✅ Integración al día (v2.43.5).
- ✅ Alarma pH resuelta (bidón rellenado).
- Valores sanos: pH 7,79→bajando, ORP ~707 mV, temp 28,6 °C, sal OK, producción 100%.

---

# Episodio 2 — 2026-08-11: el pH- no dosifica (causa raíz)

## Síntoma
La piscina marca pH alto y el equipo **no coge bajador de pH**, con el bidón a la mitad y la
manguera de aspiración dentro.

## Lectura del panel

| Indicador | Valor |
|---|---|
| pH | **8,28** |
| Redox (ClmV) | 589 mV |
| Alarma | ⚠ **pH** + `high` (rojo) |
| `pumpstop` | **apagado** |
| Modos activos | Intelligent · Auto ClmV · direct |
| Producción | 60 % |

**Clave del diagnóstico:** `pumpstop` está apagado, así que **no** es el paro por bidón vacío de
junio. Es la **alarma de pH alto**, que bloquea igualmente la bomba de ácido por protección: la
lectura lleva demasiado tiempo fuera de rango, el equipo asume avería (sonda descalibrada, bomba
descebada, fuga) y corta antes que vaciar el bidón en la piscina.

El redox bajo **no es un problema aparte**: a pH 8,28 el cloro pierde poder oxidante. Baja el pH
y el redox sube solo.

## Causa raíz (química, otra vez)

**Alcalinidad total (TAC) = 240 mg/L.** Rango sano: 80–120.

El TAC es el tampón del agua: cuanto más alto, más se resiste el pH a moverse. La bomba dosificaba
sin llegar nunca a consigna hasta que el equipo se autobloqueó. Sumado a que el clorador salino
sube el pH de forma continua por electrólisis, la automática no tenía ninguna posibilidad.

**Y el agua de aporte también mide TAC 240.** La piscina no se desvió: copia el agua de llenado.
Consecuencia: diluir (vaciar y rellenar) no sirve de nada.

## Descartado por el camino

- **No hay producto que baje solo el TAC.** "Reductor de alcalinidad", "TA down", "Baja TA": todos
  son ácido. La aireación no baja TAC, solo sube pH.
- **La descalcificadora no interviene**, por dos motivos independientes: no baja alcalinidad
  (el intercambio iónico quita dureza, los bicarbonatos pasan intactos) y además solo trata el agua
  de la casa — la piscina se llena por la línea del huerto, que no pasa por ella.
- **Echar la garrafa de golpe: no.** El ácido se hunde y forma una bolsa a pH 1-2 sobre el
  revestimiento, ataca los electrodos de la célula, y ácido + hipoclorito da cloro gas. Además ni
  siquiera llega al objetivo (20 L bajan ~80 puntos: 240 → 160).

## Productos y equivalencias (piscina de 40 m³)

| Producto | Composición | Por 10 ppm de TAC |
|---|---|---|
| AstralPool pH Minus (20 L) | ácido sulfúrico **14,4 %** | **2,5 L** |
| Piscimar Baja TA PM-642 | bisulfato sódico 100 % | **1 kg** |
| Salfumán ferretería | clorhídrico ~23 % | ~1,1 L |

Escala útil: según etiqueta, **1,28 L de pH Minus bajan el pH 0,2** en esta piscina.

## Plan aplicado
Objetivo **120 ppm** (no 100: el agua de relleno viene a 240 y el margen extra se pierde con el
primer rellenado). 120 puntos → **~30 L de pH Minus**, en unos 6-7 días.

Procedimiento completo, calendario, variante para días laborables, registro de mediciones y
seguridad: **[`plan-bajar-alcalinidad-piscina-2026-08-11.md`](plan-bajar-alcalinidad-piscina-2026-08-11.md)**

## Mantenimiento posterior
- **~1 L de pH Minus por cada m³ de agua repuesta**, para compensar el aporte en el momento y no
  repetir el tratamiento entero.
- **Cubierta / manta térmica**: menos evaporación = menos relleno = menos alcalinidad importada.
  Es lo único que ataca la causa.
- Al terminar: reset de la alarma cortando corriente, y consigna de pH a **7,2–7,4** (no 7,6), que
  da margen frente a la subida continua del salino.

## Pendiente
- [ ] Medir el TAC de la **línea del huerto** (el 240 medido es del grifo de la casa; esa línea
      puede tener otro origen).
- [ ] Comprar 2 garrafas de 20 L de pH Minus.
- [ ] Poner en marcha la descalcificadora — por la casa y por la instalación, no por el TAC.

---

# Episodio 3 — 2026-08-15: la integración "no expone datos"

## Síntoma
Home Assistant no muestra valores del clorador, pero el grupo de filtración funciona y la bomba
de pH dosifica. Además, cerca de consigna salta una alarma que **para la bomba**, con la garrafa
por debajo de un cuarto.

## Método
La extensión de navegador **no** sirve para esto: no consigue inyectar script en `localhost:8123`
bajo Brave, ni con permiso de sitio concedido (timeout de 5 s, y 45 s esperando `document_idle`).

La vía que funciona es la **API REST de HA** con un token de larga duración:

| Endpoint | Para qué |
|---|---|
| `GET /api/states` | estado y atributos de todas las entidades |
| `GET /api/config/config_entries/entry` | si el config entry cargó y por qué falla si no |
| `GET /api/error_log` | avisos del coordinator |
| `GET /api/history/period/…` | cuándo cambió cada estado |
| `POST /api/template` | `integration_entities('fluidra_pool')` + `device_attr()` |
| `POST /api/config/config_entries/entry/{id}/reload` | recargar sin reiniciar HA |

## Trampa de diagnóstico

Los `entity_id` de esta integración **no contienen la palabra "fluidra"**:

```
sensor.piscina_chlorinator_ph          number.piscina_chlorinator_consigna_ph
binary_sensor.piscina_chlorinator_alarma   sensor.casa_estado_de_la_piscina
```

Filtrar `/api/states` por "fluidra" da **falso negativo**: parece que no existe ninguna entidad
cuando en realidad hay 13 registradas. Filtrar por `integration_entities('fluidra_pool')`.

## Diagnóstico (con evidencia)

La integración **no está rota**: config entry en `state=loaded`, autenticación correcta,
las 13 entidades presentes en el registro.

El clorador **ya estaba sirviendo datos cacheados en la primera lectura que HA consiguió**, el
2026-08-13 a las 15:33 local. No se puede afirmar que el corte empezara ahí: la base de datos del
recorder arranca ese mismo día, así que no hay visibilidad anterior. El corte puede ser más viejo.

Secuencia tras recargar el config entry:

```
09:14:04 UTC  reload  → todo disponible: pH 8.87, ORP 620, cloración 60 %, device_offline=False
09:15:46 UTC  +100 s  → unavailable de nuevo, device_offline=True
```

Un poll bueno y se cae. El mismo patrón del día 13 (dato a las 13:33:53, muerto a las 13:34:27,
**34 segundos**). El historial lo confirma: `signal_excellent` → `unavailable`, sin degradación
previa. No es cobertura que se va apagando; es un corte seco.

**Prueba de que es caché, no telemetría:** los valores devueltos son idénticos a los del día 13,
con la temperatura del agua clavada en 28,7 °C tras 48 horas. La nube sirve el **último snapshot
conocido** en la primera petición de cada sesión nueva. El propio `signal_excellent` forma parte
de ese snapshot rancio, así que **no prueba conectividad actual**.

Qué distingue lo vivo de lo muerto:

| Entidades | Origen | Estado |
|---|---|---|
| `sensor.casa_*`, salinidad | datos de piscina a nivel nube | ✅ se actualizan |
| pH, ORP, temperatura, alarma, todos los `number.*` | componentes del dispositivo | ❌ congelados |

El único camino cortado es el que pasa por el clorador. **El equipo funciona; lo que está caído
es su módulo de comunicación.** De ahí la aparente contradicción "el grupo va bien" + "no expone
datos": son las dos caras de lo mismo.

Recargar la integración **no lo arregla** — solo provoca una lectura de caché.

## La alarma que para la bomba

Del último snapshot:

| Dato | Valor |
|---|---|
| Alarma activa | **`HIGH PH`** ("High pH") — 1 alarma |
| pH | **8,87** |
| Consigna pH | 7,61 (rango configurable 7,0–7,8) |
| ORP | 620 mV |
| Nivel de cloración | 60 % |
| Consigna ORP | 750 mV |

**No es alarma de nivel de producto.** Es la protección por pH alto del episodio 2: la bomba
dosifica, no consigue bajar de 8,87 a 7,61 porque el TAC 240 lo tampona, y el equipo se
autobloquea. El nivel de la garrafa no es la causa del paro.

Aun así conviene rellenarla y **no operar por debajo de un cuarto**: ahí la lanza de aspiración
empieza a tragar aire, el ácido sulfúrico al 14,4 % desgasifica, la peristáltica pierde cebado y
gira sin trasegar producto. Eso produce el mismo bloqueo por otra vía, con la manguera perfecta.

**El pH se está escapando: 8,28 (11-ago) → 8,87 (13-ago).** Mientras no baje la alcalinidad, esto
se repite.

## Versiones

| Dónde | Versión |
|---|---|
| Integración en ejecución (HACS ← upstream) | **v2.78.3** |
| Este fork antes de sincronizar | v2.40.7 (275 commits atrás) |

El aviso `No component data received … after 3 consecutive polls` que aparece en el log **no
existe** en el código de v2.40.7. Depurar contra un checkout desincronizado lleva a conclusiones
falsas: sincronizar el fork antes de tocar nada.

## Causa raíz: el SSID guardado ya no existe

**Cambió el nombre de la red WiFi de 2,4 GHz.** La contraseña no, y el router es el mismo. El módulo
arranca, escanea, no encuentra la red que tiene memorizada y se rinde. Nunca se asocia, nunca llega
a la nube.

Es la única hipótesis que explica las cuatro observaciones a la vez:

| Observación | Qué descarta |
|---|---|
| La contraseña no cambió | no es fallo de credenciales |
| El router es el mismo | no es hardware de red |
| El equipo arranca y dosifica | no es el módulo, que está vivo |
| La nube nunca lo ve | nunca llegó a asociarse |

### El ciclo de corriente no es la solución

El clorador **cae con el grupo** (misma línea, enclavado con la bomba). Con un ciclo de 2 h
encendido / 1 h apagado son **8 arranques al día** y 16 h de filtración: más de dieciséis ciclos
completos desde el 13 de agosto, sin recuperarse ni una vez. Descartado.

> Ese enclavamiento es correcto y **no debe separarse**. La célula de electrólisis no puede
> funcionar sin caudal: se recalienta, se incrusta, degrada las placas de titanio y genera cloro gas
> en un tubo cerrado.

### Ojo con la banda

Estos módulos hablan **solo 2,4 GHz** — por coste, pero sobre todo por alcance: 5 GHz no atraviesa
la obra hasta el cuarto técnico. Si el router emite las dos bandas con nombres distintos (`RED` y
`RED-5G`), la buena es la que **no** lleva el sufijo. Conectar el equipo a la de 5 GHz no funciona
nunca, con contraseña correcta o sin ella.

### El aviso de pH alto de la app no es un falso positivo

La app oficial y Home Assistant **no son fuentes independientes**: leen el mismo registro de la
nube. Las dos repiten la foto congelada, con la alarma `HIGH PH` que sí era real cuando se cortó la
comunicación.

La prueba: el panel del equipo marcaba **7,68** mientras la nube seguía diciendo **8,87**. Esa
discrepancia es, exactamente, la medida del corte. La sonda no miente; la nube enseña una
fotografía vieja.

## Lo que HA no puede ver

No hay **ningún** sensor de la piscina independiente del clorador: ni enchufe con medida, ni
contacto en el cuadro. Todo llega por la nube de Fluidra a través del clorador, que es justo lo
roto. HA no puede detectar siquiera si el grupo está en marcha.

Un enchufe inteligente con medida de consumo en la línea del grupo resolvería esa ceguera: daría
una fuente que no depende de la nube de nadie, y permitiría distinguir "la bomba no funciona" de
"el clorador no reporta".

## Resuelto — 2026-08-15 13:04

Reemparejado el WiFi del clorador con la red de 2,4 GHz actual, aprovechando el arranque del grupo
de las 13:00. Verificación desde la API de HA a los pocos minutos:

| Dato | Antes (foto congelada) | Después |
|---|---|---|
| `device_offline` | `True` | **`False`** |
| Temperatura del agua | 28,7 °C (48 h clavada) | **29,2 °C** |
| pH | 8,87 | **7,68** |
| ORP | 620 mV | **640 mV** |
| Salinidad | 5,14 | **5,46** |
| Alarma | `HIGH PH` | **`off`**, `active_alarms: []` |

La temperatura era la prueba: en cuanto se movió, los datos dejaron de ser caché. Y la nube pasó a
decir **7,68**, exactamente lo que marcaba el panel del equipo mientras la nube seguía anclada en
8,87. Ese hueco entre panel y nube era la medida del corte, y se cerró.

La alarma `HIGH PH` desapareció sin intervención: no había avería, había un registro de hace dos
días.

**Método de verificación reutilizable:** ante cualquier sospecha de datos rancios, comparar la
lectura del panel con la de la nube. Si difieren, el problema es de comunicación, no de sonda. Y
vigilar un valor que cambie solo —la temperatura del agua sirve—: si lleva horas idéntico al
decimal, es caché.

## Pendiente
- [x] ~~Reemparejar el WiFi del clorador~~ — hecho 2026-08-15.
- [x] ~~Revocar el token de larga duración de HA~~ — hecho 2026-08-15.
- [ ] Vigilar el ORP: 640 mV con consigna en 750 y producción al 60 %. Con el pH ya en rango debería
      subir solo, porque el cloro recupera poder oxidante. Si no sube, revisar producción.
- [ ] Rellenar la garrafa de pH Minus (regla: nunca por debajo de 1/4).
- [ ] Retomar el plan de alcalinidad del episodio 2 — **es la única causa que sigue viva**. Con TAC
      240 el pH volverá a escaparse y la alarma `HIGH PH` volverá a bloquear la bomba.
- [ ] Valorar un enchufe con medida de consumo en la línea del grupo, para dejar de depender de la
      nube como única fuente.

---

# Episodio 4 — 2026-08-15: `PUMPSTOP PH` con la bomba sana

Horas después de recuperar la conexión, con el equipo reportando en vivo, salta una alarma nueva.

## Qué significa realmente `PUMPSTOP PH`

> *"pH pump has run for too long without reaching the setpoint."*

Es un **corte por tiempo máximo de dosificación**, no una alarma de nivel. El equipo **no tiene sonda
de nivel** en la garrafa del tratamiento: lo único que sabe es que lleva demasiado rato bombeando sin
que el pH llegue a consigna.

> **Corrección a las notas de junio.** Allí se apuntó `PUMPSTOP PH` como "bidón vacío". Eso fue la
> **causa** de aquella vez, no el **significado** de la alarma. Confundir las dos cosas lleva a
> descartarla en falso cuando la garrafa tiene producto.

## Descartes hechos con el equipo delante

| Comprobación | Resultado |
|---|---|
| Tubo de aspiración con la bomba en marcha | **producto avanzando** → sí trasiega |
| Punto de inyección | **sin costra blanca** → válvula no cristalizada |
| Garrafa que alimenta la bomba | **queda un cuarto** → hay producto |
| Panel vs nube | **7,66 = 7,66** → la sonda lee bien y el dato no está rancio |

Entra ácido en la piscina y el pH no se mueve. **Eso no es una avería: es la definición de un
tampón.**

## La causa: un tira y afloja empatado

```
bomba de ácido  ──→ empuja el pH ABAJO
célula al 60 %  ──→ empuja el pH ARRIBA   (electrólisis, continua)
TAC 240         ──→ amortigua las dos
                    ─────────────────────
                    resultado neto: cero
```

pH clavado en **7,66** durante más de 37 min con consigna en 7,61, mientras ORP, temperatura y
salinidad se actualizaban cada 35 s. La bomba dosifica, la célula compensa y el tampón se traga el
resto.

Por eso salta la alarma a los ~14 minutos, y por eso **volverá a saltar**. La protección funciona
como debe: la máquina reconoce que no puede ganar y para antes de vaciar la garrafa en la piscina.

## Decisión: subir la consigna a 7,7 temporalmente

Con TAC 240 se está obligando al equipo a pelear por cinco centésimas inalcanzables. Cada intento
son catorce minutos de bomba, producto quemado y una alarma más — y ese producto hace falta para el
tratamiento de alcalinidad.

El agua mientras tanto es segura: **pH 7,66 con ORP 678 y subiendo** (venía de 620). La desinfección
funciona.

Al terminar el tratamiento, con el TAC en 120, bajar la consigna a **7,2–7,4** como indica el plan:
ahí el equipo sí podrá mantenerla, porque el agua habrá dejado de resistirse.

Secuencia en el panel: `SET` → `+` → `SET`. **Nunca tocar `CAL`.** Alternativa exacta y sin menús:
la entidad `number.piscina_chlorinator_consigna_ph` en Home Assistant (rango 7,0–7,8, paso 0,1).

## Diagnóstico sin token de Home Assistant

Cuando no hay token de larga duración, se puede leer todo desde el contenedor Docker:

```bash
docker logs --since 3h homeassistant      # ojo: el contenedor escribe en hora LOCAL, la API en UTC
```

Y la base de datos del recorder, en solo lectura y con HA en marcha:

```bash
docker exec homeassistant python3 -c "
import sqlite3
con = sqlite3.connect('file:/config/home-assistant_v2.db?mode=ro', uri=True)"
```

Tablas útiles: `states_meta` (entity_id ↔ metadata_id), `states` (state, last_updated_ts,
attributes_id) y `state_attributes` (`shared_attrs`, JSON con `active_alarms` y `error_code`).

## Truco de lectura: `last_updated` vs `last_reported`

- `last_updated` — cuándo **cambió** el valor
- `last_reported` — cuándo **llegó** el último sondeo, aunque el valor sea idéntico

Si una entidad tiene `last_reported` muy anterior al de sus compañeras, el dato ha dejado de llegar.
Si todas comparten `last_reported` y solo una tiene el `last_updated` viejo, esa magnitud
simplemente no se mueve. **Son diagnósticos opuestos y se distinguen solo mirando los dos campos.**

## Velocidad de subida del pH sin oposición

Con la consigna en 7,7 y el pH por debajo, la bomba de ácido **no dosifica**. Eso deja medir la
subida limpia que provoca la célula:

```
13:06  7,66   →   14:52  7,70      0,04 en 1 h 45 min
                                    ≈ 0,023 pH/hora
                                    ≈ 0,37 pH/día  (16 h de filtración)
```

Contraste que lo valida: durante los dos días con el equipo desconectado y la bomba bloqueada, el pH
llegó a **8,87**. Partiendo de rango normal, a 0,37 diarios, cuadra.

**Consecuencia:** subir la consigna es una tregua, no una solución. La de 7,7 duró una hora y tres
cuartos. No subir a 7,8 (techo del equipo): compraría horas, no días, y a más pH el cloro rinde
peor. Nada aguanta contra 0,37 de pH al día salvo bajar el TAC.

**Táctica para los días de tratamiento:** bajar la producción de cloración del 60 %. Durante el
tratamiento el pH estará en 7,0–7,4, y a ese pH el cloro rinde mucho más que a 7,7 — se puede
producir menos manteniendo el poder desinfectante. Así el ácido trabaja en bajar el TAC en vez de
pelear con la célula. Vigilando que el ORP no baje de 650.

## Entidades huérfanas en Home Assistant

`unavailable` tiene dos causas opuestas, y se tratan al revés. El atributo `restored` las separa:

| Estado | Qué significa | Qué hacer |
|---|---|---|
| `unavailable` **sin** `restored` | la integración la provee, el dato no llega ahora | **desactivar** — borrarla la recrea |
| `unavailable` **con** `restored: true` | nadie la provee, es un resto del registro | **borrar** — es basura |

Comprobación:

```bash
# ¿la provee la integración?
POST /api/template   {"template": "{{ integration_entities('fluidra_pool') }}"}

# ¿es un resto?
GET /api/states/<entity_id>     → buscar  "restored": true

# listar todas las huérfanas de golpe
GET /api/states   → filtrar por attributes.restored
```

**Caso `CLORIB`** (`sensor.piscina_chlorinator_cloro_libre`): `restored: true` y ausente de
`integration_entities`. Borrada el 2026-08-15; `GET` de la entidad devuelve **404** y el total baja
de 61 a 60.

No iba a volver nunca: el equipo es salino, mide **ORP/redox**, no cloro libre. Ese sensor no existe
en el hardware y la app oficial tampoco lo muestra (episodio 1). Que upstream dejara de crear la
entidad en la v2.78.3 es la confirmación — la quitaron porque no había nada que mapear.

> En junio hubo que **desactivar** las tres fantasma en vez de borrarlas, porque la v2.43.5 todavía
> las creaba. La diferencia no es de criterio: es que la integración cambió.

**Quedan tres huérfanas que NO hay que borrar:** `tts.piper`, `stt.faster_whisper` y
`wake_word.openwakeword`. Sus integraciones existen pero están en `setup_retry` con *Unable to
connect* — los servicios de voz de Wyoming no arrancan. Volverían en cuanto conectaran. El problema
real ahí son los contenedores, no el registro de entidades.

## Cómo distinguir un corte de corriente de un fallo de conexión

Los dos dejan las entidades en `unavailable`. Se separan mirando **la antigüedad de los datos**:

| | Corte de corriente (ciclo de filtración) | Fallo de conexión |
|---|---|---|
| Antigüedad | minutos: el último dato es de justo antes del corte | horas o días |
| Valores al volver | distintos, frescos | **idénticos**, hasta el decimal |
| Recuperación | sola, al volver la corriente | nunca sin intervención |

El clorador cae con el grupo, así que quedarse `unavailable` durante la ventana de parada es
**comportamiento normal**, no una avería.

> **Una desconexión NUNCA crea entidades huérfanas.** Comprobado con el equipo caído: sus entidades
> quedan en `unavailable` **sin** el atributo `restored`, porque la integración las sigue proveyendo
> — simplemente sin dato. Si aparece `restored: true`, la causa es otra: nadie provee ya esa
> entidad. Son dos diagnósticos que no se solapan.

Ojo al leer el historial durante una parada: puede aparecer **un sondeo suelto con dato cacheado**
en mitad de la ventana sin corriente. El 2026-08-15 el equipo cayó a las 15:09:40 y a las 15:42:20
hubo una lectura aislada con los mismos valores, antes de volver a `unavailable`. Ese repunte no
significa que el equipo despertara: es la nube sirviendo su último snapshot.

## El "punto de equilibrio" que no existió — conclusión retirada

> ⚠️ **Esta sección documenta un error de razonamiento propio. Se conserva porque el error es más
> instructivo que la conclusión.**

Tras subir la consigna a 7,7 se observó: 40 minutos sin alarmas, y el pH **clavado en 7,70 durante
51 minutos** (14:51:55 → 15:42:53). De ahí se concluyó que la bomba *sí podía sostener 7,7* aunque no
alcanzara 7,61, y que se había dado con su punto de equilibrio.

**La conclusión no se sostiene**, porque la bomba de suministro de pH **no estaba dosificando**
durante ese rato. Y una bomba parada:

- no puede disparar un corte por tiempo de dosificación → de ahí los "40 minutos limpios"
- no sujeta nada → el pH "clavado" era simplemente que aún no había cruzado a 7,71

Las dos observaciones se explican igual de bien con o sin punto de equilibrio. **No eran evidencia de
nada**, y se presentaron como si lo fueran.

Lo respalda el ritmo de subida: 0,023 pH/h por la tarde y 0,037 pH/h al anochecer. **Las dos son
subidas sin oposición**; la diferencia es la hora del día, no la bomba.

### Hipótesis abierta: banda muerta del controlador

A las 18:33, con el grupo encendido desde las 17:02, la bomba seguía parada y **sin ningún aviso**,
teniendo el pH por encima de la consigna:

```
consigna 7,70   ·   pH 7,74   →   desviación 0,04   →   no dosifica
consigna 7,61   ·   pH 7,66   →   desviación 0,05   →   sí dosificaba → PUMPSTOP PH
```

Encaja con que el controlador tenga una **banda muerta** de ~0,05: no arranca la bomba hasta que la
desviación la supera, para no estar conmutando por centésimas.

Si es así, subir la consigna sí sirvió, pero **no por el motivo que se había escrito**: no existe
ningún punto donde la bomba sostenga el pH — simplemente la desviación cayó dentro de la banda muerta
y el equipo dejó de intentarlo.

**Pendiente de confirmar.** El pH sube ~0,03/h, así que la desviación llegará a 0,10 por sí sola. Si
la bomba arranca ahí, la banda muerta queda demostrada. Si sigue parada, hay otra causa y toca
revisar la configuración del equipo.

> **Lección de método:** antes de atribuir una mejora a un cambio, comprobar que no hay una segunda
> variable que se movió a la vez. Aquí el cambio de consigna y el hecho de que la bomba no estuviera
> dosificando coincidieron en el tiempo, y se le adjudicó el mérito al primero sin descartar el
> segundo.
>
> Y el corolario operativo: **`PUMPSTOP PH` ausente no significa que la bomba esté bien.** Puede
> significar que no está dosificando en absoluto. La ausencia de alarma no es señal de salud.

## Horas de filtración: medidas, no estimadas

El clorador cae con el grupo, así que **sus transiciones a `unknown` dibujan el horario real del
reloj** sin mirar el cuadro. Basta con leer el historial de `binary_sensor.piscina_chlorinator_alarma`:
`unknown` = sin corriente.

Medido el 2026-08-15:

```
15:09:40   →  unknown     el grupo se para
17:02:53   →  off         el grupo arranca
              ─────────
              1 h 53 min de parada  ≈  2 h
```

Con ~2 h encendido, el ciclo real es **2 h ON / 2 h OFF = 12 h de filtración al día**, no las 16 h
que se habían supuesto.

> Ese repunte aislado de las 15:42 (dato cacheado en mitad de la parada) es justo lo que puede
> falsear esta lectura. Buscar transiciones **sostenidas**, no puntos sueltos.

### Lo que cuesta el déficit, medido

```
antes de parar   (15:09)   ORP 680 mV
al volver        (17:02)   ORP 644 mV     ← por debajo del suelo de 650
5 min después    (17:07)   ORP 657 mV     ← recupera rápido con la célula en marcha
```

**36 mV perdidos en dos horas sin filtrar.** Con la célula parada no se produce cloro y a 30 °C con
sol el que hay se consume. Y la recuperación de 13 mV en cinco minutos demuestra que al equipo **no
le falta capacidad, le faltan horas**.

Ahí está también la explicación de por qué el ORP se estancaba en 680 sin llegar a los 750 de
consigna: no era solo el pH alto.

### La cuenta

> **Regla: horas de filtración ≈ temperatura del agua / 2.**

| | |
|---|---|
| Temperatura del agua | 30,8 °C |
| Filtración necesaria | **≈ 15 h/día** |
| Filtración actual | 12 h/día |
| Déficit | **3 h/día** |

Corrección al alza de las paradas: pasar de 2 h a 1 h deja 2 h ON / 1 h OFF = **16 h/día**. El reloj
es manual, con segmentos de 15 minutos.

El reparto definitivo debe cumplir dos cosas a la vez: las 15–16 h diarias, y **ventanas con la
depuradora en marcha que cubran las tomas del tratamiento** (mañana, tarde y noche, separadas 6–8 h,
con 1 h de filtración posterior a cada toma).

## Conclusión

Las tres alarmas de este verano —junio, 11 de agosto y hoy— salen del mismo sitio. Con la bomba
sana, producto disponible e inyección limpia, `PUMPSTOP PH` es un **síntoma de alcalinidad alta**, no
un fallo mecánico.

**El TAC es lo único que queda por arreglar** — y, en segundo plano, las horas de filtración.
