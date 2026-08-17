# Plan para bajar la alcalinidad — Piscina 40 m³

**Fecha:** 11 de agosto de 2026
**Equipo:** Clorador salino Fluidra (tecnoLC2)
**Volumen:** 40 m³

---

> # 🛑 PLAN CANCELADO — OBJETIVO YA CUMPLIDO — NO EJECUTAR NUNCA
>
> **2026-08-17.** Este plan no está suspendido: está **cancelado**. La alcalinidad se midió por
> titulación limpia y **ya estaba dentro del objetivo**. No hay nada que bajar.
>
> **TAC real medido = 85–110 mg/L.** Objetivo del plan: 120. Superado por abajo.
>
> El **TAC de 240 sobre el que está calculado todo este documento es falso** y queda descartado:
> era una medición del 11-08 cuyo instrumento nunca se registró, y contradice el balance de ácido
> (para pasar de 240 a 100 harían falta ~14 kg de bisulfato o ~35 L de producto que nadie vertió).
>
> ## ⚠️ POR QUÉ EJECUTARLO SERÍA UNA CATÁSTROFE, Y NO UNA EXAGERACIÓN
>
> Concurren **dos errores que se multiplican**:
>
> 1. **El TAC de partida es menos de la mitad** del supuesto (≈100 frente a 240).
> 2. **El producto que hay ahora en casa es 3,1 veces más concentrado.** Este plan está calculado
>    sobre AstralPool pH Minus al **14,4 %**. Desde el 17-08 el equipo aspira de una garrafa de
>    **Reductor pH- líquido MG, ácido sulfúrico al 38 %**.
>
> | Producto | Concentración | Puntos de TAC por litro |
> |---|---|---|
> | AstralPool pH Minus (el del cálculo) | 14,4 % | **4,0** |
> | Reductor pH- líquido MG (el que hay hoy) | 38 % | **12,5** |
>
> Verter los **30 L** de la sección 2 con el producto actual daría **375 puntos** de reducción sobre
> un agua que tiene ~100. Resultado: **alcalinidad cero, pH desplomado**, y destrucción de juntas,
> gresite, silicona y del recubrimiento de los electrodos de la célula.
>
> ## SI ALGÚN DÍA HAY QUE VOLVER A BAJAR EL TAC
>
> No usar este documento. Recalcular desde cero con estas dos reglas:
>
> - **Escala del producto nuevo (38 %): 1 L = 12,5 puntos de TAC en 40 m³.**
> - **Nunca bajar de 80 mg/L.** Por debajo el agua se vuelve agresiva.
>
> Y medir antes, con el método de la sección «Cómo medir el TAC sin reactivos» al final de
> `NOTES-piscina-clorador.md` (Episodio 6): pesar el producto, dosificar con las dos bombas en
> marcha y leer la **meseta de mezcla a los 15 minutos**, nunca el mínimo.

---

## 1. Situación de partida

> 🛑 **CIFRAS INVALIDADAS.** Se conservan solo como registro histórico. Ver el banner de cabecera.

| Parámetro | Medido | Objetivo |
|---|---|---|
| Alcalinidad (TAC) | ~~**240 mg/L**~~ → **FALSO. Real: 85–110** | 120 mg/L (rango sano: 80–120) |
| pH | **8,28** | 7,2 – 7,6 |
| Redox (ClmV) | 589 mV | 650 – 750 mV |
| Alarma en panel | ⚠ pH + `high` | apagada |

**Diagnóstico:** la alcalinidad altísima actúa como freno químico. La bomba de pH- dosifica
sin llegar nunca a la consigna, y el equipo la bloquea por protección (alarma ⚠pH `high`).
El LED `pumpstop` está apagado, así que **no** es el paro por bidón vacío de junio de 2026.

El cloro/redox bajo **no es un problema aparte**: a pH 8,28 el cloro pierde la mayor parte de su
poder desinfectante. Cuando baje el pH, el redox sube solo.

