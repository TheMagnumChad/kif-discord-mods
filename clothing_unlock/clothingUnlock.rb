# Mod by Voidcat Cyr

# KIF fix: wraps PIF 6.8.2's own hat shop instead of replacing it with an
# older copy (that one read VAR_CURRENT_MART, so a shop could list another
# city's hats), and unlocks silently: 6.8.2's obtainHat / obtainNewClothes
# show a message and a "put it on?" question for every single outfit.
alias voidcat_clothingUnlock_pokemart_hat_shop pokemart_hat_shop
def pokemart_hat_shop(include_defaults = true)
  # KIF fix: the outfit lists are only read from the game's files when needed
  update_global_hats_list if !$PokemonGlobal.hats_data
  update_global_clothes_list if !$PokemonGlobal.clothes_data
  $Trainer.unlocked_hats ||= []
  $Trainer.unlocked_clothes ||= []
  # KIF fix: skips the game data's entries without an id (unlockHat can't take one)
  for i in 0...$PokemonGlobal.hats_data.keys.length() do
    unlockHat($PokemonGlobal.hats_data.keys[i]) if $PokemonGlobal.hats_data.keys[i]
  end
  for i in 0...$PokemonGlobal.clothes_data.keys.length() do
    unlockClothes($PokemonGlobal.clothes_data.keys[i]) if $PokemonGlobal.clothes_data.keys[i]
  end

  voidcat_clothingUnlock_pokemart_hat_shop(include_defaults)
end
