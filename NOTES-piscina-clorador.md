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

> 🛑 **ESTE NÚMERO ES FALSO.** Se conserva como registro de lo que se creyó entonces. El 17-08 la
> alcalinidad se midió por titulación limpia: **85–110 mg/L**, y siempre estuvo cerca de 150, nunca
> en 240. Toda dosis calculada en esta sección está invalidada. Ver **Episodio 6**.

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

## Banda muerta confirmada

La hipótesis se resolvió sola, y antes de lo previsto:

```
18:16   pH 7,74   desviación 0,04   →  bomba parada, sin aviso
18:38   pH 7,77   desviación 0,07   →  bomba dosificando  →  PUMPSTOP PH a los ~14 min
```

**El umbral está entre 0,04 y 0,07**, coherente con los 0,05 de desviación que dosificaban por la
mañana (consigna 7,61 con pH 7,66). La banda muerta es de ~0,05.

De paso queda demostrado que **la bomba funciona**: dosificó catorce minutos seguidos. Lo que no
puede es mover el pH contra el TAC 240.

> El equipo **rearma la alarma solo** pasado un rato: bloquea, espera y reintenta. Por eso parecía ir
> y venir durante el día.

## Primera dosis manual de Baja TA — resultados

1 kg de bisulfato sódico en polvo, diluido en 10-12 L de agua de la piscina, vertido paseando por la
parte honda y lejos de los chorros, con la depuradora en marcha.

```
19:05   pH 7,74   ORP 686
19:51   pH 7,33   ORP 700
19:54   pH 7,30   ORP 701
```

**Bajada de 0,41 con 1 kg.** La previsión cruzando las equivalencias de la tabla era ~0,4. El
producto rinde lo que dice la etiqueta en esta agua, así que la escala `1 kg = 10 puntos de TAC` es
fiable para planificar.

### El techo del ORP lo pone el pH — demostrado

Todo el día pegado a 683-686 sin poder pasar de ahí, con la célula al 60 % y horas de filtración de
sobra. Cuatro décimas menos de pH y rompe el techo en diez minutos:

```
686  →  691  →  715  →  708  →  701
```

> **Regla que sale de aquí: las horas de filtración ponen el SUELO del ORP; el pH pone el TECHO.**
> Son dos palancas distintas y hacen falta las dos. Más horas no llevan el redox a los 750 de
> consigna si el pH está alto.

### El falso mínimo al verter

```
19:45:54   7,49
19:47:00   6,79      ← la nube sin mezclar pasando por la sonda
19:47:34   7,14
19:48:42   7,36
```

Ese 6,79 **no es el pH de la piscina**. La sonda está en la tubería y lee lo que le llega; durante
unos segundos le llegó agua de la zona de vertido. Se recupera solo en dos minutos.

**No corregir nunca sobre esa lectura.** Y es justo el motivo por el que se vierte *paseando* y con
la filtración en marcha: quieto en un punto, esa nube es mucho más concentrada y dura mucho más.

## Conclusión

Las tres alarmas de este verano —junio, 11 de agosto y hoy— salen del mismo sitio. Con la bomba
sana, producto disponible e inyección limpia, `PUMPSTOP PH` es un **síntoma de alcalinidad alta**, no
un fallo mecánico.

**El TAC es lo único que queda por arreglar** — y, en segundo plano, las horas de filtración.

> ⚠️ **La magnitud de ese TAC quedó en entredicho al día siguiente.** El diagnóstico cualitativo
> —alcalinidad alta frenando la regulación— se mantiene; el número 240 no. Ver **Episodio 5**.

---

# Episodio 5 — 2026-08-16: el TAC 240 se cae

## Síntoma

Medición con **tiras reactivas**: cloro libre OK, pH en banda, y **alcalinidad 40**. El plan entero
(`plan-bajar-alcalinidad-piscina-2026-08-11.md`, 30 L de producto en 6 días) está calculado sobre un
**TAC de 240**. Entre 40 y 240 no hay margen de error: hay un instrumento mintiendo.

## El árbitro: una titulación que hicimos sin querer

La dosis manual del día 15 fue, sin pretenderlo, **una titulación ácido-base con el pH registrado
minuto a minuto**. Eso permite calcular la alcalinidad sin ningún reactivo.

```
1 kg de bisulfato sódico (NaHSO₄, M = 120,06 g/mol)
  = 8,33 mol de H⁺  en 40 m³
  = 0,208 meq/L de ácido añadido

pH:  7,74 (19:05)  →  mínimo 7,28 (19:56)
```

Resolviendo el equilibrio del carbonato (pK₁ = 6,35) para la alcalinidad `A` que produce esa bajada:

```
A - h = 10^(pH₂ - 6,35) · ( A / 10^(pH₁ - 6,35) + h )

→  A ≈ 3,0 meq/L  ≈  150 mg/L CaCO₃
```

Y al revés, lo que cada hipótesis **habría predicho** para esa misma dosis:

| TAC supuesto | Bajada de pH predicha | pH final |
|---|---|---|
| 240 (el del plan) | −0,33 | 7,41 |
| **~150** | **−0,46** | **7,28** ✅ observado |
| 40 (la tira) | −1,00 | 6,74 |

**Con alcalinidad 40 el pH se habría hundido un punto entero.** No hay tampón que absorba un kilo de
ácido en 40 m³. No pasó: se quedó en 7,28 y volvió a subir con una pendiente suave y constante toda
la noche. Eso es agua tamponada.

Los dos sesgos del método empujan en la misma dirección, así que **150 es techo, no suelo**:

- el CO₂ se desgasifica durante los 51 min de medición → sube el pH → el descenso real fue mayor
- si algo de producto quedó sin disolver, el ácido efectivo fue menor

## Por qué la tira no vale — dos motivos independientes

**1. El punto de toma.** La muestra se cogió **cerca de las impulsiones**. El plan lo prohíbe
explícitamente (centro de la piscina, un palmo de profundidad) y no por capricho: el clorador inyecta
en la línea de retorno, así que el agua que sale por la boquilla no es el agua de la piscina — es la
que acaba de pasar por la célula y por el punto de inyección de ácido. Sesga a la baja.

**2. La tira se contradice a sí misma sobre agua que no se movió.** Dos lecturas el mismo día:

```
~09:00   tira:  pH 7,2 - 7,8
~11:00   tira:  pH 7,2 - 7,6
         sonda: pH 7,72 - 7,74 durante toda la mañana, sin moverse
```

**7,74 está fuera de la banda 7,2-7,6.** La sonda no cambió, la tira sí, y la segunda lectura excluye
el valor verdadero. La reproducibilidad de la tira es de ±0,2-0,3 en el mejor caso.

> Y el argumento que cierra el asunto: **si el pad de pH falla de forma demostrable, no hay ninguna
> razón para creerle al pad de alcalinidad**, que es el menos fiable de todos los de una tira.

La sonda, en cambio, tiene validación independiente: está calibrada **y** su respuesta a una dosis
conocida de ácido cuadra con el modelo del carbonato. Es el único instrumento de los tres con una
comprobación externa.

## Consecuencia: plan suspendido

> 🛑 **ACTUALIZADO EL 17-08.** El plan ya no está suspendido: está **CANCELADO**. Y de los tres
> números de esta sección, **el único que sobrevivió fue el ~150** — la titulación del día 15 era
> buena. Ver **Episodio 6**.

| | |
|---|---|
| TAC de partida real | **~150**, no 240 |
| Objetivo | 120 |
| Producto necesario | **~7,5 L**, no 30 L |
| Si se ejecuta el plan como está | TAC final ≈ **30** → agua agresiva |

Un agua en TAC 30 ataca juntas, gresite y el recubrimiento de los electrodos de la célula. Habríamos
convertido el problema en otro peor y más caro.

> **El fallo de método:** el 240 salió de una medición del 11-08 cuyo instrumento nunca quedó
> registrado, y jamás se verificó con un segundo método. Un número que sostiene un plan de 30 L y
> seis días tenía que haberse confirmado **antes** de escribir la primera línea del plan.

**Pendiente:** medir la alcalinidad por **titulación de gotas** (o análisis en tienda), con la muestra
del centro de la piscina. No comprar producto ni dosificar nada hasta tener ese número.

## Artefacto de lectura: la primera muestra tras cada arranque miente

Confirmado en **los cinco arranques registrados**. Tras cada corte de corriente, el primer sondeo
devuelve una caché rancia, y siempre **lee alto**:

| Arranque | 1ª muestra | 2ª muestra |
|---|---|---|
| 15/22:03 | 7,69 | 7,41 |
| 16/00:49 | 7,66 | 7,55 |
| 16/03:49 | 7,77 | 7,68 |
| 16/06:48 | 7,80 | 7,74 |
| 16/09:47 | 7,82 | 7,74 |

Vale igual para las otras magnitudes — en el arranque de las 09:47: ORP 695 → 686, temperatura
28,0 → 27,5 °C. Y el mismo fantasma aparece en la cloración: un `0.0` suelto el día 15 a las
15:42:20, en mitad de una parada.

> **Regla: descartar siempre la primera muestra posterior a un arranque y leer desde la segunda.**

## Atributos de la integración que no son de fiar

```
number.piscina_chlorinator_consigna_ph
  ph_range:           "6.8-7.6"   ← falso: el equipo aceptó 7,8 sin problema
  friendly_name:      "PH 7.6"    ← congelado en la consigna de anteayer
  current_ph_reading:  7.8        ← este sí se refresca
```

Se frenó una escritura de 7,8 por culpa del `ph_range`, y el rango era mentira. **Para leer la
consigna, `current_ph_reading`. El nombre y el rango son restos.**

## El experimento que no discriminaba

Se propuso usar la ventana de parada del reloj para separar las dos causas de la subida del pH:
si sube con la célula sin corriente, es desgasificación de CO₂; si no, es la célula.