**Orden de trabajo innegociable:** primero TAC → después pH → después resetear el equipo.
Si se intenta corregir el pH sin bajar antes el TAC, en tres días se vuelve al punto de partida.

---

## 2. Producto y dosis

> 🛑 **DOSIS INVALIDADAS — NO EJECUTAR.** Calculadas sobre un TAC falso de 240 **y** sobre un
> producto que ya no es el que hay en la instalación. Ver el banner de cabecera.

**AstralPool pH MINUS** — líquido, garrafa de 20 L, ref. 73674
Composición: **ácido sulfúrico 14,4 %** (CAS 7664-93-9)

> ⚠️ **Este NO es el producto conectado desde el 17-08.** Ahora hay **Reductor pH- líquido MG,
> ácido sulfúrico al 38 %**, que rinde **12,5 puntos de TAC por litro** en vez de 4,0.
> **Toda cifra en litros de esta sección hay que dividirla por 3,1 antes de siquiera pensarla.**

> ~~Regla de oro para esta piscina: 2,5 L de producto = 10 puntos de TAC menos.~~
> **Regla vigente (producto al 38 %): 0,8 L = 10 puntos de TAC menos.**

| Concepto | Cantidad ~~del plan~~ | Equivalente con el producto de hoy |
|---|---|---|
| Bajada total ~~(240 → 120)~~ | ~~120 puntos~~ **ninguna: ya está en objetivo** | — |
| Producto total | ~~**~30 L**~~ | ~~9,7 L~~ **0 L** |
| A comprar | ~~2 garrafas de 20 L~~ | **nada** |
| Ritmo diario | ~~**5 L/día**~~ | ~~1,6 L/día~~ **no aplica** |
| Cada toma | **1,7 L** × 3 tomas al día |

> **Objetivo 120, no 100.** El agua de relleno viene con 240 de alcalinidad, así que apuntar a 100
> es gastar producto de más para un margen que se pierde con el primer rellenado. 120 está dentro
> del rango sano y ahorra un día entero de tratamiento.

La media garrafa que ya hay (~10 L) alimenta la bomba del clorador: **no se cuenta** para el
tratamiento. Quedarse sin producto a mitad de camino es exactamente lo que provocó la alarma
de junio.

**Alternativa de reserva:** quedan ~2 kg de Piscimar Baja TA (bisulfato sódico 100 %).
Equivalencia: **1 kg = 10 puntos de TAC**. Se guardan para el ajuste fino del último día.

---

## 3. Material necesario

- [ ] 2 garrafas de 20 L de pH Minus
- [ ] Regadera o cubo graduado de 10–12 L (uso exclusivo para esto)
- [ ] Guantes de goma y gafas de protección
- [ ] Test-kit de pH y alcalinidad (con reactivo en fecha)
- [ ] Manguera cerca, por si hay salpicadura

---

## 4. Rutina diaria

Se repite igual cada día del calendario.

### Por la mañana, antes de nada

1. Medir **pH** y **TAC**. Muestra del centro de la piscina, a un palmo de profundidad
   (nunca del borde ni delante del retorno).
2. Anotar en la tabla de registro del punto 6.
3. **Comprobar el corte de seguridad:** si el pH está **por debajo de 7,0**, ese día **no se echa
   nada**. Solo aireación. Se retoma al día siguiente.

### Las tres tomas (mañana / tarde / noche, cada 6–8 horas)

Para cada toma:

1. Verificar que la **depuradora está en marcha**.
2. Llenar la regadera con **~10 L de agua**.
3. Añadir **1,7 L de pH Minus** sobre el agua.
   **Siempre el ácido sobre el agua, nunca el agua sobre el ácido.**
4. Verter paseando por el borde de la **parte honda**, sin detenerse en un punto.
5. **Lejos de la boquilla de retorno del clorador.** Los dos productos nunca en el mismo sitio.
6. Dejar la filtración funcionando **mínimo 1 hora** después.

