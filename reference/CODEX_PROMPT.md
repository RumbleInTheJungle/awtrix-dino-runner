# Codex-Auftrag: Dino Runner – zehn lebendige Pixelwelten mit Parallax-Scrolling

## Kontext und Referenzen

Du arbeitest im bestehenden **Dino-Runner-Spiel für AWTRIX-NG / Ulanzi TC002** (Berry-Skript, **52 × 16 RGB-LED-Pixel**). Es geht **nicht** darum, ein neues Spiel zu schreiben, sondern das bestehende Spiel um zehn grafisch eigenständige, lebendige Welten zu erweitern.

Verwende die angehängten Referenzbilder:

- `reference_10_levels.png` – verbindliche **gestalterische Inspiration** für die zehn Welten (Farbwelt, Kulissen, Hindernisthemen, Stimmung). Das Poster ist ein **Konzeptbild**, keine 1:1 verwendbare 52×16-Sprite-Datei; reduziere die Details auf die echte Auflösung.
- `reference_original_dino_day.png` und `reference_original_dino_night.png` – der **bisherige blaue Dinosaurier im bestehenden Spiel**. **Behalte seine Form, Grösse, Lauf-/Sprunganimation, Position und das vorhandene Kollisionsverhalten unverändert bei.** Auch die bereits vorhandene Konfiguration seiner Farbe muss weiter funktionieren.

Wichtig: Der Dino bleibt exakt der bestehende Sprite. **Nur Welten, Kulissen, Boden, Umgebungsanimationen, thematische Darstellung bestehender Hindernisse und Übergänge** werden erweitert.

## Vorgehensweise

1. Lies zuerst im Workspace vorhandene Projektanweisungen (`AGENTS.md`, `SKILLS.md`, README etc.), die bestehende Dino-Runner-Berry-Datei und relevante AWTRIX-NG-Zeichen-/Animations-APIs. **Erfinde keine Berry-APIs**, sondern nutze ausschliesslich die im Repository verfügbaren Mechanismen.
2. Analysiere die aktuellen Render-Reihenfolgen, den Game Loop, Sprite-Geometrien, Hindernisgenerierung, Score, Geschwindigkeit, Einstellungen, Tag-/Nachtwechsel, Demo-Modus, Töne und die Eingaben über Tasten bzw. BLE-Gamepad.
3. Skizziere eine kurze Implementierungsstrategie und setze sie dann **direkt im vorhandenen Spiel** um. Bitte keine isolierte Demo, die den bisherigen Code ersetzt.
4. Implementiere die Welten möglichst **datengetrieben** (Welten-ID, Palette, Hintergrundmuster, Deko-Sprites, Hindernis-Skins, Partikeleffekte), mit gemeinsamem Parallax-Renderer statt zehn unabhängigen Kopien des Game Loops.
5. Teste die Darstellung in der echten logischen **52×16-Pixel-Auflösung**, nicht nur auf hochskalierten Entwürfen. Erzeuge, wenn technisch machbar, pro Welt einen vergrösserten Pixel-Preview/Screenshot; teste Animation und Speicher-/CPU-Verhalten auch auf Hardware, soweit möglich.

## Unverhandelbare Anforderungen

