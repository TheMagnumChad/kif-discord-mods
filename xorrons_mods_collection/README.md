# Xorron's Mods Collection v1.1- Kuray Infinite Fusion Edition

This collection features a comprehensive set of enhancements and optimizations for the Kuray Infinite Fusion Engine (KIF), designed to deliver a more vibrant, stable, and immersive gameplay experience.

---

## 🛠 Main Modules

### 1. Xorron Mod Menu (`000_Xorron_Mod_Menu.rb`)
The central control hub for all installed mods.
- **Features:** Toggle mods, adjust limits, control FPS settings, and configure follower formations.
- **New:** Integrated real-time synchronization (settings take effect immediately without map reloads).

### 2. Xorron's PokePetSystem (`Xorrons_PokePetSystem.rb`)
Allows you to have up to 6 Pokémon as active followers simultaneously.
- **Bodyguard Formation:** Starting with 3 Pokémon, they form a tactical V-formation. Follower 1 trails the player, while the rest secure the flanks and rear.
- **Real-time Sync:** Instantly detects party healing, swaps, or evolutions, updating followers on the map immediately.
- **Gen 9 Support:** Features an intelligent costume system for Pokémon lacking native overworld sprites.

### 3. Wandering Trainers Mod (`Wandering_Trainers_Mod.rb`)
Breathes life into the world with trainers roaming the maps alongside their own Pokémon.
- **Multi-Battles:** Support for Duo or Trio group battles with optimized engine stability to prevent UI freezes.
- **Dynamic AI:** Trainers react to player proximity with unique animations and farewell messages.

### 4. Xorron's Shiny Sprite Fix (`Xorrons_Shiny_Sprite_Fix.rb`)
Ensures accurate and bug-free shiny representation in the overworld.
- **Individual Cloning:** Every shiny individual receives a unique bitmap copy in memory. This prevents color bleeding onto normal Pokémon of the same species.
- **Strict Detection:** Specialized logic for fusions that ignores inherited background values, triggering only for confirmed shinies.

---

## 🌟 Special Features

- **Gen 9 Costume System:** Since Generation 9 lacks overworld sprites, these Pokémon receive deterministic "costumes" (fallback sprites from Gen 1-7). These costumes are correctly recolored if the Pokémon is shiny.
- **Advanced Facing Logic:** Followers 2 through 6 always look in the player's movement direction to secure the perimeter, while only the lead follower looks directly at the player.
- **Graphic Overhaul:** FPS unlocker (60/90 FPS) with a continuous brightness lock for smoother gameplay.

---

## 📦 Additional Mods in the Collection

- **Infinite Safari:** Removes the step limit in the Safari Zone.
- **Kuray Auto-Capture:** Automates Pokémon catching (with an optional 100% success rate).
- **Map Progress:** Tracks and visualizes exploration progress on world maps.

---

**Built for stability, aesthetics, and fun.**
*Note: All modifications are modular and do not alter the game's original core data files.*
