# Cosmic Detention — UI & Visual Design Guide

This document defines the settled visual language, layout hierarchy, typography, iconography, and scene-authoring conventions for **Cosmic Detention**'s spaceship/visor HUD and menus. All coding agents and developers modifying UI scenes or scripts must follow these specifications.

---

## 1. Core Design Philosophy

- **Spaceship Cockpit / Holographic Visor Aesthetic**: The UI is styled like a sleek, modern sci-fi helmet display with crisp cyan borders, dark translucent navy backing panels, subtle corner radii (`3px–4px`), and soft cyan outer glow shadows.
- **Uncluttered Viewport**: Keep the active gameplay HUD minimal. Do not place heavy telemetry bays on the top, left, right, or bottom edges of the screen during gameplay. Detailed session telemetry (student name, phase/grade/timer, join code, progression counters, and held-item actuator readout) lives in the **Pause / Status Menu (`[ESC]`)**, not on the live HUD.
- **Scene-First Godot Authoring**: All UI nodes, containers, anchors, `StyleBoxFlat` resources, shader materials, and themes must be authored in `.tscn` and `.tres` files so they are directly inspectable and editable in the Godot Scene and Inspector docks. Never construct UI hierarchies or styleboxes procedurally in `.gd` scripts.

---

## 2. Typography & Input Naming Conventions

### Global Font (`Jersey 25`)
- **Font File**: `res://fonts/Jersey_25/Jersey25-Regular.ttf`
- **Project-Wide Default**: Set in `cssa-game-jam/project.godot` under `[gui]` (`theme/custom_font="res://fonts/Jersey_25/Jersey25-Regular.ttf"`).
- **Theme & Scene Usage**:
  - Assigned as `default_font` in `res://ui/menu_theme.tres`.
  - Applied explicitly to standalone UI scenes (`ui/event_feed.tscn`, `ui/vending_entry.tscn`) and 3D world labels (`world/classroom/props/transfer_chute.tscn`).
  - Always use **Jersey 25** for any new `Label`, `RichTextLabel`, `Button`, `LineEdit`, or `Label3D`.
- **Text Outlines**: To maintain readability against bright or moving 3D backgrounds, HUD and menu labels use dark navy outlines (`font_outline_color = Color(0, 0.08, 0.16, 0.95)`, `outline_size = 3` or `4`).

### Input Prompts & Control Copy
- **Mouse Buttons**: Always refer to mouse actions as **`Left-click`** and **`Right-click`** (never `LMB` or `RMB`).
- **Bracketed Key Hints**: Format keybind hints consistently with square brackets, e.g. `[ESC]`, `[H]`, `[E]`, `[SPACE]`, `[Left-click]`, `[Right-click]`.

---

## 3. Color Palette, Borders & Glow Specifications

### Color Tokens

| Role | Color Value | Usage |
|---|---|---|
| **HUD Bay Background** | `Color(0.008, 0.027, 0.059, 0.45–0.55)` | Translucent dark navy fill for HUD bays, banner, and console sub-panels |
| **Menu / Modal Background** | `Color(0.008, 0.027, 0.059, 0.88)` | High-contrast translucent dark navy fill for Main Menu, Pause Menu, and Vending |
| **Primary Cyan Border** | `Color(0.18, 0.92, 1.0, 0.9)` | Crisp `2px` border on HUD bays, menus, buttons, and gauges |
| **Hover / Focus Cyan Border** | `Color(0.45, 0.98, 1.0, 1.0)` | Highlighted border on hovered/focused buttons and inputs |
| **Outer Cyan Glow (HUD)** | `Color(0.0, 0.8, 1.0, 0.16–0.22)` | `shadow_size = 8–12` on HUD panels and buttons |
| **Outer Cyan Glow (Menus)** | `Color(0.0, 0.85, 1.0, 0.35)` | `shadow_size = 18` on `MenuBoxStyle` (`res://ui/menu_theme.tres`) |
| **Primary Heading Cyan** | `Color(0.35, 0.95, 1.0, 1.0)` | Titles (`COSMIC DETENTION`, `CLASS IS STILL RUNNING`, `INCIDENT FEED`) |
| **Body / Readout Ice White** | `Color(0.88, 0.98, 1.0, 1.0)` | Primary readout text, currency numbers, and banners |
| **Prompt Amber** | `Color(1.0, 0.88, 0.42, 1.0)` | Center-screen contextual interaction prompt (`%Prompt`) |
| **Stomach Gauge Fill** | `Color(0.0, 0.92, 0.78, 0.95)` | Vertical Stomach bar fill with bright top highlight `Color(0.6, 1.0, 0.95, 1.0)` |
| **Gas Gauge Fill** | `Color(0.55, 0.95, 0.2, 0.92)` | Vertical Gas bar fill with bright top highlight `Color(0.85, 1.0, 0.55, 1.0)` |

