# Ten pixel worlds

This is the adopted graphics specification for Dino Runner’s 52×16 display.

## Shared behaviour

The original dino’s shape, size, running and jumping animation, position and collision behaviour remain unchanged. P1 and solo default to blue `#3399FF`; P2 defaults to `#FF3355`. In Matrix, both players are green and the ready labels identify their turns.

Auto mode visits worlds 1–10 in order, repeating after Matrix. Worlds change every 1,000 pixels. Fixed mode keeps a favourite world. Day/night milestones remain every 500 pixels, with one compounded 5% speed increase and the existing milestone sound.

Grassland, desert, jungle, snow and moon base turn to a moonlit night on every second milestone. Scenery shifts to a darker blue-grey with a lower LED floor (far 40, mid 50, near 64, soil 40), the sky goes nearly black, stars and a moon appear, and hazards keep their daylight colours. Within one world, day and night fade over 1.5 seconds with an orange dusk or pink dawn band over the horizon; the moon base has no band. A change of world keeps the half-second fade.

Permanent night and cavern themes keep their scenery and shift into a subtler late phase: the sky darkens, Neon City dims its windows, turns every other one off and lets a sign drop out now and then, lava cools, storm clouds grow heavier with lightning twice as often, crystals glow less and Matrix terminals dim while the rain thins to half its columns.

Far scenery scrolls at 4% of gameplay speed, mid scenery at 10% and near details at 24%, scaled by the parallax intensity setting. Patterns wrap without an empty edge. Sparse ambient effects use their own animation time. Pausing freezes everything.

The draw order is background, far scenery, mid scenery, near decoration, ground and obstacles, dino, then HUD. A half-second palette transition changes scenery halfway through, without resetting obstacles. Distant decoration stays dimmer than hazards. Ground remains continuous: decorative pits and platforms do not imply new game mechanics.

The original poster is concept art. Actual graphics use small pixel patterns, silhouettes and geometric motifs. The detailed directions below guide refinements within the limited resolution. Individual scene details are reduced where readability requires it.

## 1. Classic Grassland Day

**Palette:** subdued sky blue, two dark greens, fresh grass green, earth brown and small yellow sun accents.

**Far:** a tiny sun and compact white clouds drifting very slowly. **Mid:** overlapping stepped hill and bush silhouettes at different depths.

**Near and ground:** a green running edge over brown earth, with sparse tufts, flowers and stones. **Obstacle direction:** rocks, stumps or solid bushes, using the original silhouettes where needed to preserve readable timing. Airborne hazards remain recognisable.

**Animation:** drifting clouds and occasional one-pixel grass movement. Night darkens the scene, turns the sun into a moon and adds restrained stars.

## 2. Desert Dunes

**Palette:** orange, gold, sand yellow, red-brown and dark cactus green.

**Far:** a small sun and distant mesas. **Mid:** overlapping ochre dunes and dim background cacti.

**Near and ground:** sand, isolated pebbles, small mounds and tiny bone-fragment motifs. **Obstacles:** contrasting cacti and rocks. Decorative cacti remain darker and separate from the hazard lane.

**Animation:** occasional drifting dust. No dense sand cloud.

## 3. Jungle Ruins

**Palette:** near-black green, emerald, turquoise, moss green and grey stone.

**Far:** dark stepped canopy silhouettes. **Mid:** trunks, temple walls, moss-edged stone columns and a few hanging-vine motifs.

**Near and ground:** mossy stone, small ferns, roots and masonry. **Obstacles:** stone blocks, broken columns and roots.

**Animation:** a leaf or vine shifts one pixel every few seconds; at night, fireflies blink between the trees. Decoration never draws over the dino.

## 4. Neon City Night

**Palette:** dark navy and violet, cyan, magenta and sparse yellow signals.

**Far:** rectangular skyline with isolated window pixels. **Mid:** light strips, abstract signs and nearer buildings.