```
08:52  pH 7,74   →   09:48  pH 7,74      plano en 55 min
```

**El resultado no vale, porque el test estaba mal diseñado.** La parada quita **dos** variables con un
solo interruptor: para la célula *y* para la circulación, que es lo que agita la superficie y permite
que el CO₂ escape. Las dos hipótesis predicen exactamente lo mismo con la bomba parada.

Peor: **sin ninguna entrada de ácido ni de base, cualquier agua mantiene su pH, tenga el tampón que
tenga.** Sobre la alcalinidad, el dato aporta cero.

Lo único que sí demuestra: no hay ningún tercer proceso moviendo el pH con el grupo parado. Todo lo
que le pasa a esta piscina pasa en las ventanas ON.

> **Lección de método:** un test que da el mismo resultado tanto si la hipótesis es cierta como si es
> falsa no es un test. Antes de leer el resultado, escribir qué se vería en cada caso — si las dos
> columnas salen iguales, el experimento está mal antes de empezar.

## El test bien hecho: célula al 0 %

Un interruptor, una variable. Siguen la circulación y la aireación; solo deja de producir la célula.

```
10:14:58   nivel_de_cloro   60 %  →  0 %        ← t0
10:17:03   consigna_ph      7,7   →  7,8        ← saca del test a la bomba de ácido:
                                                   con el pH en 7,74 y consigna 7,8, no dosifica
partida:   pH 7,74   ·   ORP 698
```

**Control de validez — el que faltaba en el intento anterior: el ORP tiene que bajar.** Si la
cloración se queda de verdad en 0, el redox cae ~18 mV/h. Si el ORP no se mueve, el comando no llegó
al equipo y un pH plano no probaría nada.

**Aborto** si el ORP baja de 655 (el suelo operativo son 650).

Resolución mínima para poder concluir algo:

```
subida esperada  0,023 - 0,046 pH/h        resolución del sensor: 0,01
24 min  →  0,009    por debajo de la resolución: no concluir nada
46 min  →  0,018 - 0,035    ya se distingue
90 min  →  0,035 - 0,069    inequívoco
```

**Restaurar al terminar: cloración 60 %, consigna 7,70.**

### Resultado

```
10:14:58   pH 7,74   ORP 698     ← t0, célula a 0 %
11:02      pH 7,74   ORP 698     ← 47 min: PLANO
11:12:55   pH 7,77   ORP 698     ← 58 min: +0,03
11:44:29   pH 7,77   ORP 698     ← 89 min, fin del test

subida con la célula apagada:  +0,03 en 89 min  =  0,020 pH/h
```

Contraste con las subidas medidas **con la célula al 60 %**:

| Momento | Célula | Subida | Contexto |
|---|---|---|---|
| 15/tarde | 60 % | 0,023 pH/h | sin ácido reciente |
| 15/noche | 60 % | 0,046 pH/h | **horas después de echar 1 kg de ácido** |
| 16/mañana | **0 %** | **0,020 pH/h** | sin ácido reciente |

**La célula no es el motor de la subida del pH. Es el agua.** Con la producción apagada el pH sube
prácticamente igual que con ella al 60 %.

Y la coherencia interna refuerza el mecanismo: la subida más rápida de las tres (0,046) es justo la de
las horas siguientes a la dosis de ácido, que es cuando la sobresaturación de CO₂ es máxima. **El
ritmo correlaciona con el ácido reciente, no con la célula.**

> **Consecuencia operativa: bajar el porcentaje de cloración NO arregla el pH.** Queda descartada la
> táctica escrita el día 15 de producir menos para que el ácido no pelee con la célula. La palanca es
> la alcalinidad, y solo la alcalinidad.

### La trampa de leer antes de tiempo

```
a los 47 min   pH plano        →  conclusión: "el motor es la célula"
a los 89 min   pH +0,03        →  conclusión: "el motor es el agua"
```

**Conclusiones opuestas según cuándo se mire.** El cálculo de resolución fijado *antes* de empezar
decía que a 47 minutos la señal esperada (0,018-0,035) apenas superaba la resolución del sensor
(0,01), y que la lectura inequívoca era la de 90 minutos. Cerrar en el checkpoint habría dado la
respuesta contraria con toda la apariencia de un resultado limpio.

### El control de validez nunca confirmó

El ORP no cayó en los 89 minutos (698 → 698).

- **A favor** de que la célula sí paró: venía subiendo +13 mV en los 29 min previos (686 → 699 entre
  las 09:48 y las 10:17) y **se cortó en seco exactamente en t0**.
- **En contra:** nunca llegó a bajar.
- **Atenuante:** la expectativa de −18 mV/h estaba mal fundada — salía de la parada del día 15
  (680 → 644), y ese 644 es uno de los sondeos post-arranque que este mismo episodio demuestra que no
  son fiables. Se construyó la expectativa sobre un dato ya sabido malo.

**Veredicto: fuertemente sugerente, no probado.**

## El reloj: la duda del disco desfasado, resuelta

El día 15 se cambió el reloj a 2 h ON / 1 h OFF y quedó la duda de si el disco estaba bien puesto.
No hace falta cronometrar nada: **cada arranque y cada parada quedan grabados**, y con la noche
entera registrada el horario real sale solo.

```
ON  22:04-23:56 | 00:49-02:42 | 03:48-05:40 | 06:48-08:55 | 09:47-11:54

ciclo ~3 h  ·  ~1 h 53 en marcha  ·  duty 63 %  →  15,1 h/día
```

**El cambio funcionó**: se pasó de 12 h/día a 15,1. Objetivo cumplido.

**Pero el disco va ~12 minutos adelantado** respecto a la hora real. Los bloques arrancan a las
00:49, 03:48, 06:48 y 09:47 en vez de en punto, y el desfase es consistente en los cuatro:

| Nominal | Real | Desfase |
|---|---|---|
| 01:00 | 00:49 | −11 min |
| 04:00 | 03:48 | −12 min |
| 07:00 | 06:48 | −12 min |
| 10:00 | 09:47 | −13 min |

No es grave, pero importa para programar las tomas del tratamiento: cada dosis quiere **1 h de
filtración posterior**, y con el disco adelantado esa hora empieza y acaba antes de lo que marca el
reloj de pared.

> Las paradas son menos limpias (±8 min) porque la transición a `unknown` se detecta en el sondeo
> siguiente, no en el instante del corte. Los **arranques** sí son inmediatos, y por eso son los que
> valen para medir el desfase.
>
> **CORRECCIÓN (20-08):** la conclusión operativa es correcta —el arranque es el bueno— pero el
> motivo escrito aquí es falso. El sondeo es de **34 s**, así que no puede explicar ±8 min. Los
> minutos de las paradas los pone la **caché de la nube de Fluidra**, que sigue sirviendo el último
> valor conocido después del corte. Ver «20 de agosto».

## Pendiente

- [x] **Alcalinidad**, resuelta el 17-08 por titulación limpia: **85–110 mg/L**. Ver Episodio 6.
- [x] Recalcular las secciones 2 y 5 del plan — hecho: el plan queda **CANCELADO**, no reanudado.
- [x] Resultado del test de la célula al 0 %.
- [ ] Caudal **real** de la bomba peristáltica. No la placa: medirlo con recipiente graduado y modo
      cebado, 60 s cronometrados. El tubo de silicona se cansa y entrega menos que el nominal.
- [ ] Alarma `HIGH SALT` del 15-08 a las 23:13 (1 min, salinidad 5,36-5,43). Probablemente **falsa**:
      ver Episodio 6, el clorador lee la sal ~1 g/L por encima de un medidor de mano contrastado.

---

# Episodio 6 — 2026-08-17: la alcalinidad estaba bien desde el principio

El día más largo del proyecto, y el que más conclusiones propias tumba. Termina con el problema
central **cerrado** y con un desastre esquivado por leer una etiqueta.

## Resultado: TAC = 85–110 mg/L

La primera titulación del proyecto hecha en condiciones válidas: **célula recién limpia**, **las dos
bombas en marcha** (mezcla rápida), concentración de producto conocida, hora anotada al minuto y
sonda contrastada contra un segundo instrumento.

```
15:20:58   pH 7,74   basal
15:35      vertido de 2,0-2,5 L de minorador al 14,4 %, diluido, paseando por el borde
15:39:12   pH 6,95   MÍNIMO
15:48:52   pH 7,21   MESETA DE MEZCLA
17:04:21   pH 7,28   ya contaminado por desgasificación
```

Resolviendo el equilibrio del carbonato (pK₁ = 6,35) para la bajada 7,74 → 7,21:

| Volumen vertido | TAC antes | **TAC actual** |
|---|---|---|
| si 2,5 L | 118 | **108** |
| si 2,0 L | 94 | **86** |

**Corroborado por un método independiente**: tira reactiva AstralPool 7-en-1, bien tomada, leída por
el usuario sobre la tira física: **TA 80-120**. Química y física de acuerdo.

**El objetivo del plan eran 120. El agua ya estaba por debajo.** El plan se cancela: no hay nada
que bajar. Y el riesgo cambia de lado — si el valor real es 86, está rozando el mínimo sano de 80.

## El hallazgo de método: el mínimo NO es la respuesta

Ese `6,95` de las 15:39 no es la alcalinidad. Es **la nube de ácido concentrado pasando por delante
de la sonda** cuatro minutos después de verter. Si fuera equilibrio, no rebotaría — y rebotó a 7,21
en nueve minutos.

Esto es exactamente el artefacto que el 16-08 se **dedujo** como causa del error del día 15. Hoy
queda **grabado en directo**, y con un dato que cambia la conclusión anterior:

> **El artefacto se resuelve en ~13 minutos, no en horas.**

Lo cual invalida el razonamiento del Episodio 5 que decía que el 150 estaba subestimado porque
51 min era «un cuarto de renovación». A los 51 minutos el agua ya estaba equilibrada. **Aquel 150
era correcto**, y encaja con la cronología: ~155 el 11-08, 150 el 15-08, ~120 hoy antes de dosificar.