### Reusable Menu Theme (`res://ui/menu_theme.tres`)
Assigned to `Root` in `ui/game_ui.tscn` so all menu panels (`Root/Menu`, `Root/Pause`, `Root/Vending`), buttons, and text fields share one consistent look:
- **`PanelContainer/styles/panel` (`MenuBoxStyle`)**:
  - `2px` cyan border (`Color(0.18, 0.92, 1, 0.9)`), `4px` corner radius on all corners, `24px` horizontal / `20px` vertical content margins, dark translucent navy background (`alpha = 0.88`), and `shadow_size = 18` glowing cyan shadow.
- **`Button` states (`normal`, `hover`, `pressed`, `disabled`, `focus`)**:
  - `2px` cyan border, `3px` corner radius, glowing cyan shadow (`shadow_size = 8–12`), and progressive background illumination on hover/press.
- **`LineEdit` states (`normal`, `focus`)**:
  - Framed dark navy input boxes (`2px` cyan border, `3px` corner radius) that brighten on focus.

---

## 4. Iconography & Currency Representation

### Currency Icon (`res://assets/ui/bitcoin.png`)
- **Rule**: Never display the Unicode Bitcoin text character (`₿`) directly to the user in any UI label, button, banner, scoreboard, event feed, or 3D sign. Always render `res://assets/ui/bitcoin.png` instead:
  - **HUD Top-Left (`CurrencyBay`)**: `TextureRect` (`28x28`, `expand_mode = 1`, `stretch_mode = 5`) next to `%Stats`.
  - **Vending Header (`Root/Vending/Content/Header`)**: `BalanceLabel` (`"Balance"`) + `BitcoinIcon` (`TextureRect`, `26x26`) + `%VendingBalance` (`"%d" % balance`).
  - **Vending Item Cards (`ui/vending_entry.tscn`)**: Scene-authored `Footer` (`VBoxContainer`) containing `NameLabel` and `PriceRow` (`BitcoinIcon` `TextureRect` + `PriceLabel`).
  - **RichTextLabel Readouts (`%Scoreboard`, `%Banner`, `EventFeed/Content/Entries`)**: Render inline icons via BBCode `[img=WxH]res://assets/ui/bitcoin.png[/img]`. Always escape `[` as `[lb]` on dynamic/player strings before substituting `₿` with the `[img]` tag so player names cannot inject BBCode.
  - **3D Transfer Chute Sign (`world/classroom/props/transfer_chute.tscn`)**: Uses a child `Sprite3D` (`BitcoinIcon`) with `res://assets/ui/bitcoin.png` positioned in front of the cloning fee number on the `Label3D` sign.

### Meter Icons (`chicken.png` & `gas.png`)
- **Files**:
  - Stomach icon: `res://assets/ui/chicken.png`
  - Gas icon: `res://assets/ui/gas.png`
- **Styling**: Both icons are recolored to the same HUD cyan (`#47F2FF`, `RGB(71, 242, 255)`) while preserving their original alpha channels, and displayed at `24x24` directly beneath their respective vertical gauges without text labels.

---

## 5. HUD Layout & Component Specifications (`ui/game_ui.tscn`)

All live gameplay HUD nodes reside under `Root/HUD`:

