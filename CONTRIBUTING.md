# Adding a mod

Mods in this repository show up in KIF under **Options > Mods > Browse**, and players get your updates automatically.

## 1. Lay out your mod

One folder per mod, at the top of the repository:

```
your_mod/
  mod.json
  main.rb
  Graphics/...   (optional: pictures and sounds, same paths as in the game)
```

`mod.json`:

```json
{
  "id": "your_mod",
  "name": "Your Mod",
  "version": "1.0.0",
  "author": "your name",
  "description": "One or two lines on what it does.",
  "scripts": ["main.rb"],
  "requires_kif": ">=1.1.0"
}
```

- **id:** lower case letters, numbers, `_` and `-`. It never changes once published; players' settings are kept under it.
- **version:** raise it with every update, or players won't be offered the update.
- **scripts:** the `.rb` files, in the order they load.

Optional fields:

| Field | Example | Meaning |
|---|---|---|
| `requires_kif` | `">=1.1.0, <2.0"` | KIF versions it works with |
| `dependencies` | `["other_mod"]` | mods it needs |
| `load_after` | `["other_mod"]` | load after these when they're installed |
| `incompatible` | `["other_mod"]` | mods it doesn't work with |
| `credits` | `["Sprites by ..."]` | anyone else to thank |

## 2. Open a pull request

1. Fork this repository (the **Fork** button at the top of the page).
2. Add your mod's folder to your fork (**Add file > Upload files** works; drag the folder in).
3. Open a pull request to this repository and fill in the form.

For an update, change the files in your folder and raise `version` in the same pull request.

## 3. The automatic check

Every pull request is checked within a minute or two. It fails when:

- `mod.json` is missing, isn't valid, or lacks `id`, `name`, `version`, `author` or `description`
- the `id` is already taken by another mod
- a script listed in `mod.json` is missing, or a `.rb` file doesn't compile
- the folder has programs or archives (`.exe`, `.dll`, `.bat`, `.zip`, ...): upload the files themselves
- a file is over 25 MB, or the mod over 100 MB

It also lists code the reviewer will read closely: starting programs, deleting files, network access, loading `Marshal` data, setting players' settings. These don't fail the check; say why your mod needs them in the pull request.

Fix what it reports by pushing to the same branch; the check runs again.

## 4. Review

A mod is Ruby code that runs with full access to the player's computer, so every pull request is read by a person before it's merged. Things that won't be merged:

- anything that harms the player's computer, collects data, or hides what it does
- code copied from someone else's mod without their permission and credit
- mods that break saves without saying so in the description

Questions: the KIF Discord, https://discord.gg/kuray-hub-1121345297352753243