### Entre tomas: airear

Retorno apuntando a la superficie, chorros si los hay, cepillado enérgico de paredes.

La aireación sube el pH **sin devolver el TAC**. Es la mitad del trabajo y no cuesta dinero:
el ácido baja pH *y* TAC a la vez; la aireación recupera solo el pH. Esa asimetría es lo que
permite bajar la alcalinidad sin hundir el pH.

---

## 5. Calendario

Valores de TAC esperados. Son orientativos: manda siempre la medición real.

| Día | Producto | TAC esperado al terminar | Notas |
|---|---|---|---|
| 1 | 5 L (3 × 1,7 L) | ~220 | Primer día. Vigilar pH de cerca. |
| 2 | 5 L (3 × 1,7 L) | ~200 | |
| 3 | 5 L (3 × 1,7 L) | ~180 | |
| 4 | 5 L (3 × 1,7 L) | ~160 | Revisar reserva de producto. |
| 5 | 5 L (3 × 1,7 L) | ~140 | |
| 6 | Ajuste fino | ~120 | **Objetivo alcanzado.** Calcular según medición real. |

**Día 6 — ajuste fino:** medir y echar solo lo que falte.
Ejemplo: si marca 135 y se quiere 120 → faltan 15 puntos → 3,75 L de pH Minus,
o bien 1,5 kg del Baja TA en polvo.

**Si el TAC no baja como se espera**, no doblar la dosis. Revisar primero que el reactivo del
test-kit esté en fecha y que la muestra se tome bien. Continuar al mismo ritmo un día más.

### Variante para días laborables (2 tomas en vez de 3)

Si no hay forma de hacer tres tomas entre semana, se hace con dos: una antes de salir por la
mañana y otra al volver por la tarde. El tratamiento no se estropea, solo va algo más lento.

| Tipo de día | Tomas | Cantidad por toma | Total del día | Puntos de TAC |
|---|---|---|---|---|
| Laborable | 2 (mañana y tarde-noche) | 2 L | 4 L | ~16 |
| Fin de semana | 3 (cada 6–8 h) | 1,7 L | 5 L | ~20 |

Con 5 días laborables + 2 de fin de semana se cubren los 120 puntos en una semana justa.

Al pasar a 2 L por toma, **diluir en 15 L de agua** en lugar de 10 y repartir con más calma:
misma cantidad diaria, menos concentración por punto de vertido.

### Lo que NO se puede hacer: acumular dosis

Echar el producto de varios días de una vez —o la garrafa entera— **no acelera nada y hace daño**:

- El ácido no se dispersa, se va al fondo y forma una bolsa a pH 1–2 apoyada sobre el
  revestimiento durante horas. Ataca liner, gresite y juntas de forma permanente.
- Ese frente ácido pasa por la célula del clorador y le come el recubrimiento de los electrodos.
- Ácido concentrado + hipoclorito de la célula = **cloro gas**.
- Referencia de escala: según la etiqueta, **1,28 L bajan el pH 0,2** en esta piscina.
  Una garrafa de 20 L equivale a **15 dosis completas simultáneas**.
- Y ni siquiera resuelve: 20 L bajan unos 80 puntos, de 240 a 160. Sigue fuera de rango.

**El TAC no depende del calendario.** Ir más lento no cuesta nada; ir más rápido cuesta el vaso
y la célula.

---

## 6. Registro de mediciones

| Día | Fecha | pH mañana | TAC mañana | Producto echado | Observaciones |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |

---

## 7. Seguridad

- Guantes y gafas **siempre**. Que no haga vapores como el salfumán no significa que no queme:
  la etiqueta indica «Provoca quemaduras graves en la piel y lesiones oculares graves».
- **Ácido sobre agua. Nunca al revés.**
- **Nunca** mezclar con cloro, hipoclorito ni ningún otro producto. Ni en la regadera, ni en el
  mismo punto de la piscina, ni con pocos minutos de diferencia.