1. **Top-Left — Currency Bay & Pause Hint**:
   - `CurrencyBay` (`PanelContainer` at `offset = (20, 18, 136, 66)`): Uses `HudBayLeft` (`2px` cyan border, `3px` corner radius, `10px` cyan glow). Contains `BitcoinIcon` (`28x28`) and `%Stats` (`font_size = 24`, numeric balance only).
   - `PauseHint` (`Label` at `offset = (22, 72, 180, 94)`): Displays `[ESC] Pause / Status` (`font_size = 16`, `Color(0.45, 0.95, 1, 0.9)`) directly below `CurrencyBay` so players always know how to view session status and controls.

2. **Top-Center — Rocket Assembly Schematic Tracker (`RocketTracker`)**:
   - `RocketTracker` (`PanelContainer` anchored top-center at `offset = (-140, 18, 140, 84)`): Styled with `HudBayLeft` (`2px` cyan border, `3px` corner radius, `10px` cyan glow).
   - Contains `Content` (`VBoxContainer`) with a centered `Title` label (`"Rocket Progress"`, `font_size = 15`, `Color(0.35, 0.95, 1, 1)`) above `Schematic` (`Control`, `246x30`) with three horizontal rocket stage silhouette nodes (`%RocketStage1` for `"rocket"` First Stage booster, `%RocketStage2` for `"rocket_second_stage"` Second Stage, and `%RocketStage3` for `"rocket_fairing"` Payload Fairing nosecone), each built from a scene-authored `Fill` (`Polygon2D`) and `Outline` (`Line2D`).
   - **Unbuilt State**: Hollow translucent blueprint interior (`Fill.color = Color(0.01, 0.05, 0.1, 0.25)`) with a crisp cyan outline (`Outline.default_color = Color(0.18, 0.92, 1.0, 0.45)`).
   - **Built State**: Solid glowing cyan interior (`Fill.color = Color(0.18, 0.95, 1.0, 0.85)`) with a bright ice-cyan outline (`Outline.default_color = Color(0.78, 1.0, 1.0, 1.0)`) as each corresponding Falcon 9 stage is installed on the launch pad.

3. **Top-Right — Compact Announcement Banner (`%Banner`)**:
   - `RichTextLabel` anchored top-right (`offset = (-360, 18, -20, 66)`), styled with `BannerStyle` (`2px` cyan border, `3px` corner radius, translucent dark navy fill).
   - Right-aligned (`[right]...[/right]`, `normal_font_size = 16`), unobtrusive, and automatically converts `₿` into an inline `16x16` `bitcoin.png` icon.

3. **Bottom-Left — Narrow Vertical Stomach & Gas Gauges**:
   - **No text labels** (`"Stomach"`, `"Gas"`, or percentage readouts are omitted).
   - `%Stomach` (`ProgressBar`): Anchored bottom-left (`offset = (26, -224, 44, -52)` — `18px` wide, `172px` tall), vertical bottom-to-top fill (`fill_mode = 3`, `show_percentage = false`).
   - `StomachIcon` (`TextureRect` at `offset = (23, -44, 47, -20)`): `24x24` cyan `chicken.png` centered below `%Stomach`.
   - `%Gas` (`ProgressBar`): Positioned next to `%Stomach` (`offset = (60, -224, 78, -52)` — `18px` wide, `172px` tall), vertical bottom-to-top fill (`fill_mode = 3`, `show_percentage = false`).
   - `GasIcon` (`TextureRect` at `offset = (57, -44, 81, -20)`): `24x24` cyan `gas.png` centered below `%Gas`.

4. **Center — Reticle, Crosshair & Semicircular Throw Charge**:
   - `ReticleRing` (`Panel` centered at `offset = (-46, -46, 46, 46)`): `92x92` subtle circular visor ring (`1px` cyan border `Color(0.2, 0.9, 1, 0.22)`, `46px` corner radius). Do not alter the reticle ring or `Crosshair` (`⌖`) geometry when adjusting throw-charge visuals.
   - `%ThrowCharge` (`ProgressBar` centered at `offset = (-62, 63, 62, 187)`, `rotation = -1.5707964`):
     - Uses `CircularChargeShader` (`CircularChargeMat`) to render a thin (`~2px` wide, `r` between `0.88` and `0.925` in UV space) **semicircle arc around the bottom-left side of `ReticleRing`** with clear spacing outside the `46px`-radius reticle ring.
     - Fills in a **counterclockwise motion** from top-left (`135°` screen angle) through bottom-left (`225°`) to bottom-right (`315°`) as `progress` increases from `0.0` to `1.0`.
     - **Important Godot `ProgressBar` Shader Rule**: `theme_override_styles/fill` MUST be set to `StyleBoxEmpty` (`SubResource("ChargeEmpty")`), and only `theme_override_styles/background` should use a solid `StyleBoxFlat`. Otherwise, Godot's `ProgressBar` draws both `background` and `fill` styleboxes with the same `CanvasItem` shader material, causing a duplicate second circle to appear and grow as charge increases.

