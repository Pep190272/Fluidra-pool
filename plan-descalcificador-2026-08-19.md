# Plan del 19 de agosto: regenerar el descalcificador y mapear la fontanería

> Documento de campo. Se sigue de arriba abajo. Contexto completo en
> `NOTES-piscina-clorador.md`, sección «18 de agosto, tarde: tres tiras».

## Por qué se hace esto

El 18-08 se midió, con colorimetría sobre foto, que **el agua del grifo «descalcificado» y la del
grifo sin descalcificar son la misma agua**: ΔE 10 en el parche de dureza, cuando un descalcificador
que funciona daría **ΔE 103**. El usuario confirmó la causa: **el aparato llevaba sin sal.**

Esa cal es la que se come la célula del clorador. La dureza de la piscina (ΔE 5,2 contra la del
grifo) es exactamente la del agua con la que se rellena.

Sal echada y un primer reciclo lanzado el 18-08 por la tarde.

---

## Paso 0 — Antes de tocar nada: el primer reciclo NO cuenta

**La salmuera necesita de 4 a 6 horas para saturarse**, mejor toda la noche. El ciclo que se lanzó
justo después de echar la sal **aspiró agua, no salmuera**. La resina se regeneró poco o nada.

No sirve de nada medir sin repetir el ciclo. Y una resina que lleva mucho tiempo saturada puede
necesitar **dos o tres regeneraciones** para volver del todo.

- [ ] Lanzar una **segunda regeneración** completa.
- [ ] Esperar a que termine (un ciclo típico son **90-120 minutos**).

---

## Paso 1 — Purga: 20 litros, medidos en cubo

La tirada conocida es de **25 m de PPR 22**. El PPR se designa por diámetro exterior, así que el
interior ronda los 15-16 mm:

```
25 m × ~15,5 mm interior   ≈  4,7 L  = un volumen de tubería
3 volúmenes                ≈  15 L   ← uno no basta, el agua se mezcla, no empuja en bloque
redondeo de trabajo           20 L
```

**Cuenta litros, no segundos.** Un cubo de 5 L, cuatro llenados. El caudal de un grifo varía
demasiado como para fiarse del reloj.

- [ ] 20 L por cada grifo **antes** de tomar su muestra.

---

## Paso 2 — Mapa de la fontanería: qué grifo cuelga de qué

Situación declarada por el usuario el 18-08:

| Punto | Estado declarado | Hay que confirmar |
|---|---|---|
| Jardín | **Va aparte** del descalcificador | Sí |
| Grifo cerca de la piscina | **Sospecha de que lo dejó pasar** por el descalcificador | **Es el que decide todo** |
| Grifo interior lejano | Descalcificado | Sí, sirve de control positivo |

Es lo normal: los grifos de exterior se cuelgan **antes** del equipo a propósito, para no gastar sal
en regar. Si el punto de relleno de la piscina está aguas arriba, se puede dejar el descalcificador
perfecto y **a la piscina no le llega nada**.

### Cómo se mide

Una tira por grifo, y **todas las tiras de la misma tanda en una sola foto**, con el bote al lado.
Esa es la condición que hace comparables las lecturas: misma luz, misma carta, mismo instante.

- [ ] Grifo interior lejano (control: **debe salir blando**)
- [ ] Grifo cercano a la piscina (**la incógnita**)
- [ ] Grifo de jardín (control: **debe salir duro**)

Reglas de la tira, ya pagadas a base de errores en este proyecto:

- Mojar 1 s, **no sacudir**, sostener **horizontal en el aire**, leer **a los 20 segundos** con
  cronómetro. Ni antes ni después: el 18-08 se demostró que al minuto se mueven cuatro parches, dos
  de ellos de magnitudes que no pueden cambiar (dureza y cianúrico).
- Foto **a la sombra**, con el bote pegado y **enfocado**. La foto de piscina del 18-08 salió con la
  carta desenfocada y hubo que emparejarla contra la carta de otra foto.
- Luz **difusa, no sol bajo**. La tanda de tarde del 18-08 dio ΔE de 10-35; la de mañana, de 2-16.

---

## Paso 3 — Qué significa cada resultado

**La señal del éxito es enorme y se ve a simple vista**: el parche de dureza pasa de **magenta a
azul**. Son ~100 ΔE. No hace falta medir nada para saber si ha funcionado.

| Interior lejano | Cercano a la piscina | Lectura | Qué se hace |
|---|---|---|---|
| Blando | **Blando** | **Premio.** El descalcificador va y el punto de relleno cuelga de él | Rellenar siempre por ahí |
| Blando | Duro | El equipo va, pero el grifo de la piscina está aguas arriba | Decidir: repicar la tubería, o tirar manguera desde un grifo blando |
| **Duro** | Duro | El equipo **sigue sin regenerar** tras dos ciclos | Ir al equipo: resina agotada de verdad, válvula atascada o **bypass abierto** |

---

## Paso 4 — Antes de rellenar la piscina con agua blanda, leer esto

### Congela la dureza, no la baja

```
Se evapora agua pura      → el calcio se queda            → SUBE
Relleno con agua dura     → entra más calcio              → SUBE otra vez   (trinquete)
Relleno con agua blanda   → repone volumen, la masa de calcio no cambia
                          → vuelve al punto de partida y ahí se queda
```

Para que la dureza **baje** hay que **sacar agua**: lavar el filtro o vaciar. Con el equipo
funcionando, **cada contralavado pasa a ser una retirada real de calcio** — el agua que se va lleva
sus ~300 mg/L y la que entra a sustituirla no lleva ninguno. Lento y gratis.

### Tiene suelo: no perseguir el cero

Una piscina quiere **200-400 mg/L de dureza**. Por debajo de ~150 el agua se vuelve **agresiva** y
ataca la lechada del gresite. Es el mismo precipicio por el otro lado.

### ¿Aguanta el descalcificador el gasto? Sí, y sale barato

Números de orden de magnitud para un equipo doméstico de 20-25 L de resina (**comprobar la placa
del aparato**, estos números no son de su modelo):

```
Dureza del agua de red         ~300 mg/L CaCO3  =  30 °f
Capacidad entre regeneraciones ~125 °f·m3       →  ~4 m3 de agua blanda por ciclo
Un cuadro de gresite            0,66 m3         →  el 16 % de un ciclo
Relleno de toda la temporada    16-25 m3        →  4-6 regeneraciones extra
Sal extra por temporada         ~10 kg          →  del orden de 5-10 EUR
```

También gasta agua de enjuague, unos 150-250 L por ciclo, ~1 m³ en la temporada. Y el caudal de un
equipo doméstico (1,5-2,5 m³/h) llena un cuadro de gresite en 20-30 minutos.

**Conclusión: es asequible.** No hay motivo económico para no hacerlo.

---

## Lo que NO se hace, y conviene tenerlo escrito

- **No se echa bicarbonato.** La alcalinidad de la piscina está en 85-120 según dos métodos
  independientes (titulación del 17-08 y tira del 18-08 por la tarde, ΔE 8). Está en banda.
- **No se rellena para subir la alcalinidad.** Con la piscina en 120 y el grifo en 180, un cuadro de
  gresite da **1 mg/L**. La vía está cerrada por aritmética.
- **No se toca el lazo de control del clorador.** Cloro libre 2 ppm, ORP 700, consigna de pH 7,70,
  cloración 60 %. Las tres medidas cuadran entre sí. Se deja como está.