- Sin bañistas en el agua durante la dosificación ni en la hora siguiente.
- Garrafa bien cerrada, en lugar fresco, seco y fuera del alcance de los niños.
- Envase vacío: punto limpio, nunca a la basura común.

---

## 8. Al terminar el tratamiento

Cuando el TAC esté entre 80 y 120 y el pH se mantenga estable:

1. **Resetear la alarma del equipo:** cortar la corriente del clorador, esperar un minuto y
   volver a darla. La alarma ⚠pH `high` debe apagarse.
2. **Verificar la consigna de pH:** pulsar `SET` y comprobar el valor.
   En piscina salina conviene **7,2 – 7,4**, no 7,6: la electrólisis sube el pH de forma
   continua, así que partir de un valor más bajo da margen antes de salirse de rango.
   Se ajusta con `+` y se confirma con `SET`.
3. **Comprobar que la bomba dosifica de verdad:** mirar el tubo de aspiración. Si se ve producto
   avanzar, está cebada. Si solo se ve aire, hay que cebarla.
4. **No tocar `CAL`.** Las sondas están calibradas. Una calibración mal hecha deja el equipo
   leyendo valores falsos y el problema pasa a ser invisible.
5. A los 3–4 días, volver a medir pH y TAC para confirmar que se mantiene.

---

## 9. El agua de relleno — por qué esto se repetirá

**Dato medido: el agua de aporte también viene con TAC 240.**

Eso significa que la piscina no se ha desviado: está copiando el agua con la que se llena.
Consecuencias directas:

- **Vaciar y rellenar no sirve de nada.** El agua nueva entra con la misma alcalinidad que la que
  se tira. Diluir queda descartado como estrategia.
- **Cada rellenado vuelve a subir el TAC.** No es un fallo del tratamiento: es aritmética.
- Con la reposición normal de verano por evaporación, el TAC sube del orden de **20–30 puntos al
  mes**. Desde 120, se vuelve a zona problemática en unos 4 meses.

### La descalcificadora no interviene aquí

Por dos motivos independientes:

1. **No baja la alcalinidad.** Funciona por intercambio iónico: cambia calcio y magnesio por sodio.
   Elimina la **dureza** (la cal que incrusta), pero los **bicarbonatos** —que son exactamente lo
   que mide el TAC— salen intactos. El agua entra con 240 y sale con 240.
2. **No toca el agua de la piscina.** Trata el agua de la casa, y la piscina se llena por la línea
   del huerto, que no pasa por ella.

Conviene ponerla en marcha igualmente **por la casa y por la instalación**: protege de
incrustaciones. Pero no resuelve nada de este documento.

> **Pendiente:** el TAC medido es el del grifo de la casa. La piscina se llena por la **línea del
> huerto**. Si esa línea tiene otro origen (pozo, acometida de riego), el valor puede ser distinto.
> Merece una medición propia antes de dar el dato por cerrado.

### Mantenimiento: la regla que evita repetir el tratamiento entero

En vez de dejar que el TAC trepe otra vez hasta 240, se compensa cada rellenado en el momento:

> **~1 L de pH Minus por cada m³ de agua que se reponga.**

Se echa con el mismo método del punto 4 (diluido en regadera, filtración en marcha, repartido).
Con eso el TAC se queda estable y no hace falta volver a hacer una semana de tratamiento.

### La palanca que más ahorra: tapar la piscina

Menos evaporación = menos relleno = menos alcalinidad importada, menos producto y menos sal
que reponer. Una cubierta o manta térmica corta la evaporación de forma drástica y es lo único
que ataca la causa en vez del síntoma.

---

## 10. Resumen en una línea

Cinco litros al día repartidos en tres tomas, midiendo cada mañana, aireando entre tomas,
parando si el pH baja de 7,0. Seis días hasta 120. Al final, corte de corriente para resetear la
alarma. Después, 1 L por cada m³ que se reponga, y tapar la piscina para reponer lo menos posible.