> **Regla: en una titulación de piscina se lee la MESETA DE MEZCLA, nunca el mínimo, y nunca horas
> después** — la desgasificación de CO₂ (medida hoy: 0,055 pH/h) infla el resultado, porque sube el
> pH **sin cambiar la alcalinidad**.

## Casi desastre: el ácido nuevo es 3,1 veces más fuerte

Se sustituyó la garrafa por **Reductor pH- líquido MG, ácido sulfúrico al 38 %** (UN2796). Todo el
plan estaba calculado sobre **AstralPool pH Minus al 14,4 %**.

| Producto | Concentración | Densidad | Puntos de TAC por litro |
|---|---|---|---|
| AstralPool pH Minus | 14,4 % | ~1,10 | **4,0** |
| Reductor pH- líquido MG | 38 % | ~1,29 | **12,5** |

Verter los 30 L del plan con el producto nuevo habría dado **375 puntos** de reducción sobre un agua
con ~100: alcalinidad cero y pH desplomado.

El consejo de la tienda —«en salinas va reductor, no minorador»— **no se sostiene**: son el mismo
compuesto, ácido sulfúrico. Lo único que cambia es la concentración.

> **Pendiente de verificar en el manual: la concentración máxima que admite la peristáltica**, que
> ahora aspira 38 % cuando venía trabajando con 14,4 %.

## La célula estaba muy incrustada — y la culpa no era del ácido

Dos baños de NETCEL (HCl 3,45 %), ninguno de 10 minutos, siguiendo **la regla del burbujeo en vez
del reloj**. Quedó impecable y montó sin fugas.

La hipótesis del usuario era que el ácido vertido estos días había acelerado la incrustación. **Es
al revés**, y lo demuestra su propia observación: la cal **burbujeaba** con el limpiador, luego es
carbonato — y el ácido *disuelve* carbonato.

**La cal se formó en los huecos SIN ácido**: el 11-13/08 con la bomba bloqueada y el pH en 8,87, y
la noche del 16 al 17 con `PUMPSTOP` enclavado ocho horas y el pH subiendo a 7,99.

Se descarta el plan de limpiar cada dos semanas: **cada baño de ácido se lleva parte del
recubrimiento de óxidos de Ru/Ir**, que es lo que produce el cloro y lo caro de la pieza. Una o dos
veces por temporada.

## `PUMPSTOP`: modelo cerrado

> **Se suelta solo cuando el pH vuelve por debajo de la consigna. Queda enclavado mientras siga por
> encima.**

Confirmado tres veces el mismo día, la última a las **15:36:55**, justo al cruzar el pH por debajo
de 7,70. Las ocho horas de la noche anterior no fueron avería: la condición nunca se resolvió.

## Cómo medir el TAC sin reactivos y sin tiendas

El kit de gotas del usuario solo hace cloro y pH. No hace falta comprar nada: **cada dosis futura es
una medición gratis**, siempre que se haga así.

1. **PESAR el producto.** 14,4 % = 1,10 kg/L · 38 % = 1,29 kg/L. Una báscula de cocina es más precisa
   que una jarra. La duda entre 2 y 2,5 L fue **lo único** que dejó el resultado de hoy en banda.
2. Dosificar **con las dos bombas en marcha**, diluido, paseando por el borde. Nunca con el grupo
   parado: el ácido es más denso, se estratifica y ataca el fondo.
3. **Anotar la hora exacta.**
4. Leer la **meseta a los 15 minutos**. Ni el mínimo, ni horas después.
5. Resolver `pH = 6,35 + log((A−c)/(A/10^(pH₀−6,35) + c))` para `A`.

## Correcciones a episodios anteriores

| Afirmación | Estado |
|---|---|
| TAC 240 (11-08) | **DESCARTADO.** Instrumento nunca registrado; contradice el balance de ácido |
| TAC 150 (titulación 15-08) | **RESTITUIDO.** Era correcto; el Episodio 5 lo demoté sin razón |
| TAC 40 (tira 16-08) | **DESCARTADO.** Punto de toma en las impulsiones |
| «El equipo no rearma solo el `PUMPSTOP`» | **FALSO.** Rearma, bajo condición de pH |
| «El disco del reloj gana 23 min/día» | **FALSO.** Lo movió el usuario a mano el 16-08 |
| «La alcalinidad alta es la causa de todo» | **MATIZADO.** Con TAC ~100 no hay tamponamiento extremo |

## Hallazgos sueltos

- **Ácido cianúrico = 0.** Sin estabilizador el sol destruye el cloro libre en horas; explica que la
  célula trabaje al 60 %. **No tocar todavía** — una variable cada vez, y el cianúrico solo se va
  por dilución, así que pasarse no tiene marcha atrás.
- **Dureza ~300+.** Con eso, el TAC y 28 °C, agua incrustante. Explica la célula.
- **Lámina de agua: 7,5 × 3,5 m = 26,25 m².** Dato nuevo del 18-08. Cuadra con los 40 m³:
  profundidad media **1,52 m**. De aquí sale la conversión que faltaba: **1 cm de nivel = 262 L**,
  y un cuadro de gresite de 2,5 cm = **656 L = 1,64 % del vaso**.
- **EL RELLENO ES LA FUENTE DE LA CAL, y es un trinquete de un solo sentido.** Solo se evapora agua
  pura: todo el calcio y toda la alcalinidad que entran con el relleno **se quedan dentro**. A los
  5-8 mm/día típicos de agosto son 130-210 L/día, o sea un cuadro de gresite cada 3-5 días, y
  **16-25 m³ en una temporada — entre el 40 % y el 63 % del vaso**. Con un agua de red de dureza
  300, eso son **4,8-7,6 kg de CaCO₃ metidos al año**. La alcalinidad tiene quien se la coma (la
  bomba de ácido); **la dureza no tiene NINGUNA vía de salida salvo vaciar**. Por eso sube sola
  hasta 300+ y por eso se incrusta la célula.
- **Subir el TAC rellenando con agua de red NO SALE.** `ganancia = fracción × (TA_red − TA_piscina)`.
  Un cuadro de gresite con un agua de red generosa (TA 250) sobre una piscina a 40: `0,0164 × 210 =
  3,4 mg/L`. Para ir de 40 a 80 harían falta **7.620 L, casi 12 cuadros**. El bicarbonato equivalente
  son **2,7 kg** (1,68 g por m³ y por mg/L) y **no mete ni un miligramo de calcio**. El relleno
  ahorraría unos euros a cambio de más de lo único que ya rompió una pieza.
- **Hay DOS bombas de filtración.** La segunda sirve para mezclar rápido al dosificar y para titular
  limpio. Dato que no estaba registrado en ninguna parte.
- **Bomba de filtración: Hayward, P₂ 0,61 kW, 230 V, 2830 rpm, 3,78 A.** → 12-14 m³/h → renovación
  de los 40 m³ en **~3 h** → **4,6 renovaciones/día** con las 15,1 h actuales. **El horario está bien.**
- **La sonda de pH está sana**: 7,74 contra 7,7 de un medidor de mano IUZMAR. Primera vez en el
  proyecto que dos instrumentos coinciden en un parámetro.
- **La sal del clorador lee ~1 g/L alto.** Clorador 5,3 vs IUZMAR 4,3. El árbitro es la conductividad
  bruta del medidor de mano: **8500 µS ≈ 4,5 g/L** (para 7,6 g/L harían falta 13.600 µS). La alarma
  `HIGH SALT` del 15-08 es, casi seguro, falsa. **No añadir sal.**
- **La consigna se queda en 7,70.** Bajarla a 7,2-7,4 como decía el plan aumentaría la sobresaturación
  de CO₂, la desgasificación y con ello el ácido que la bomba tiene que echar cada día. Con el TAC
  cerca del suelo, **la consigna alta protege**.
  > ⚠️ **El MOTIVO de este punto caducó, no la conclusión.** El «TAC cerca del suelo» era el TA 40 de
  > la tira mal tomada; la titulación del 17-08 lo puso en 85-110, en banda. La consigna sigue en 7,70,
  > pero por el argumento del índice de Langelier — ver «19 de agosto, tarde».


## Lectura de la noche 17→18 de agosto: las dos predicciones, contestadas

Ventana leída del recorder: **17-08 17:00 → 18-08 07:30**, célula recién limpia, sin intervención
humana. Las dos predicciones estaban escritas **antes** del dato, y salen con signos opuestos.

### Predicción 1 — la salinidad: **FALLA**

Decía: si la cal engañaba al sensor, con la célula limpia la sal debería bajar a **4,3-4,7**.

```
Media de la noche (22:00-07:30, n=1007)   5,774 g/L
Mediana                                   5,65
Rango                                     5,48 - 6,55     (sd 0,238)
Último valor (07:30)                      5,52
Referencia con célula SUCIA               5,04 - 5,07
```

Con la célula limpia **la lectura SUBE**, no baja. La cal no era lo que inflaba el número: es un
**offset de calibración del clorador**, de **+1,3 g/L** contra el IUZMAR (4,3) y contra el árbitro
de conductividad (8500 µS ≈ 4,5 g/L). Queda confirmado que **no hay que añadir sal** y que la
alarma `HIGH SALT` del 15-08 es del instrumento, no del agua.

Hallazgo de método añadido: **el sensor de sal oscila ±0,5 g/L**. «El valor asentado» no existe en
este aparato. Cualquier lectura suelta de salinidad es ruido; solo vale la **media de una ventana
larga**.

### Predicción 2 — el `PUMPSTOP`: **ACIERTA, y limpio**

Decía: con el TAC en ~100 en vez de ~200, la bomba alcanzaría la consigna sin agotar su tiempo, así
que habría **menos eventos, o ninguno**.