- **Display:** Genau 52 Spalten × 16 Zeilen. Kein Anti-Aliasing und keine Zwischenpixel. Alle Inhalte bleiben innerhalb des Displays und sind auf einer echten LED-Matrix klar erkennbar.
- **Bestehender Dino:** Sprite unverändert; nicht neu zeichnen oder „verschönern“. Bestehende Sprünge, kurze/lange Tastendrücke, Sprungphysik, Kollisionsboxen, Spielfluss, Highscore, Demo-Modus und Eingabegeräte beibehalten.
- **Spielbarkeit vor Dekoration:** Dino und spielrelevante Hindernisse haben stets Vorrang. Keine Hintergrundpixel dürfen Hindernisse unkenntlich machen. Bei einer Kollision gelten die bisherigen Regeln, nicht zufällige reine Hintergrundobjekte.
- **Lebendige Kulissen:** Jeder Level hat eine erkennbare eigene Farbpalette, einen langsam horizontal wandernden Hintergrund, mindestens zwei Tiefenebenen, kleine Umgebungsanimationen und passende Boden-/Hindernisgrafiken.
- **Keine optische Überladung:** Auf 52×16 wirken selbst 2–3 zusätzliche LEDs stark. Deutlich mehr dunkle/ruhige Bereiche als im Poster verwenden. Atmosphärische Effekte sparsam und mit reduzierter Helligkeit zeichnen; die Spielfiguren bleiben besser sichtbar als die Deko.
- **Bestehende Features nicht brechen:** Insbesondere Gamepad/BLE, die Uhren-Bedientasten, bestehende Matrix-Regen-Funktion, Score/Highscore, Sounds, Reset, Einstellungen sowie Tag-/Nachtwechsel und Geschwindigkeitssteigerung beibehalten.

## Parallax-Scrolling und Animation: konkrete Umsetzung

Die Spielfigur läuft optisch auf der linken Seite, während die Welt von rechts nach links wandert. Verwende voneinander unabhängige, nahtlos wiederholbare Layer:

1. **Fernhintergrund (Far):** Horizont, Berge, entfernte Silhouetten, Wolken/Ferngebäude. Sehr langsame horizontale Bewegung, z. B. **3–6 % der aktuellen Hindernis-/Weltgeschwindigkeit**.
2. **Mittelgrund (Mid):** Bäume, Hügel, Ruinen, Gebäude, Höhlenwände, Mondelemente. Langsamer als Bodendetails, z. B. **8–14 %** der Hindernisgeschwindigkeit.
3. **Vordergrund-Dekoration (Near):** Grasbüschel, kleine Steine, Schilder, Blumen, Bodenglanz, ungefährliche Pflanzen. Deutlich schneller, aber langsamer als Hindernisse, z. B. **18–30 %** der Hindernisgeschwindigkeit.
4. **Spielobjekte (Gameplay):** Die bestehenden kollidierbaren Hindernisse bewegen sich mit der tatsächlichen Spielgeschwindigkeit und behalten ihr bisheriges Timing, ihre Abstände und Kollisionen. Ihre thematischen Grafiken können pro Welt variieren, aber nicht unbemerkt die Schwierigkeit ändern.
5. **Atmosphäre (FX):** Regen, Schnee, Funken, Staub, Sterne, Code-Regen, flackernde Lichter; sie bewegen sich unabhängig (oft vertikal). Sehr sparsame Partikelzahl und niedrige Helligkeit, ohne das Bild unruhig wirken zu lassen.

Geschwindigkeiten sollen **zeitbasiert** (delta time bzw. die im Spiel vorhandene Zeitbasis) und nicht frameabhängig sein. Für Subpixelbewegung intern Bruchteile akkumulieren und erst beim Zeichnen auf Pixelpositionen runden. Benutze deterministisch wiederholbare Muster bzw. zyklische Tile-Streifen, damit keine sichtbaren Nähte oder leeren Spalten beim Scrollen entstehen. Wenn die Hardware oder Berry-Runtime eingeschränkt ist, wähle eine speicherarme Lösung (vordefinierte Pixelmuster, Integer/Fixpunkt-Offsets, wenige temporäre Objekte), ohne in jeder Frame neue grosse Arrays zu bauen.

**Layer-Reihenfolge:** Hintergrundfarbe → Far → Mid → nicht-kollidierende Near-Deko → Boden/Hindernisse → Dino → HUD/Score. Dekoration am Boden darf die Silhouette des Dinos und die Oberkante der Hindernisse nicht übermalen. Beachte dabei das tatsächliche vorhandene `groundY`/Koordinatensystem des Spiels; die Werte nicht blind überschreiben. Reserviere Platz für die bestehende Scoreanzeige, falls diese im Spiel eingeblendet wird.

