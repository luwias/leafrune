# Leafrune Akadémia

Varázslótanoncként egy bejárható üvegházban tanulsz: felveszed a feladatot, utánanézel a növénynek a Herbáriumban, összeszeded a hozzávalókat, elülteted, gondozod, és leadod. Később 2–4 fős közös játék lesz belőle.

Motor: **Godot 4** (Standard, GDScript) · Modellek: **Blender**

## Indítás

1. Nyisd meg a Godotot, és válaszd az **Import** gombot.
2. Tallózd be ezt a mappát, és jelöld ki a `project.godot` fájlt.
3. Ha a Godot megkérdezi, hogy átalakítsa-e a projektet az újabb verzióhoz, mondj igent.
4. Nyomd meg a jobb felső sarokban a ▶ gombot (vagy F5).

## Irányítás

| Mit csinálsz | Gomb |
|---|---|
| Mozgás | W A S D vagy a nyilak |
| Futás | Shift |
| Kamera forgatása | kattints a játékba, utána az egérrel |
| Felvesz, letesz, használ | E |
| Ablak bezárása, egér elengedése | Esc |

## Egy feladat menete

1. **Feladattábla** (a bejárat bal oldalán): megnézed, mit kell nevelni.
2. **Herbárium** (jobb hátsó sarok): elolvasod a növény lapját. Utána a cserepek fölött látod, mire van szüksége, és egy kérdésre válaszolva plusz csillagot szerezhetsz.
3. **Raktárpolc** (jobb fal): virágföld, magok, öntözőkanna. Egyszerre egy dolog lehet a kezedben.
4. **Vízcsap** (jobb első sarok): itt töltöd meg a kannát.
5. **Cserepek**: föld, mag, locsolás. A Holdliliom az **árnyékos** asztalon nő (bal fal), a Suttogó páfrány a **napos** asztalon (hátsó fal). A páfránynak bimbós korában dúdolni kell: állj mellé üres kézzel, és nyomd meg az E-t.
6. Ha kész, üres kézzel learatod, és viszed a **Leadópulthoz** (bal hátsó sarok). Az elhervadt növény a **Komposztba** megy.

## Az üvegház modellje Blenderből

A játék magától épít egy egyszerű üvegházat. A szebb változatot a Blender-szkript készíti el:

1. Nyisd meg a Blendert, és fent válts a **Scripting** fülre.
2. Kattints az **Open** gombra, és nyisd meg a `blender/greenhouse_shell.py` fájlt.
3. A fájl elején az `EXPORT_PATH = r""` sorba írd be a projekt mappáját, például:
   `EXPORT_PATH = r"C:\Users\Anita\Documents\GitHub\leafrune\assets\models\greenhouse.glb"`
4. Nyomd meg a ▶ (Run Script) gombot.
5. Válts vissza a Godotra: magától beolvassa az új fájlt, és a következő indításkor már azt az üvegházat látod.

## Felépítés

| Fájl | Mit csinál |
|---|---|
| `scripts/game_state.gd` | A teljes játékállapot és szabályok (cserepek, tárgyak, feladatok, óra). Ebben nincs semmi 3D, ezért a multihoz ezt futtatja majd a hoszt. |
| `scripts/main.gd` | Felépíti az üvegházat, a bútorokat és az állomásokat. |
| `scripts/player.gd` | A tanonc mozgása, a kamera, és hogy mit használsz az E-vel. |
| `scripts/pot_view.gd` | Egy cserép és a benne lévő növény kinézete. |
| `scripts/hud.gd` | Kezelőfelület, Herbárium, feladattábla. |
| `blender/greenhouse_shell.py` | Blender-szkript az üvegház vázához. |

Új növényt a `game_state.gd` fájl `PLANTS` részében lehet hozzáadni.