**Ninguno. Cero alarmas en 14,5 horas.** `active_alarm_count` = 0 en las 989 muestras de la ventana.

Y la regulación se ve entera en la traza de pH:

```
17/08 17:00   7,28   ← cierre de ayer, tras la titulación
17/08 22:00   7,44   ← deriva natural al alza (desgasificación de CO2)
18/08 02:00   7,63
18/08 04:45   7,70   ← alcanza consigna
18/08 07:23   7,68   ← ~3 h clavado en 7,68-7,72
```

La bomba sube hasta la consigna y **la sostiene plana tres horas**. Eso es una peristáltica sana
regulando contra un tampón normal. Es la **tercera vía independiente** que confirma el TAC ~100:
titulación, tira bien hecha, y ahora el comportamiento del lazo de control.

Corolario: **ya no hay motivo para sospechar de la peristáltica**. El pendiente de medir su caudal
real baja de prioridad — sigue estando bien hacerlo, pero ya no es diagnóstico de nada.

### Lo demás de la ventana

```
ORP        700,8 de media (682-709), estable      cloración 60 %, consigna pH 7,70
Temp       29,6 -> 28,1 ºC (enfriamiento nocturno normal)
```

- **El cloro libre NO SE MIDE, y no es un fallo: la máquina no puede.** Corrección de una nota
  anterior de hoy que decía que «el sensor existe pero no da valor». No existe. Ya no está en
  `core.entity_registry`, y en el recorder solo quedan **4 filas muertas** (12-08 a 15-08, todas
  `unavailable`). Era un fantasma del catch-all genérico, que sí declara `c178`; al aterrizar el
  perfil propio del equipo (Issue #82) la entidad desapareció. El perfil `lc24009904_chlorinator`
  llama a `_standard_tecnolc2(["LC24009904.nn_*"], priority=87)` **sin el argumento
  `free_chlorine=`**, así que `c178` ni siquiera se consulta. Y la ficha del equipo lo dice:
  *KLINWASS (tecnoLC2 with pH + ORP probes)* — **dos sondas, no tres.**
  **El ORP es la única medida de desinfección que da esta instalación.**
- **Cinco cortes de conexión con la nube**, `device_offline=true`, de 55-70 min cada uno:
  17:26, 20:27, 23:27, 02:13, 05:12. **Cadencia de ~3 h, demasiado regular para ser aleatoria** —
  huele a horario de filtración (el clorador se queda sin corriente con la bomba), no a wifi.
  No es una avería, pero conviene contrastarlo con el disco del reloj.

## 18 de agosto, 08:05: la tira, leída con un colorímetro en vez de con el ojo

Tres fotos del mismo test: **dos a los 20 s** y **una al minuto**, la tira sobre el bordillo y el bote
al lado. En vez de comparar a ojo, se midieron los píxeles: se muestrea cada parche y **cada patrón
de la carta del bote en la MISMA foto**, se normaliza cada uno con su blanco local (el papel de la
tira, la etiqueta del bote) y se busca el patrón más cercano en **espacio Lab (ΔE)**.

Esto elimina de raíz el problema que arruinó las lecturas del 15 y el 16: **el balance de blancos ya
no importa**, porque tira y carta reciben la misma luz en la misma imagen.

```
            20 s (foto 1)     20 s (foto 2)      1 min (foto 3)
  FC            2  ΔE 2           2  ΔE18            2  ΔE13
  TC            5  ΔE 9           5  ΔE10           10  ΔE15
  pH          6,8  ΔE 9         7,2  ΔE15          7,5  ΔE15
  TA           40  ΔE11          40  ΔE16           40  ΔE10
  TH          300  ΔE21         300  ΔE21          800  ΔE28
  CYA           0  ΔE13       30-60  ΔE30*       30-60  ΔE 9
```
\* En la foto 2 el patrón «0» de CYA y TA queda cortado por el borde del bote: la elección es forzada,
y su ΔE de 30 significa «ninguno de estos encaja», que es justo lo que se espera si el verdadero es
el que falta.

### El resultado bueno: **CLORO LIBRE = 2 ppm**, y es la mejor medida del proyecto

**ΔE 2,3.** Por debajo de 3 la diferencia es imperceptible al ojo humano. El segundo candidato queda
a ΔE 11, cinco veces más lejos. Y **sale 2 ppm en los tres fotogramas**. No hay ninguna otra medición
en estas dos semanas con este respaldo.

2 ppm cae **en el centro exacto de la banda IDEAL** de la tira (1-3). **La cloración NO está baja.**
La queja del 09-08 que abrió todo esto queda cerrada: entonces sí lo estaba (ORP 565), hoy no.

### Los tres instrumentos cuadran por primera vez

```
sonda de pH   7,70   (y el IUZMAR de mano dio 7,7 → la sonda está sana)
tira          FC 2 ppm
clorador      ORP 700-709 mV
```
A 28 °C el pKa del HOCl ronda **7,50**. A pH 7,70 la fracción activa es
`1/(1+10^(7,70-7,50)) = 39 %` → **HOCl ≈ 0,77 ppm**. Sin estabilizador, eso corresponde a un ORP de
**700-720 mV**. Se mide 700-709. **Cuadra.** Cloro correcto, pH correcto, ORP correcto: el sistema
está sano y las tres medidas se sostienen entre sí.

### Por qué NO vale la lectura del minuto, aunque el pH «encaje mejor»

Hipótesis del usuario: al minuto los colores parecen más acordes con el clorador. En el pH **tiene
razón en el dato**: 7,5 al minuto está más cerca del 7,70 de la sonda que el 6,8 de los 20 s.

Pero la conclusión no se sostiene, y la prueba está en la propia foto. Entre los 20 s y el minuto se
mueven **cuatro parches**, y **dos de ellos miden magnitudes que no pueden cambiar en 40 segundos**:

- **Dureza: 300 → 800.** La dureza cálcica no se duplica en 40 segundos.
- **Cianúrico: 0 → 30-60.** El estabilizador no aparece de la nada en 40 segundos.

No hace falta saber cuál es el valor verdadero de ninguno de los dos: **basta con que no puedan
cambiar.** Si cambian, lo que se está midiendo es el reloj, no el agua. El parche de pH no «acierta»
al minuto: va subiendo y de paso cruza por la respuesta que esperábamos. Si se espera más, se pasa
a 7,8 y luego a 8,4.

**Regla nueva, y esta es dura:** *una lectura que depende de cuánto rato la mires no es una lectura.*
Los 20 segundos del fabricante no son una recomendación, son el punto de calibración.

### Lo que queda abierto

- **TA = 40 en los TRES fotogramas**, contra los **85-110** de la titulación del 17-08. Es el único
  conflicto que sobrevive al método nuevo, y ya no se puede achacar a la foto. Da igual para la
  acción inmediata (**no se echa ácido en ninguno de los dos casos**), pero **no da igual para la
  contraria**: si de verdad fuese 40 estaría por debajo del suelo sano de 80 y tocaría **subirlo con
  bicarbonato**. → **Comprar el reactivo de gotas de TA.** Es lo único que cierra esto.
- **TC = 5 con FC = 2** en los dos fotogramas de 20 s, es decir **~3 ppm de cloro combinado**
  (cloraminas), muy por encima del 0,5 habitual. El ΔE del parche TC es flojo (9-10) frente al 2,3
  del FC, así que **no se actúa: se repite el test** mirando solo ese parche.

## 18 de agosto, tarde: tres tiras, y el descalcificador no descalcifica

Tres tomas, una tira cada una: **piscina**, **grifo supuestamente descalcificado** y **agua sin
descalcificar**. Mismo método colorimétrico. La carta de la foto de piscina salió desenfocada, así
que se usó la de la foto del grifo como patrón para las tres, normalizando cada tira con su propio
papel.

**Aviso de calidad, por delante:** la luz de tarde es mucho peor para esto. Los ΔE de esta tanda
salen entre 10 y 35, contra el 2-16 de la mañana. Y hay una prueba interna de que los **valores
absolutos** llevan error: las dos tiras de grifo dan **CYA 30-60**, y en agua de red **no hay ácido
cianúrico, es imposible**. Por eso lo que se firma aquí son las **diferencias**, no los absolutos:
las tres tomas son de la misma sesión, con la misma luz y minutos aparte, y ahí la comparación sí
aguanta.

### 1. El agua de red ES más alcalina que la piscina. Confirmado

```
                        FC     TC     pH     TA     TH      CYA
  piscina                2     10    7,2    120    300    30-60
  grifo "descalcif."     0    0,5    7,8    180    300    30-60
  grifo sin descalc.     0    0,5    7,5    180    800    30-60
```

Diferencia directa piscina ↔ grifo en el parche de TA: **ΔE 31,6**. Para calibrar cuánto es eso, un
escalón entero de la carta en esa zona vale 18-25 ΔE (80→120 = 18,4; 120→180 = 24,8). O sea que el
grifo está **más de un escalón completo por encima** de la piscina. La sospecha era correcta.

### 2. Pero la piscina no necesita alcalinidad, así que da igual

El parche de TA de la piscina da **120, y con ΔE 8: el mejor emparejamiento de toda la tanda de
tarde.** Sumado a la titulación del 17-08 (85-110), son **dos métodos independientes en la banda
85-120**.

**El 40 de la mañana queda como el dato descolgado y se retira.** Tenía ΔE 10-16 (mediocre) y ahora
tiene dos medidas en contra. 120 está en la parte alta de la banda ideal: **no hay nada que subir.**

Con eso, la aritmética del relleno se hunde del todo:

```
ganancia por cuadro = 0,0164 × (180 − 120) ≈ 1 mg/L
```

**Un punto por cuadro de gresite.** Y aunque el grifo estuviese dos escalones por encima, serían 2.

**Conclusión doble: ni bicarbonato ni relleno.** El bicarbonato ya no es que sea innecesario, es que
metería el TAC por encima de la banda.

### 3. EL HALLAZGO: el descalcificador no está haciendo nada

Comparando las dos tiras de grifo entre sí, parche a parche:

```
  FC   ΔE  5,1     TC   ΔE  3,8
  pH   ΔE  9,0  ←  canal nulo: un descalcificador NO cambia el pH
  TA   ΔE  9,5  ←  canal nulo: NI la alcalinidad (intercambia Ca por Na, el bicarbonato se queda)
  TH   ΔE 10,0  ←  AQUÍ tendría que estar toda la señal
  CYA  ΔE 12,4
```

El pH y la alcalinidad **tienen que salir idénticos** entre agua blanda y dura: eso fija el suelo de
ruido de esta comparación en **ΔE 9-10**. Y la dureza sale en **10,0**. Exactamente el ruido.

Y ahora la magnitud que debería tener si funcionara. En la propia carta:

```
  TH  0 vs 300   ΔE = 103,1      ← lo que se esperaría de un descalcificador que descalcifica
  TH  150 vs 300 ΔE =  21,5      ← lo que se esperaría de uno que va a medio gas
  observado                10,0
```

**Se esperan 103 y se miden 10.** Ni siquiera llega a la mitad de lo que daría un descalcificador
funcionando a medias. Las dos aguas son la misma agua.

Remate: el parche de dureza de la **piscina** contra el del **grifo** da **ΔE 5,2** — la piscina está
tan dura como el grifo del que se llena, que es justo lo que predice el trinquete del relleno.

### CAUSA CONFIRMADA POR EL USUARIO: el descalcificador está sin sal

Lo dice él al leer el resultado: el aparato está en el parking **y lleva sin sal**. Encaja exacto con
la medida — sin sal no hay regeneración, la resina se satura y **el agua atraviesa el equipo sin que
la toque nadie**. De ahí el ΔE 10 en lugar de 103. Diagnóstico cerrado por dos vías independientes.

**PRECISIÓN IMPORTANTE, que corrige lo que dije antes de saberlo:** rellenar con agua descalcificada
**NO baja la dureza, la CONGELA.** El balance:

- Se evapora agua pura → el calcio se queda → la concentración SUBE.
- Se rellena con agua dura → entra más calcio → sube otra vez. **Trinquete.**
- Se rellena con agua blanda → el volumen se repone y la masa de calcio no cambia → **vuelve al punto
  de partida y ahí se queda.**

Para que la dureza BAJE hay que **sacar agua**, y eso solo pasa al **lavar el filtro** o al vaciar.
Con la sal puesta, cada contralavado pasa a ser una retirada real de calcio: el agua que se va lleva
sus 300 mg/L y la que entra a sustituirla no lleva ninguno. Lento y gratis.

**Y tiene suelo: no perseguir el cero.** Una piscina quiere **200-400 mg/L** de dureza. Por debajo de
~150 el agua se vuelve agresiva y empieza a comerse la lechada del gresite. Se pasa de incrustante a
corrosiva, que es el otro lado del mismo precipicio.

### Qué se hace con esto

- **Nada de bicarbonato. Nada de rellenar para subir el TAC.** Las dos vías están cerradas, y por
  motivos distintos: la primera porque no hace falta, la segunda porque no daría ni un punto.
- **Mirar el descalcificador.** Sal en el depósito de salmuera, válvula de regeneración, y sobre
  todo **si el bypass quedó abierto**. Es el único mando que actúa sobre la causa real de la cal.
- Un descalcificador que funcionara daría agua de relleno **con la misma alcalinidad y sin calcio**.
  No sirve para subir el TAC — la aritmética es la que es — pero **corta la entrada de cal de raíz**,
  que es lo que se comió la célula.
- **El reactivo de gotas de TA baja de prioridad.** Ya no hay conflicto que arbitrar: 85-110 y 120
  cuentan lo mismo.

## 18 de agosto, noche: sal echada, y la fontanería pasa a ser la incógnita

Acciones del usuario tras el resultado: **llena el descalcificador de sal y lanza un reciclo.**

**Ese primer ciclo no cuenta, y conviene que quede escrito por qué.** La salmuera necesita **4-6
horas** para saturarse, mejor toda la noche. Un ciclo lanzado justo después de echar la sal **aspira
agua, no salmuera**: la resina se regenera poco o nada. Medir ahora daría un resultado a medias y
llevaría a la conclusión equivocada — que el aparato está roto — cuando lo único que pasó es que no
se le dio tiempo. Y una resina saturada desde hace mucho puede necesitar **dos o tres ciclos**.

### El mapa de la fontanería, tal y como se declara el 18-08

| Punto | Estado declarado | Papel en la prueba de mañana |
|---|---|---|
| Jardín | **Va aparte** del descalcificador | Control negativo: debe salir duro |
| Grifo cerca de la piscina | **Sospecha de que lo dejó pasar** por el equipo | **La incógnita que decide todo** |
| Grifo interior lejano | Descalcificado | Control positivo: debe salir blando |

**Y aquí está el riesgo que puede tumbar todo el arreglo:** los grifos de exterior se cuelgan **antes**
del descalcificador a propósito, para no gastar sal en regar. Si el punto por el que se rellena la
piscina está aguas arriba, **se puede dejar el equipo perfecto y a la piscina no le llega nada**.

La buena noticia es que el propio test lo resuelve sin herramientas: tres tiras, tres grifos, una
sola foto. Si el interior sale blando y el de la piscina sigue duro, el corte está localizado.

### La purga: 20 litros, contados en cubo

Tirada conocida: **25 m de PPR 22**. El PPR se designa por diámetro **exterior**, así que el interior
ronda 15-16 mm.

```
25 m × ~15,5 mm interior   ≈  4,7 L   = un volumen de tubería
3 volúmenes                ≈  15 L    ← uno no basta: el agua se mezcla, no empuja en bloque
redondeo de trabajo           20 L
```

**Litros, no segundos.** El caudal de un grifo varía demasiado para fiarse del reloj. Es la misma
disciplina que el resto del proyecto: medir el recipiente, no estimar.

### La señal que hay que buscar mañana

El parche de dureza pasando de **magenta a azul**. Son unos **100 ΔE**: no hace falta colorimetría
ni ordenador, **se ve a simple vista**. Si no se ve a ojo, no ha pasado.

**Protocolo completo de mañana en `plan-descalcificador-2026-08-19.md`.**

## 19 de agosto, 18:28: el descalcificador ABLANDA — y el grifo de la piscina cuelga aguas arriba

Primer resultado positivo del aparato en todo el proyecto, y de paso queda contestada la pregunta de
fontanería que quedó abierta el 18-08.

### El material

Dos fotos de la misma tanda, tomadas con segundos de diferencia, con el bote de patrones al lado:

- **Foto A** — dos tiras (grifo de jardín y grifo cercano a la piscina).
- **Foto B** — las mismas dos, más una **tercera: el grifo interior más lejano de la piscina**.

Colorimetría con el método de la casa: línea central de cada tira ajustada por regresión, muestreo
del 50 % central de cada parche, **normalización con el blanco de su propia tira** (no con el de la
foto: cada tira está a una altura distinta y recibe distinta luz) y ΔE en Lab.

### El número

ΔE por parche, siempre entre tiras de **la misma foto** — misma luz, mismo instante, misma carta:

| Comparación | pH | TA | **TH (dureza)** | CYA |
|---|---|---|---|---|
| Foto A: tira 1 vs 2 | 8,2 | 10,1 | **6,0** | 13,1 |
| Foto B: tira 1 vs 2 | 3,8 | 4,8 | **0,4** | 3,1 |
| Foto B: tiras 1/2 vs **3** | 13,2 | 9,0 | **46,2** | 21,1 |

Suelo de ruido establecido el 18-08: **ΔE 9-10**.

Lab del parche de dureza:

```
tira 1  L 65,0   a* +44,2   b* -11,5     MAGENTA   → 300+ mg/L
tira 2  L 64,9   a* +44,5   b* -11,8     MAGENTA   → 300+ mg/L   (ΔE 0,4 entre ellas: la misma agua)
tira 3  L 59,6   a*  +4,4   b* -34,1     AZUL      → 0-100 mg/L
```

El parche **cambia de familia de color**, no de tono. Es la señal que el plan pedía buscar a ojo.

### El artefacto que había que descartar, y por qué no cuela

La tira 3 está **visiblemente más mojada** que las otras dos: recién sumergida. Y el 18-08 quedó
demostrado que el parche de dureza **deriva al alza** con el tiempo (300 → 800 entre los 20 s y el
minuto). Una tira leída demasiado pronto sale, por tanto, **falsamente azul**. La objeción es
legítima y hay que contestarla antes de celebrar nada.

La contesta el propio parche de al lado. **La alcalinidad de la tira 3 no se mueve**: ΔE 9,0, dentro
del ruido, y con el azul si acaso *más* revelado que en las otras dos. Si el problema fuera falta de
tiempo de revelado, **TA caería junto con TH**. No cae.

Y esa disociación —**dureza al suelo, alcalinidad intacta**— no es una casualidad de la foto: es la
**firma química del intercambio iónico**. Un descalcificador retira Ca²⁺ y Mg²⁺ y los cambia por Na⁺;
la alcalinidad, que son bicarbonatos, sale igual que entró. El resultado se valida solo.

### Qué queda decidido

Aplicando la tabla del Paso 3 del plan (fila 2):

| Interior lejano | Cercano a la piscina | Jardín | Lectura |
|---|---|---|---|
| **Blando** | **Duro** | **Duro** | El equipo **funciona**; el grifo de la piscina está **aguas arriba** del descalcificador |

- **El descalcificador está regenerado y ablanda.** La causa era la que dijo el usuario: llevaba sin
  sal. Los dos ciclos han bastado. Y como los equipos domésticos regeneran solos por volumen, **no
  hay que volver a bajar al parking**.
- **El grifo de jardín sale duro: control superado.** Ya se sabía que va aparte.
- **El grifo cercano a la piscina sale duro: la sospecha del usuario era correcta.** Ese punto de
  toma no cuelga del descalcificador. Con ΔE 0,4 contra el de jardín, es literalmente la misma agua
  de red — y eso apunta a que **está en el mismo ramal exterior**. Encaja con la práctica habitual de
  instalación: los grifos de fuera se cuelgan **a propósito** aguas arriba del equipo, para no gastar
  sal regando. El de la piscina se quedó ahí por estar fuera, no por un error de montaje.

### La consecuencia práctica: el punto de relleno cambia

**No se rellena por el grifo de la piscina.** Ese grifo mete agua de 300+ mg/L y es el que ha estado
alimentando el trinquete de dureza que se come la célula.

Dos vías, y la barata funciona hoy mismo:

1. **Manguera desde el grifo interior blando.** Coste cero, disponible ya.
2. **Repicar la tubería** para colgar el grifo de la piscina del descalcificador. Es la solución
   definitiva, pero el equipo está en un parking en obras: no corre prisa.

Y conviene recordar lo que el relleno blando **no** hace (Paso 4 del plan): **no baja la dureza, la
congela**. Lo que ahora sí cambia de naturaleza es el **contralavado**: con relleno blando, cada
lavado de filtro pasa a ser una **retirada real de calcio**, porque el agua que se va lleva sus
300 mg/L y la que entra a sustituirla no lleva ninguno. Lento, gratis, y por primera vez en la
dirección correcta.

## 19 de agosto, tarde: se apaga la segunda bomba, el reloj pasa a tres bloques y la consigna se queda

Tres decisiones del mismo día, y las tres se apoyan en datos que aportó el usuario sobre la marcha.

### Dato nuevo: las dos bombas comparten filtro Y bomba de pH

No estaba registrado. Cambia la lectura por completo:

```
Una bomba Hayward   12-14 m³/h   ← el caudal para el que está dimensionado el filtro
Dos bombas          24-28 m³/h   ← el doble por el MISMO lecho de arena
```

La arena atrapa la suciedad porque el agua pasa despacio. Al doblar el caudal el agua cruza el lecho
demasiado rápido, la suciedad lo atraviesa y con el tiempo puede abrir canales. **Dos bombas no
filtraban el doble: filtraban peor.**

La segunda entró el 17-08 para mezclar rápido durante la titulación. Ese trabajo está hecho.

- **Se apaga la segunda.** Queda como reserva y como herramienta de mezcla para dosificar.
- **Hacerla girar 10-15 min una vez al mes**, o se agarra.
- Ahorro colateral: del orden de **40-60 EUR/mes** de bomba que no aportaba nada.

Con una sola bomba: **4,6 renovaciones al día**. Una piscina doméstica pide 1-2. Sobra.

### El reloj: de ocho bloques a tres

El reparto anterior (2 h ON / 1 h OFF) daba 16 h/día y **ocho arranques**. El usuario propone bajar a
dos filtraciones. Se le recomiendan **tres**, y el motivo es el cianúrico.

**El CYA está a cero** — parche naranja en las tres tiras del 19-08. Sin estabilizante no hay filtro
solar en el agua y el sol destruye el cloro libre en un par de horas. Con dos bloques quedan dos
huecos de 4-5 h y uno cae con sol sí o sí. Con tres, **ningún hueco diurno pasa de 3 h**.

Reparto puesto, **15 h/día** (regla temperatura/2, agua a ~30 °C), 20 segmentos de 15 min por bloque:

```
06:00 → 11:00    deja el agua clorada antes de que apriete el sol
13:00 → 18:00    el pico de sol y de baño
21:00 → 02:00    noche; solo 1 h en punta tarifaria
```

Huecos: 2 h a mediodía, 3 h al atardecer con el sol cayendo, 4 h de madrugada donde no se consume
nada.

**Antes de tocar un pin, poner el disco en hora.** Va ~12 min adelantado (medido el 17-08): sin
corregirlo, todo arranca 12 minutos antes de lo programado.

**A vigilar el 23-08:** se pasa de 16 h a 15 h y el clorador **solo produce con la bomba en marcha**.
Es un 6 % menos de producción sobre un FC de 2,0 ppm que está en el centro exacto de la banda. Hay
margen, pero hay que confirmarlo.

### La consigna de pH se queda en 7,70 — con un argumento nuevo

El usuario pregunta si hay que bajarla. **Se queda**, pero el motivo que había escrito ya no vale y
hay que sustituirlo.

**Lo que caduca:** en «Hallazgos sueltos» está escrito *«con el TAC cerca del suelo, la consigna alta
protege»*. Eso se escribió creyendo que la alcalinidad estaba en 40. La titulación del 17-08 la puso
en **85-110, dentro de banda**. Bajar la consigna gasta alcalinidad, sí, pero hay colchón. **Ese
argumento ya no bloquea nada.**

**Lo que decide de verdad es el índice de Langelier**, y lo que dice es que no tenemos el dato:

```
LSI = pH + f(T) + f(Ca) + f(TAC) − constante

pH 7,70 · 30 °C · TAC 100 · dureza 300           →  LSI ≈ +0,18   ligeramente incrustante
                    ...si esos 300 fueran CALCIO →  LSI ≈ +0,07   equilibrio
```

**Los 300 salen de un parche de tira, y una tira mide dureza TOTAL, no calcio.** El calcio suele ser
el 70-80 % de esa cifra. Según cuál sea, el agua está en equilibrio o levemente incrustante.

Y aquí está el argumento: **mover la consigna 0,1 mueve el LSI 0,1. La incertidumbre del dato de
entrada es MAYOR que el efecto de la corrección.** Sería apuntar con un instrumento que no distingue
entre «hay que actuar» y «no hay nada que hacer».

Razones de apoyo, por orden de peso:

- **No hay problema de desinfección que arreglar.** A 7,70 solo el 39 % del cloro es HOCl activo, y a
  7,50 sería el 50 % — pero el **ORP está en 700 mV**, por encima del umbral de 650. El lazo funciona.
- **Una variable cada vez.** El mismo día se cambia el reparto de filtración y entran 1,31 m³ de agua
  nueva. Con el pH movido también, un desplazamiento el sábado no tendría autor identificable.
- **El ácido es del 38 %**, 3,1× más fuerte que el de los números originales. Más dosificación con ese
  producto es donde este proyecto ya estuvo cerca del desastre.

**Y el arreglo estructural ya está en marcha:** contralavado + relleno blando bajan la dureza, y bajar
la dureza baja el LSI **sin gastar una gota de ácido ni un miligramo de alcalinidad**. Se está
atacando el término correcto de la ecuación.

Si el 23-08 sale que hay que corregir: **7,70 → 7,60, un escalón, y se mide.** Nunca directo a 7,4.

> **PENDIENTE, y es el dato que desbloquea la decisión del pH: una DUREZA CÁLCICA de verdad**, con
> reactivo de calcio, no con tira. Es el mismo dato que dirá cuándo parar de contralavar (suelo:
> 200-400 mg/L; por debajo de 150 el agua se vuelve agresiva y ataca la lechada del gresite).

### Corrección de método: el cuello de botella del relleno es la manguera, no el equipo

Se estimó el llenado de 1,31 m³ en 30-50 min a partir del caudal del descalcificador (1,5-2,5 m³/h).
**Está mal planteado.** El que manda es el grifo con manguera, del orden de 10-15 L/min:

```
1.310 L ÷ 12 L/min  ≈  1 h 50 min
```

Y el criterio de parada tampoco son las filas: **es la boca del skimmer**, con el agua entre dos
tercios y tres cuartos de la abertura. Pasado ese punto el skimmer deja de barrer la superficie; por
debajo, traga aire. La boca es un instrumento; las filas son una estimación.

La tira del grifo se toma **con el grifo todavía abierto**, justo antes de cerrar: es el agua que ha
pasado por la resina después de tirarle 1,3 m³ seguidos. Si se cierra y se espera, la tubería se
queda quieta y habría que purgar otros 20 L para medir lo mismo.

## 19 de agosto, 20:03: la tira de control tras el relleno, y el ORP baja a 667

Cierre del día. Dos medidas: una que confirma el arreglo y otra que abre la vigilancia del sábado.

### La tira de control del grifo, y esta vez con protocolo limpio

Toma del usuario, y merece quedar escrita porque es la mejor del proyecto: **cerró el grifo, lo
reabrió, dejó correr 3 s, enjuagó el vaso tres veces, tomó la muestra, esperó 10 s, sumergió la tira
y fotografió a los 20-22 s cronometrados.**

Resultado, con el bote enfocado en la misma foto:

```
dureza (TH)      Lab  L 74,5   a* +9,1   b* -50,7      AZUL     ← agua dura da a* +44
alcalinidad (TA) Lab  L 60,2   a* +5,1   b* -58,9      azul profundo, sin cambio
FC / TC / CYA    a cero — es agua de red, es lo que tiene que salir
```

**El descalcificador aguantó los 1,31 m³ seguidos.** Era el riesgo vivo: una resina que llevaba
muchísimo tiempo saturada y a la que se le pide de golpe un tercio de su capacidad entre ciclos.

Y otra vez el control interno que vale más que la propia medida: **la alcalinidad no se movió.**
Dureza al suelo con alcalinidad intacta es la firma del intercambio iónico, no un artefacto de foto.

> **Cautela de método:** los ΔE **entre fotos distintas no valen** — cambia la luz, cambia el blanco
> de referencia y cambia el balance de la cámara. Lo que se compara entre tandas es el **signo y el
> orden de magnitud de a\***, no la distancia. Dentro de una misma foto sí vale la distancia.

### ORP 667: baja, y es coherente

Foto del display del clorador (Klinwass): **667 mV**. Venía de **700-709** el 18-08.

Dos causas que apuntan en la misma dirección y no hay que asustarse con ninguna:

- **Acaban de entrar 1,31 m³ de agua sin cloro** — una dilución del 3,3 % del cloro libre.
- La lectura se toma **al final de un bloque de filtración** (el de 18:47-20:40), que es donde el ORP
  está en su punto más bajo del ciclo.

**Sigue por encima de 650**, que es el umbral de desinfección correcta. **No se toca nada.** Pero es
**el número del sábado**: si el reparto nuevo de 15 h se queda corto, va a aparecer justo ahí.

El pH del display sale ilegible en la foto. El usuario lo reporta en **7,70**. Queda registrado como
**reportado, no medido**.

### Corrección del usuario: el orden de la faena del reloj

Se había escrito «poner el disco en hora y después los pines». **Está mal, y lo corrige el usuario:**

```
1. PARO del grupo
2. Configurar los pines
3. Puesta en hora  ← lo ÚLTIMO
```

El motivo es mecánico y sólido: **manipular los pines mueve el disco.** Si se pone en hora primero,
la hora se pierde mientras se recorren los 96 segmentos. La puesta en hora va al final, cuando ya no
se va a volver a tocar el disco.

Lo que sí se mantiene del consejo anterior: **hacerlo todo con el grupo parado**, para no darle un
corte seco al clorador en plena producción.

## 20 de agosto: el reloj sigue adelantado, el sondeo son 34 s, y el lazo va mejor

Día sin intervención. **No se tocó nada: ni consigna, ni bomba, ni pines, ni el disco del reloj.**
Solo se leyó. Y de leer salieron una corrección de método y una respuesta que llevaba tres días
pendiente.

### La hora exacta del arranque: 05:53:19

Se leyó del recorder, sin madrugar y sin cronometrar nada, con la receta de siempre
(`binary_sensor.piscina_chlorinator_alarma`, `unknown` = sin corriente):

```
19-08 20:27:40  unknown   fin de bloque
19-08 20:55:30  off       ARRANQUE del bloque de las 21:00   ->  4,5 min de ADELANTO
20-08 02:01:47  unknown   fin del bloque 21-02
20-08 05:53:19  off       ARRANQUE del bloque de las 06:00   ->  6,7 min de ADELANTO
```

**La corrección de 5 min del 19/08 por la noche no arregló nada: empeoró unos 2 minutos.** Se pasó
de 4,5 a 6,7 min de adelanto. El disco se movió en el sentido equivocado, y además con mano
imprecisa, porque no fueron los 5 min enteros en ninguna dirección.

La rejilla de lectura que se había dejado escrita (06:00 en hora / 05:55 / 05:50 / 06:05) **no
contemplaba este resultado intermedio**. Cuando una rejilla de interpretación solo tiene casillas
discretas y el dato cae entre dos, la rejilla es la que está mal.

### Corrección: el sondeo son 34 segundos, y los ±8 min de las paradas no vienen de ahí

Se venía suponiendo que las paradas tenían ±8 min de holgura **porque la transición se detecta en el
sondeo siguiente**. Eso es falso, y se comprueba mirando cuántas filas escribe cada sensor:

```
sensor.piscina_chlorinator_ph / orp / salinidad / temperatura
   05:53:19 · 05:53:53 · 05:54:27 · 05:55:03 · 05:55:37 · 05:56:12 ...
   ────────────────────────────────────────────────────────────────
   una muestra cada ~34 s
```

Con 34 s de cadencia, **la incertidumbre del ARRANQUE es de medio minuto, no de ocho**. Y entonces,
¿de dónde salen los ±8 min de las paradas? De otro sitio completamente:

| | arranque | parada |
|---|---|---|
| Qué pasa | el equipo reconecta y la nube sirve dato vivo | el equipo se queda sin corriente |
| Qué ve HA | valores nuevos inmediatamente | la nube **sigue sirviendo dato cacheado** un rato |
| Holgura | < 35 s | varios minutos, hasta que caduca la caché |

**Son dos mecanismos distintos, no el mismo mecanismo con dos magnitudes.** La regla operativa que
ya teníamos —usar siempre el arranque, nunca la parada— sobrevive intacta; lo que cambia es el
motivo, y el motivo importa porque dice cuánto vale cada número.

Contraste que lo valida: la parada de las 02:01:47, con el disco 6,7 min adelantado, implica corte
real hacia la 01:53 y unos 8 min de caché. Encaja.

### Decisión: el disco NO se vuelve a tocar

6,7 minutos sobre bloques de 5 horas es un **2,2 %**. No cambia las 15 h/día, no cambia el suelo del
ORP, no cambia nada medible. Y ajustar a mano un disco mecánico tiene **más error que el defecto que
corrige** — está demostrado en este mismo episodio, donde un intento de mover 5 min acabó moviendo
-2 en el sentido contrario.

> **Regla:** no se corrige un desvío cuya magnitud es menor que el error del procedimiento de
> corrección. Se documenta y se deja.

### ¿Mejor o peor que antes? Mejor. Y la prueba no es el ORP

Ventana comparable, 06:00-08:34 locales, los mismos minutos cada día:

| día | ORP medio | pH (rango) | sal | temp | muestras en alarma |
|---|---|---|---|---|---|
| 16-08 | 704 | 7,77 | 5,27 | 27,7 | **310** |
| 17-08 | 709 | 7,91 (±0,34) | 5,31 | 27,6 | **805** |
| 18-08 | 701 | 7,69 | 5,70 | 28,3 | 2 |
| 19-08 | 696 | 7,69 (±0,28) | 5,76 | 29,0 | **0** |
| 20-08 | 697 | 7,70 (±0,04) | 5,62 | 29,3 | **0** |

**Trampa que casi se cuela, y queda como regla:** el ORP de hoy sale 7 mV por debajo del 16-08, y
eso *no significa nada*. Los días 16-18 iban con el reloj de ocho bloques, así que esa ventana
**incluye tramos con el grupo parado**, y con el grupo parado la nube sirve dato congelado. Se ve
en el recuento de filas: **19-41 muestras esos días contra 271 hoy**. Hoy es el primer día con la
ventana entera en marcha. Comparar 697 contra 704 es comparar una media buena contra una media
hecha de valores cacheados.

> **Regla:** antes de comparar dos medias, comparar el **número de muestras** que las sostienen. Una
> media sobre 20 filas congeladas y otra sobre 271 filas vivas no son la misma clase de objeto.

Lo que sí es limpio, y decide:

- **Alarmas.** 805 muestras en alarma el 17-08, 310 el 16, **dos** el 18, **cero** el 19 y el 20.
  La curva no admite discusión.
- **Planitud del pH.** Hoy es el día **más plano de toda la serie**: 0,04 de recorrido, frente a
  0,34 del 17-08. Quitar la segunda bomba fue el acierto — la peristáltica ya no pelea contra
  24-28 m³/h por un lecho dimensionado para 12-14.
- **La cuenta que cierra el argumento.** Hoy sostiene 697 mV con **una hora menos de filtración**
  (15 vs 16), **una bomba en vez de dos** y **1,6 °C más de agua** (29,3 vs 27,7), y más calor es
  más consumo de cloro. Mismo resultado, con menos medios y en peores condiciones. Eso no es
  empatar.

Y el 667 mV del 19/08 queda explicado del todo: era final de bloque justo después de meter 1,31 m³
sin cloro. Hoy, a la misma altura del ciclo, 697. No había degradación del lazo.

### Predicción validada: la dilución de la sal

El 19/08 se calculó que el relleno de 1,31 m³ bajaría la salinidad unos **-0,15 g/L**.

```
19-08   5,76 g/L
20-08   5,62 g/L
        ───────
        -0,14 g/L    ← predicho -0,15
```

Primera predicción cuantitativa del proyecto que acierta a la primera. Y confirma de paso que el
sensor, con **media de ventana larga** (271 muestras), sí es utilizable pese al offset de +1,3 g/L y
a la oscilación de ±0,5: **el offset es constante, así que las DIFERENCIAS son buenas aunque el
valor absoluto no lo sea.**

### Lectura de cierre, 11:00: el bloque de mañana entero, y el hueco que viene

Bloque 06:00-11:00 completo, **528 muestras** — el primer bloque de este proyecto medido entero y
con dato vivo de principio a fin.

```
                media bloque   última hora   último (10:59)   rango
ORP                 692,2         680,7           677          677-701
pH                  7,70          7,70            7,70         7,68-7,72
salinidad           5,63          5,73            5,71         5,45-6,00
temperatura        29,2          29,1            29,1         29,1-29,4
alarmas            0 de 527 muestras
```

**El perfil dentro del bloque es un diente de sierra, y hay que leerlo como tal:** 697 de media en
las primeras 2,5 h, 681 en la última hora, 677 en la muestra final. El ORP sube al principio del
bloque y decae hacia el final. **Un valor suelto no dice nada si no se dice a qué altura del ciclo
se tomó.**

Y ahora la comparación que importa, a la MISMA altura del ciclo:

```
19-08  final de bloque   667 mV
20-08  final de bloque   677 mV     ← +10
```

**Diez milivoltios mejor que ayer en el punto más desfavorable del día.** El pH, además, no se movió
de 7,70 en 528 muestras seguidas.

### Predicción para el hueco de 11:00 a 13:00 — se comprueba mañana sin hacer nada

Hoy es **la primera vez** que se produce el hueco 11-13 del reparto nuevo. Y el 15/08 quedó medido
lo que cuestan dos horas sin filtrar: **36 mV** (680 → 644, con sol y a 30 °C).

Aplicado al arranque de hoy:

```
677 (final de bloque)  -  ~30 mV  =  645-660 al arrancar a las 13:00
```

Rebaja deliberada sobre los 36 mV medidos: aquel hueco era de tarde, con más UV acumulado; este es
de mediodía a primera hora de la tarde. Pero **la horquilla roza el suelo de 650**, y ahí está el
punto débil del reparto de tres bloques.

- **Si sale por encima de 660** → el hueco no es problema, no se toca nada.
- **Si sale por debajo de 650** → la palanca NO es el pH: es devolver horas de filtración o subir
  el % de cloración. Las horas ponen el suelo del ORP.

Se lee mañana del recorder, en la muestra del arranque de las 13:00 de hoy. No hay que estar
delante.

### La caché de la nube, pillada en directo

Detalle que confirma el hallazgo de esta mañana por segunda vez y de forma independiente: con el
disco 6,7 min adelantado, el bloque de las 11:00 **se cortó de verdad hacia las 10:53**. Y a las
**10:59:36 seguían entrando muestras** con valores nuevos.

Seis minutos de datos después del corte. Eso no lo puede producir un sondeo de 34 s: es la nube
sirviendo su último estado conocido. **Comprobación pendiente para mañana:** a qué hora exacta cayó
el `unknown` de este corte. Si la explicación es correcta, tiene que estar varios minutos después de
las 10:53, nunca antes.

### Pendiente

- **21/08, 19:00** — dureza cálcica con reactivo EDTA (kit comprado el 20/08 en Amazon). Dos
  muestras: piscina (dato del LSI) y grifo interior blando purgando 20 L, que es la prueba de fuego
  del descalcificador con un número en vez de un color. Aviso en Calendar con el protocolo.
- **21/08** — leer del recorder las dos comprobaciones que deja hoy: el **ORP del arranque de las
  13:00** (predicho 645-660) y la **hora del `unknown`** del corte de las ~10:53 (tiene que caer
  varios minutos después).
- **21/08** — redactar el issue para `foXaCe/Fluidra-pool` con los tres hallazgos que sirven a
  terceros: el tecnoLC2 no tiene cloro libre (11 componentes, dos sondas), la caché de la nube
  retrasa la detección del corte de corriente, y el truco de medir las horas reales de filtración
  con las transiciones del `binary_sensor` de alarma. Nada de eso necesita datos de la casa.
- **23/08, 09:00** — revisión completa del agua. El ORP sigue siendo el número.

## 21 de agosto: la dureza cálcica, por fin con un reactivo — 850 mg/L, y la tira queda enterrada

Era el dato **pendiente desde el 17/08**, el que bloqueaba la decisión de la consigna de pH y el
criterio de parada del contralavado. Kit EDTA comprado el 20/08. Muestra: **agua de la piscina**.

```
viraje ROSÁCEO (hay cal) -> AZUL
1 gota = 1 °fH
85 gotas  =  85 °fH  =  850 mg/L CaCO3
```

### El LSI, recalculado

Con las condiciones reales de la instalación — pH 7,70 (consigna, sin moverse en 528 muestras),
29 °C, TAC 85-110 por titulación del 17/08, sal 5,6 g/L:

```
LSI = pH + TF + CF + AF - K

TF(29 °C = 84 °F) = 0,70
CF = log10(Ca como CaCO3) - 0,4
AF = log10(TAC)
K  = 12,32   <- constante de sólidos disueltos para agua salada ~5,6 g/L.
                Se fija por retroajuste al LSI +0,18 que este mismo proyecto
                calculó el 19/08 con dureza 300 y 30 °C. Misma constante,
                mismos números: las comparaciones de abajo son homogéneas.
```

| Escenario | Ca (mg/L) | CF | LSI (TAC 100) | LSI (rango TAC 85-110) |
|---|---|---|---|---|
| 850 es **calcio** | 850 | 2,529 | **+0,61** | +0,54 a +0,65 |
| 850 es **total**, Ca = 76 % | 650 | 2,413 | **+0,49** | +0,42 a +0,53 |
| la vieja tira | 300 | 2,077 | +0,16 | +0,09 a +0,20 |

**Los dos escenarios reales dicen lo mismo: agua claramente incrustante.** La ambigüedad
calcio/total no cambia ninguna decisión, así que no bloquea nada.

### Ambigüedad que queda abierta (y que no importa para decidir)

El viraje rosa → azul **no desambigua por sí solo**:

- En kits de piscina tipo Taylor (R-0010 tampón + R-0011L indicador + R-0012 titulante) el
  rojo → azul **ES** la titulación de **calcio**: el tampón lleva la muestra a pH 12-13 y el
  magnesio precipita como hidróxido.
- Con negro de eriocromo T a pH 10, el rojo vino → azul es dureza **TOTAL**.

Para cerrarlo hay que mirar si el kit dice «calcio» y si lleva **dos reactivos previos** al
titulante. Se anota como pendiente menor.

### Correcciones y consecuencias

**1. La tira queda enterrada.** Los 300 del parche eran falsos. El 800 al que derivaba el parche
—que el 20/08 se descartó como artefacto— estaba **más cerca de la verdad que el 300**. Confirma
la regla: *una tira solo vale si algo que no es una tira la confirma*.

**2. El pH deja de ser la palanca.** Es aritmética directa: el pH entra en el LSI sumando, así que
**bajar 0,10 de pH baja exactamente 0,10 de LSI**. Para llevar +0,61 a cero harían falta **pH 7,10**,
inaceptable, y con el ácido del 38 % es justo donde este proyecto estuvo cerca del desastre.
El escalón 7,70 → 7,60 pactado sigue siendo correcto, pero es un **parche, no la solución**.

**3. La palanca real es SACAR CALCIO, y la aritmética duele.** Dilución con relleno blando
(~0 de dureza), vaso de 40 m³, `C_final = C_inicial × (1 - f)`:

```
850 -> 400 mg/L   f = 0,53   ->  21,2 m3   (53 % del vaso)
850 -> 300 mg/L   f = 0,65   ->  25,9 m3   (65 %)
650 -> 400 mg/L   f = 0,38   ->  15,4 m3   (38 %)
```

**El goteo de contralavados NO llega.** Con ~0,5 m³ por contralavado harían falta **~42
contralavados** para los 21,2 m³. A uno por semana, eso no es esta temporada: son ocho meses.
La frase del 18/08 —«cada contralavado pasa a ser una retirada real de calcio»— es cierta y sigue
en pie, pero su **magnitud es despreciable** frente al problema medido.

**4. Consecuencia que nadie había contado: la SAL se va con el agua.** El vaso lleva
`40 m³ × 5,6 g/L = 224 kg` de sal. Reponer el 53 % del agua **se lleva ~119 kg**, unos **5 sacos
de 25 kg** a reponer. Y el llenado, con el cuello de botella real de la manguera (12 L/min),
son `21.200 L ÷ 12 ≈ 29 horas` de grifo. Esto no se improvisa una tarde de agosto.

**5. Lo que el relleno blando SÍ conserva: la alcalinidad.** El intercambio iónico quita calcio y
deja los bicarbonatos intactos. Es exactamente lo que interesa: se desploma el CF sin tocar el AF.

### Decisión

- **Ahora, 21/08:** el escalón pactado, **7,70 → 7,60**, uno solo, y se mide el 23/08. Nunca directo
  a 7,4.
- **Palanca secundaria disponible:** el TAC entra como `log10`. Llevarlo de 100 a 80 vale **-0,10**
  de LSI, tanto como el escalón de pH. Es seguro **aquí en concreto** porque hay control activo de
  pH: la bomba mantiene 7,70 sin moverse en 528 muestras, así que la pérdida de tampón no se traduce
  en oscilación. Combinado con el escalón: **+0,61 → +0,41** (o +0,49 → +0,29).
- **Estructural, al CIERRE DE TEMPORADA, no en agosto:** vaciado parcial del ~50 % con relleno
  blando, contando los 5 sacos de sal y las ~29 h de manguera. Es el momento en que el vaciado ya
  toca de todas formas.
- **Suelo que no se cruza:** 200-400 mg/L. Por debajo de 150 el agua ataca la lechada del gresite.
  Desde 850 hay recorrido de sobra.

### Aviso de método: no se diluyó

El protocolo mandaba **diluir 50/50 con destilada por encima de 40 gotas** y no se hizo. En EDTA a
dureza alta el viraje se vuelve lento y se tiende a **sobre-titular** persiguiendo un color que se
apaga. Por tanto **850 es cota superior**: el valor real puede ser algo menor. No baja a 300.

### Pendiente que deja este día

- **Segunda muestra: grifo interior blando, purgando 20 L.** Es la prueba de fuego del
  descalcificador **con un número** en vez de con un color, y lo único que puede confirmar o tumbar
  el hallazgo colorimétrico del 19/08. Sin ella, los 21 m³ de relleno blando son un plan sobre una
  suposición.
- Sigue pendiente del 20/08: el **ORP del arranque de las 13:00** (predicho 645-660) y la **hora del
  `unknown`** del corte de las ~10:53, ambos del recorder.
- Sigue pendiente: el **issue para `foXaCe/Fluidra-pool`** con los tres hallazgos reutilizables.

## Lección de método de la semana

Lo que ha decidido cada resultado de estos siete días **no ha sido la química**. Ha sido el **punto
de toma**, el **instrumento** y el **tiempo transcurrido**. Tres retractaciones, todas por no haber
registrado esas tres cosas.

Reglas que quedan escritas:

- **Descartar siempre la primera lectura de cualquier instrumento** de esta instalación.
- **Una tira solo vale si algo que no es una tira la confirma.**
- **En una titulación se lee la meseta de mezcla, nunca el mínimo.**
- **Una titulación que pasa de 40 gotas sin diluir es una COTA SUPERIOR, no una medida.** El viraje
  del EDTA se apaga a dureza alta y se sobre-titula persiguiendo un color que ya no vuelve.
- **Una tira se fotografía pegada al bote y a la sombra.** Con luz cálida el balance de blancos
  convierte el verde-azulado en oliva, y ahí está justo la diferencia entre 180 y 40.
- **Antes de dosificar, leer la etiqueta del envase que hay hoy**, no la del que había cuando se
  escribió el plan.