## Die zehn Level – detaillierte Art Direction

### 01 – Classic Grassland Day (klassische Graslandschaft)

**Farbklima:** Helles Himmelblau, zwei dunklere Grüntöne, frisches Hellgrün, erdiges Braun, kleine gelbe Sonnenakzente. Positiv, hell, klassischer Dino-Runner-Look.

- **Fernhintergrund:** Flacher blauer Himmel. Eine kleine gelbe Sonne rechts oben (beim Scrolling als sehr weit entfernt nahezu ortsfest) und vereinzelte kompakte, 2–5 Pixel breite weisse Wolken, die extrem langsam nach links ziehen.
- **Mittelgrund:** Zwei Reihen unregelmässiger dunkelgrüner Hügel-/Buschsilhouetten; der hintere Höhenzug scrollt langsamer als die vordere Baum-/Gebüschreihe. Klare Silhouetten statt individueller Blätter.
- **Vordergrund:** Leuchtend grüne Grasoberkante auf braunen Erd-Pixeln, gelegentliche 1–2-Pixel-Grasbüschel, kleine Blumen/Steine und ein Baumstumpf. Die Bodenstruktur wandert kontinuierlich von rechts nach links.
- **Spielhindernisse:** Kleine Felsen, Baumstümpfe oder feste Buschformen, mit unveränderten spielmechanischen Hitboxen.
- **Animation:** Wolken langsam vorbeiziehen lassen; selten einen Grasbüschel-Pixel variieren. Keine permanent flackernden Farben.

### 02 – Desert Dunes (Wüste)

**Farbklima:** Tiefes Orange/Gold, Sandgelb, Rotbraun, dunkles Kaktusgrün. Heiss, trocken, weite Landschaft.

- **Fernhintergrund:** Warmer orangefarbener Himmel mit kleinem gelbem Sonnenkreis und sehr weit entfernten rotbraunen Tafelbergen, die fast stillstehen.
- **Mittelgrund:** Zwei sich überlappende, leicht wellige Dünen-Silhouetten in Ocker und Dunkelorange; einzelne Kakteen weit hinten wandern etwas schneller als die Dünen.
- **Vordergrund:** Sandfarbener Boden mit dunkleren 1-Pixel-Kieseln, kleinen Sandhügeln und gelegentlichen Knochen-/Rippenfragmenten als Deko. Staubschleier maximal vereinzelt und dezent.
- **Spielhindernisse:** Deutliche 2–4 Pixel breite Kaktus- und Fels-Silhouetten; hohe Kakteen müssen gut von rein dekorativen Hintergrundkakteen unterscheidbar bleiben.
- **Animation:** Seltene Staubpixel gleiten horizontal, Dünen parallaxen langsam; keine flächendeckende Sandpartikelwolke.

### 03 – Jungle Ruins (Dschungelruinen)

**Farbklima:** Schwarzgrün, Smaragd, Türkisgrün, moosiges Hellgrün und dunkelgrauer Stein. Dicht, geheimnisvoll, aber gut lesbar.

- **Fernhintergrund:** Sehr dunkler Wald mit weichen, aus wenigen Stufen bestehenden Baumkronen-Silhouetten.
- **Mittelgrund:** Mehrere Baumstämme und angedeutete Tempelwände/Säulen aus grauen quadratischen Steinen, teils mit hellgrünen Mooskanten; langsam versetztes Scrolling. An der oberen Displaykante sehr wenige hängende Lianen.
- **Vordergrund:** Moosiger Steinboden mit einzelnen versetzten Steinen, winzigen Farnen, Wurzeln und Grasspitzen. Gelegentliche zerfallene Steinsäulen erscheinen seitlich am Weg.
- **Spielhindernisse:** Klar erkennbare Steinblöcke, überwucherte Säulenfragmente oder Wurzelhindernisse.
- **Animation:** Alle paar Sekunden eine Liane/ein Blatt um einen Pixel schwingen lassen. Nichts darf sich vor die Dino-Silhouette legen.