**Near and ground:** dark technical plates, a thin cyan running edge and occasional lights. **Obstacles:** crates, bollards and warning-striped industrial barriers.

**Animation:** occasional gentle window or sign brightening. No strobing. Day/night milestones retain the night-city identity.

## 5. Snow / Ice

**Palette:** dark blue, ice blue, cyan and controlled white highlights.

**Far:** distant mountain silhouettes and a few snow points. **Mid:** smaller ridges, snowy fir motifs and low ice formations.

**Near and ground:** a snow-white running edge over blue ice, with small snow piles and reflections. **Obstacles:** ice blocks, frozen rocks and crystal-like forms within the existing hitboxes.

**Animation:** sparse drifting snow and occasional glints; stars and a crescent moon at night. Snow never becomes dense enough to hide hazards.

## 6. Volcano / Lava Cavern

**Palette:** near-black, red-brown, glowing red and orange, with sparse yellow.

**Far:** dark rock walls and distant lava seams. **Mid:** stalactites, fissures and narrow decorative lava streams.

**Near and ground:** continuous dark stone, thin glowing cracks and a red lower edge. **Obstacles:** basalt blocks, pointed rock motifs and clearly defined ember hazards.

**Animation:** a few rising sparks and restrained lava highlights. No apparent pits, full-display flashes or lava drawn over gameplay objects.

## 7. Moon Base / Space

**Palette:** black space, cool grey and violet, moon white, cyan and a blue-green planet.

**Far:** sparse stars and a tiny planet. **Mid:** lunar hills, station domes, antennae and small dish motifs.

**Near and ground:** lunar dust or metal plates, tiny craters and occasional blue lights. **Obstacles:** moon rocks, supply crates and technical pillars.

**Animation:** rare star glints or antenna lights. A satellite is an optional refinement only if readable. Gravity and jump physics remain normal.

## 8. Storm Night

**Palette:** indigo, blue-violet, charcoal, pale cold blue and muted green.

**Far:** layered storm clouds with occasional highlighted edges. **Mid:** dark hills, bare trees and distant rocks.

**Near and ground:** dark earth and stone, sparse grass and wet reflections. **Obstacles:** contrasting stones, dead roots and broken stumps.

**Animation:** one to three diagonal rain streaks at normal settings and occasional small distant lightning shapes. No full-display flashes or effects drawn over gameplay objects.

## 9. Crystal Caverns

**Palette:** midnight blue, cyan, turquoise, violet and magenta.

**Far:** dark cave walls and sparse fissures. **Mid:** stalactites and dim crystal-vein motifs.

**Near and ground:** dark rock, a thin cyan edge, fragments and reflections confined to the bottom row. **Obstacles:** bright crystal clusters, columns and edged rocks. Dangerous crystals stay brighter than decoration.

**Animation:** isolated sparkles and occasional travelling highlights. Avoid broad colour cycling.

## 10. Matrix

**Palette:** black, dark green, saturated green and restrained pale-green accents.

**Far:** reuse the original vertical rain with independent speeds and trail lengths. **Mid:** dim digital columns, data blocks and sparse terminal outlines scrolling horizontally.

**Near and ground:** a thin green running edge, packet markings and occasional code pixels. **Obstacles:** solid bright data barriers and terminal pillars, distinct from rain.

**Animation:** restrained rain and rare decorative one-pixel motifs. Never glitch the dino, HUD or collision geometry. Both dinos are green; **P1 READY** and **P2 READY** identify turns.

## Reference and review

The original detailed German prompt and the three reference PNGs are kept locally in the ignored `reference/` folder and are not published with this repository. The blue dino in the Matrix concept image does not apply to this implementation.

Review [the rendered contact sheet](../previews/contact-sheet.png) and the individual 52×16 PNGs in `previews/`. These are outputs from the game’s Berry renderer, using native raster mocks in the test host. They are not AI-generated previews.
