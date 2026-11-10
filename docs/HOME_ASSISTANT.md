# Room lights with Home Assistant

Dino Runner can dim your room while you play. With the blueprint below, Home Assistant lowers your lights when a match starts, keeps them brighter by day and darker at night, and can tint colour lights in each world's colour. When the match ends, it puts the lights back as they were.

The game itself knows nothing about lamps. It reports its state over MQTT, and the blueprint decides what the lights do.

## What you need

- An AWTRIX NG clock connected to the same MQTT broker as Home Assistant. If the clock already shows up in Home Assistant through MQTT, this is done.
- Home Assistant 2024.10 or newer with the MQTT integration.
- Dino Runner 2026.11.1 or newer on the clock.

## Set it up

1. Import the blueprint:

   [![Open your Home Assistant instance and show the blueprint import dialog.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2FRumbleInTheJungle%2Fawtrix-dino-runner%2Fblob%2Fmain%2Fhomeassistant%2Fdino_runner_lights.yaml)

   Or go to **Settings → Automations & scenes → Blueprints → Import blueprint** and paste `https://github.com/RumbleInTheJungle/awtrix-dino-runner/blob/main/homeassistant/dino_runner_lights.yaml`.
2. Create an automation from **Dino Runner room lights**.
3. Enter the clock's **MQTT prefix**. If the clock has no prefix set, enter its **uid** instead: twelve lowercase hex characters such as `a4cf12ab34cd`, shown in the clock's device information and at the start of its MQTT topics.
4. Choose your lights and save.

To try it without playing, choose **Worlds** in the game's menu. The tour changes between day and night every five seconds and walks through every world.

## What happens

| In the game | Lights |
|---|---|
| Menu, high scores | unchanged |
| Countdown | the current lighting is saved, then the lights dim |
| Running by day | day brightness (default 60%) |
| Running at night, or in a world that is always dark | night brightness (default 15%) |
| Pause, second player's turn | stay as they are |
| Results, leaving the game, clock offline | the saved lighting comes back |

With **World colours** on, colour lights take each world's colour: warm sunlight in the grassland, orange in the desert, magenta in Neon City, red in the volcano, green in Matrix, and moonlight blue at night. **Colour strength** mixes that colour with white; 0% keeps the light white. Lights that cannot show colour only change brightness.

Lights that were off before the match are switched on for it and off again afterwards.

## Good to know

- **Zigbee.** The game sends only a few messages a minute, and the automation handles them one after another, so Zigbee lights keep up. A transition of about two seconds looks smooth on Hue bulbs.
- **Several clocks.** Each clock reports under its own prefix. Create one automation per clock.
- **HTTP login on the clock.** The game reads the clock's prefix from its local API. If you turned on the clock's HTTP login, it cannot, and reports under `dinorunner/` instead. Leave the prefix empty in the blueprint then. Only one clock with a login can use the lights this way.

## The messages

The game publishes JSON, only when something changes. `<prefix>` is the clock's MQTT prefix, or its uid when none is set.

`<prefix>/dinorunner/state`:

| Field | Values |
|---|---|
| `mode` | `menu`, `ready`, `countdown`, `run`, `tour`, `pause`, `results`, `off` |
| `room` | `game` from the countdown to the end of the match, otherwise `normal` |
| `enter`, `leave` | `true` on the message where `room` changes |
| `world` | 1–10 |
| `phase` | `day`, `night` in the five day worlds, `late` in the five night worlds |
| `dark` | `true` at night and in the worlds that are always dark |
| `color` | the world's light colour as `#RRGGBB` |
| `score` | the final score, with `results` |

`<prefix>/dinorunner/event` carries `{"event": "roar"}` when the dino hatches, `crash` when a run ends and `record` when the best score is beaten. The blueprint does not use them; they are there for your own automations.

The messages are not retained. Turn on **Debug logging** in the game's settings to see its topic in the clock's log.