### 04 – Neon City Night (Neonstadt)

**Farbklima:** Sehr dunkles Navyblau, Schwarzviolett, kräftiges Pink/Magenta, Neon-Cyan, wenige gelbe Signallichter. Futuristischer Arcade-Stil.

- **Fernhintergrund:** Dunkle Skyline verschiedener rechteckiger Gebäude. Einzelne Fenster als 1-Pixel-Punkte, nur sehr langsame Bewegung.
- **Mittelgrund:** Vertikale Cyan- und Pink-Lichtleisten, abstrakte Reklametafeln und Neon-Pfeile. Gebäude der vorderen Skyline laufen schneller als die fernen Hochhäuser.
- **Vordergrund:** Dunkler technischer Boden mit einer durchgehenden cyanfarbenen Laufkante, regelmässigen Bodenplatten und nur vereinzelten leuchtenden Schrauben-/Lichtpunkten.
- **Spielhindernisse:** Scharf abgegrenzte Absperrblöcke, Kisten, niedrige Poller, Industriebarrieren mit gelben Warnstreifen; geometrische Hitboxen wie bisher.
- **Animation:** Gelegentlich ein Fenster oder eine Neonröhre sanft aufhellen, Leuchtschilder sehr sparsam wechseln; kein aggressiver Stroboskopeffekt.

### 05 – Snow / Ice (Eiswelt)

**Farbklima:** Dunkelblau, Eisblau, Cyan, Weiss. Kalte, klare Winterwelt.

- **Fernhintergrund:** Nachthimmel mit winzigen Schneepunkten; grosse, hellblaue Bergsilhouetten in weiter Entfernung, sehr langsame Bewegung.
- **Mittelgrund:** Kleinere Bergkämme und einzelne schneebedeckte Tannen; hinter dem Weg gelegentlich niedrige Eisformationen.
- **Vordergrund:** Schneeweisse Laufkante, darunter dunkelblaue Eisschichten, vereinzelte helle Eisreflexe. Kleine Schneehaufen und vereiste Steinchen als unschädliche Deko.
- **Spielhindernisse:** Eis-Kristallspitzen, Schnee-/Eisblöcke oder vereiste Felsen, optisch klar erkennbar und ohne neue versteckte Kollisionen.
- **Animation:** Wenige kleine Schneeflocken fallen mit leicht seitlicher Drift; vereinzelt glitzert ein Pixel an einer Eisfläche. Kein dichtes Schneegestöber, das Hindernisse verdeckt.

### 06 – Volcano / Lava Cavern (Vulkanhöhle)

**Farbklima:** Fast Schwarz, dunkles Rotbraun, glühendes Rot, Orange und sparsame gelbe Akzente. Gefährlich und warm.

- **Fernhintergrund:** Dunkle Felswände mit roten Konturen und entfernten orangefarbenen Lavastreifen; extrem langsame Parallax-Bewegung.
- **Mittelgrund:** Stalaktiten von oben, dunkle Felsspalten und vereinzelt schmale vertikale Lavaströme; Lavaströme dürfen den Dino nicht verdecken und sind rein optisch, sofern sie nicht als echtes Hindernis existieren.
- **Vordergrund:** Schwarzer/dunkler Steinweg mit dünn glühenden Rissen und roter Unterkante. Kleine Steine, ein paar Lava-Sprenkel und Felsnasen.
- **Spielhindernisse:** Spitze Felsen, harte Basaltblöcke, klar sichtbare Lava-/Glut-Hindernisse mit den bestehenden Hitboxen. **Keine scheinbaren Abgründe** zeichnen, wenn der Runner gar keine Grubenmechanik hat.
- **Animation:** Seltene orange Funken steigen auf, Lavastreifen pulsieren sanft mit wenigen Helligkeitsstufen. Keine schnellen grossflächigen Flashes.

