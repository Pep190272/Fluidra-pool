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