5. **Bottom-Right — Compact Incident Feed (`ui/event_feed.tscn`)**:
   - Instance of `res://ui/event_feed.tscn` anchored bottom-right (`offset = (-310, -148, -20, -20)` — `290x128`).
   - Styled with a `2px` cyan border, `3px` corner radius, and low-opacity dark navy background.
   - Contains `Title` (`INCIDENT FEED`, `font_size = 12`), `Entries` (`RichTextLabel`, `normal_font_size = 13`, `bbcode_enabled = true`), and a top-right `ToggleTip` (`[H] Hide` / `[H] Event Feed`, `font_size = 11`).
   - Pressing **`H`** toggles the feed between expanded and a compact `[H] Event Feed` pill in the bottom-right corner.
   - Note: In `event_feed.tscn`, the root `EventFeed` node uses `anchors_preset = 3` (bottom-right). In the Godot editor, opening `game_ui.tscn` shows `EventFeed` properly in the bottom-right because `Root/HUD` provides a full-screen parent rect.

---

## 6. Menus & Overlays (`ui/game_ui.tscn`)

### Main Menu (`Root/Menu`)
- Centered `PanelContainer` (`660x610`, `offset = (-330, -305, 330, 305)`) inheriting `MenuBoxStyle` from `res://ui/menu_theme.tres` (with glowing `shadow_size = 18` cyan shadow).
- Contains:
  - `Title` (`COSMIC DETENTION`, `font_size = 44`, cyan with dark outline) and `Subtitle` (`Eat. Survive. Frame your friends.`, `font_size = 22`).
  - `NameField`, `AddressField`, `Host`, `LANRow` (`FindLAN`, `LANGames`, `JoinLAN`), `JoinRow` (`CodeField`, `Join`), `MenuStatus`.
  - Framed `Controls` help box (`SubResource("HudBottomConsole")`, `line_spacing = 4`, `font_size = 17`) organized by action category:
    ```text
    [WASD] Move   •   [Shift] Sprint   •   [Space] Jump / Stand / Escape
    [E] Grab / Sit / Interact   •   [Q] Drop   •   [F] Vent Gas
    [Left-click] Punch / Hold to Throw   •   [Right-click] Eat / Use
    [Tab] Class Register   •   [H] Incident Feed   •   [Esc] Pause Menu
    ```
  - `Quit` button.

### Pause / Status Menu (`Root/Pause`)
- Centered `PanelContainer` (`540x450`, `offset = (-270, -225, 270, 225)`) inheriting `MenuBoxStyle` and button styles from `res://ui/menu_theme.tres`.
- Houses session telemetry and held-item status that were removed from the live HUD:
  - `Title`: `CLASS IS STILL RUNNING` (`font_size = 28`).
  - `%PhaseLabel`: Displays student name, current phase, grade, countdown timer, LAN join code, classes survived, and rocket parts (`STUDENT: <name>\n<PHASE> • GRADE <n> • <MM:SS>\nJOIN <code> • <n> classes / <n> parts`).
  - `BottomConsoleBay` (`PanelContainer` with `HudBottomConsole`): Contains `BayHeader` (`◈ MANIPULATOR BAY // KINETIC ACTUATOR ◈`) and `%HeldLabel` (current held item or empty-hand actions using `Left-click` / `Right-click`).
  - Action buttons: `RESUME`, `COPY JOIN CODE`, `QUIT TO MAIN MENU`.