### 07 – Moon Base / Space (Mondbasis)

**Farbklima:** Fast schwarzer Weltraum, kühles Grau/Violett, Mondweiss, etwas Cyan und Blaugrün für einen fernen Planeten.

- **Fernhintergrund:** Fast schwarzer Sternenhimmel mit wenigen statischen/blinkenden Sternen und einem kleinen blaugrünen Planeten. Planet und Sterne bewegen sich im Vergleich zu anderen Ebenen kaum.
- **Mittelgrund:** Graue Mondhügel und entfernte Kuppeln einer Forschungsstation, schmale Antennen oder Satellitenschüsseln; die Bauwerke passieren langsam.
- **Vordergrund:** Grauer metallisch-mondstaubiger Untergrund mit einzelnen blauen Bodenlichtern, kleinen Kratern/Steinen und regelmässigen Bodenpanelen.
- **Spielhindernisse:** Mondgesteinsbrocken, Versorgungskisten, kleine technische Pfeiler; im Vordergrund klare Kontrastkante.
- **Animation:** Sehr selten funkelt ein Stern oder blinkt ein Antennenlicht. Optional ein kleiner langsam wandernder Satellit im Hintergrund. **Die bestehende Sprungphysik bleibt normal**; „Weltraum“ ist zunächst nur visuell.

### 08 – Storm Night (Gewitternacht)

**Farbklima:** Dunkles Indigo, Blauviolett, Anthrazit, kaltes Hellblau und wenige gedämpfte Grünpunkte.

- **Fernhintergrund:** Dunkelviolette Sturmwolken in mehreren Höhen, langsam von rechts nach links; gelegentlich helle Wolkenkante.
- **Mittelgrund:** Tiefblaue Wald-/Hügel-Silhouetten, kahle Bäume und grosse entfernte Felsen; langsam und gleichmässig scrollend.
- **Vordergrund:** Dunkler Erd-/Steinboden, vereinzelte grüne Grashalme und Steine; kleine nasse Lichtreflexe im unteren Pixelband.
- **Spielhindernisse:** Grosse Steine, abgestorbene Wurzeln, Aststümpfe, die sich deutlich vom dunklen Hintergrund absetzen.
- **Animation:** Vereinzelte diagonale Regenstriche (z. B. 1–3 gleichzeitig), ab und zu ein gezackter 2–4-Pixel-Blitz im fernen Himmel. **Keine Fullscreen-Blitze** und keine Effekte direkt über Dino/Hindernissen.

### 09 – Crystal Caverns (Kristallhöhlen)

**Farbklima:** Dunkles Mitternachtsblau, Cyan, leuchtendes Türkis, Violett und Magenta. Magisch, funkelnd, unterirdisch.

- **Fernhintergrund:** Fast schwarzer Höhlenraum mit dunkelvioletten Felswänden und wenigen angedeuteten tiefen Spalten.
- **Mittelgrund:** Langsam wandernde Stalaktiten und weit entfernte Kristalladern; verschieden grosse kristalline Formen leuchten gedämpft türkis/violett.
- **Vordergrund:** Dunkler Felsboden mit schmalem cyanfarbenem Lichtsaum, winzigen kristallinen Splittern und vereinzelten Spiegelungen **nur im untersten Displaybereich**.
- **Spielhindernisse:** Helle scharfkantige Kristallcluster, einzelne grosse Kristallsäulen oder Felsformationen mit leuchtenden Kanten. Gefährliche Kristalle müssen klar heller/kontrastreicher sein als nicht kollidierende Deko.
- **Animation:** Unregelmässig glitzern einzelne Kristallspitzen für einen Moment; gelegentlich läuft ein Lichtpunkt entlang einer Kristallader. Keine flächigen Farbwechsel.

### 10 – Matrix Level (digitale Codewelt)

**Farbklima:** Tiefschwarz, dunkles Grün, sattes Grün, helle neon-grüne Akzente, wenig Weiss. Bewusst reduziert und sehr kontrastreich. Der vorhandene **blaue Dino bleibt unverändert**, damit er sich eindeutig vom Hintergrund abhebt.

- **Fernhintergrund:** Schwarzer Hintergrund mit dünnen, weit auseinanderstehenden vertikalen Spuren aus grünen Binär-/Code-Pixeln. Der Regen fällt **vertikal von oben nach unten** (eigene Geschwindigkeit, verschiedene Spurlängen), unabhängig vom horizontalen Parallax-Scrolling.
- **Mittelgrund:** Dunkle digitale Säulen, Datenblöcke, angedeutete Monitore/Terminals und dünne Leuchtlinien, die langsam horizontal nach links ziehen. Nur wenige bewusst gesetzte hellgrüne Konturen.
- **Vordergrund:** Schwarzer Boden mit einer dünnen neon-grünen Laufkante und regelmässigen „Datenpaket“-Markierungen; einzelne kleine grüne Funken/Codepunkte scrollen nach links.
- **Spielhindernisse:** Rechteckige grüne Datenblöcke, Terminal-Pfeiler, Datenbarrieren oder digitale Säulen. Kollidierbare Objekte müssen **heller und/oder durchgehender** als die transparent wirkenden Code-Regenspuren sein.
- **Animation:** Mehrere voneinander unabhängige vertikale Code-Regen-Spuren mit hellgrünen Köpfen und dunkleren Schweifen, gelegentlich ein subtiler 1-Pixel-Glitch an rein dekorativen Datenblöcken. **Kein Glitch auf Dino, Score oder Kollisionen.** Bestehenden Matrix-Modus / vorhandene Regenroutine nach Möglichkeit weiterverwenden und sinnvoll integrieren, aber Gamepad- und Tastensteuerung dabei nicht verlieren.

## Weltenfolge, Tag/Nacht und Einstellungen

Implementiere zehn auswählbare Welten mit stabilen IDs `1..10` und klaren Namen. Vorgeschlagenes Verhalten:

- **Auto-Modus (Standard):** Die Welten 1→2→…→10→1 nacheinander durchlaufen. Wechsel in sinnvoller, konfigurierbarer Distanz, **z. B. nach zwei vorhandenen Tag-/Nacht-Intervallen**. Prüfe zuerst, wie Score und Tag-/Nacht-Schwelle im tatsächlichen Code funktionieren, statt pauschal eine neue Zählweise einzuführen.
- **Fixierter Modus:** Optional eine Welt 1–10 dauerhaft auswählen, praktisch für Demo, Entwicklung und persönliche Lieblingswelt. Die restlichen Spielmechaniken funktionieren weiter.
- **Tag/Nacht:** Vorhandenen Wechsel (bisher z. B. bei Score 700), dessen Geschwindigkeitserhöhung und Sounds weiterhin ausführen. Weltwechsel und Tag/Nacht dürfen einander nicht doppelt auslösen oder den Score zurücksetzen. Bei den Welten, bei denen Tag/Nacht gut passt, verwende eine leicht geänderte Palette für Nacht/Tag. Für thematisch permanente Nachtwelten bleibt der Look stimmig (z. B. Neon City und Matrix), ohne die bestehende Zustandsmaschine zu stören.
- **Übergänge:** Kurzer, ruhiger Farb-/Kulissenübergang von etwa 0,5–1 s, wenn mit der vorhandenen Rendertechnik machbar; kein schwarzer Bildschirm, kein plötzlicher Hindernis-Reset, kein weisser Flash. Bei Performance-/Speicherproblemen einfache direkte Umschaltung mit wenigen Übergangs-Pixeln statt teurer Alpha-Blends.
- **Einstellungen:** `worldMode` (auto/fixed), `fixedWorld` (1–10), `worldChangeInterval` (passend zur bestehenden Scorelogik), `parallaxEnabled`, `parallaxIntensity` (0–100 %, sinnvolle Standardstärke), `ambientEffectsEnabled`, `ambientEffectDensity` (0–100 %, eher sparsam). In bestehende Settingsstruktur integrieren, Standardwerte und Grenzen gemäss vorhandenem Stil dokumentieren. Bestehende Optionen unverändert behalten.
- **Demo-Modus:** Die neu gestalteten Welten auch in der bestehenden automatischen Demo darstellen; der Demonstrationsmodus bleibt steuerbar/abschaltbar wie bisher.

## Technische Details und Qualität

- Bewahre sämtliche bestehenden Hindernisabstände, Sprungtimings und Schwierigkeitskurven. Weltwechsel dürfen die Bewegungsgeschwindigkeit **nicht zusätzlich** erhöhen – dafür ist weiterhin die bisherige Schwierigkeitssystematik zuständig.
- Unterscheide in den Daten klar zwischen `decoration` (ohne Kollision) und `obstacle` (bestehende Hitbox). Für jede Welt passende Hindernis-Skins wählen, aber wenn nötig die bisherigen Hindernissilhouetten mit lediglich neuen Farben beibehalten, um Sprungbreite und Schwierigkeit nicht zu verfälschen.
- Nutze für jede Welt wenige kleine, wiederverwendete Sprites/Zeichenfunktionen statt grosser eingebetteter Bildressourcen. Hintergründe sollen aus echten Pixelmustern und kleinen Algorithmen bestehen, nicht aus dem riesigen Posterbild gerendert werden.
- Stelle durchgehend sicher: keine verwirrenden Lichtpunkte auf der Dino-/Hindernisbahn, keine grellen dauerblinkenden Effekte, keine Kollisionsobjekte mit unsichtbaren Hitboxen. Bei Bedarf Hintergrund-Helligkeit priorisiert reduzieren.
- Wenn Partikel/Parallax zu viele Ressourcen benötigen, automatisch auf weniger FX zurückfallen, **ohne** Renderfehler oder Eingabelag. Keine unkontrollierten Heap-Allokationen pro Frame.
- Falls bereits ein Matrix-Mode existiert, integriere ihn als Hintergrundstil der zehnten Welt und erhalte alle bisherigen Nutzeroptionen und Controller-Funktionen. Keinen zweiten inkompatiblen Effekt parallel einführen.

## Definition of Done / bitte am Ende liefern

1. Konkrete Änderungen an den **bestehenden Berry-Dateien** (und notwendigen Settings-/Asset-Dateien) – nicht nur Pseudocode.
2. Alle zehn Welten laufen und unterscheiden sich farblich und durch ihre Vorder-/Mittel-/Hintergrundelemente **sichtbar auf 52 × 16 Pixeln**.
3. Mindestens zwei horizontal scrollende Parallax-Layer je Welt, plus themenspezifische FX, soweit aktiviert.
4. Dino, Gamepad/BLE, Jump, Hindernisse, Score, Sounds, Demo und Tag-/Nachtwechsel funktionieren unverändert.
5. Keine abrupt sichtbaren Tile-Nähte, unlesbaren Hindernisse oder FPS-/Speichereinbrüche unter normalen Spielbedingungen.
6. Kurze Beschreibung der neuen Settings, eine Übersicht geänderter Dateien, durchgeführter Tests und noch offener Hardwareprüfungen.
7. Wenn im Projekt möglich, zehn **echte 52×16-Pixel-Screenshots** aus dem Renderer als Review-Artefakte; nicht durch KI-Hochglanzbilder ersetzen.

Bitte **zuerst die bestehende Implementierung verstehen, danach vollständig umsetzen**. Nutze die Bilder als visuelle Leitplanken, aber optimiere jede Welt für die realen 52×16 RGB-LEDs der TC002 und die Fähigkeiten von AWTRIX-NG/Berry.
