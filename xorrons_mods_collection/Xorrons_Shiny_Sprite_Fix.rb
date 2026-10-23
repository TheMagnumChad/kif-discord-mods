#==============================================================================
# Xorron's Shiny Sprite Fix 1.3.1 (Non-Shiny Fix)
#==============================================================================
# Schaltet die offizielle Kuray-Shiny-Umfärbung für die Weltkarte frei.
# Korrektur: Normale Pokémon werden nicht mehr fälschlicherweise gefärbt.
#==============================================================================
# KIF fix: the original called Bitmap#pbGiveFinaleColor, which 6.8.2 doesn't have (nothing was
# recoloured), and cloned a bitmap for every shiny without ever freeing it. Now:
#  - a "Followers/X" sprite switches to the game's own shiny sheet "Followers/Shiny/X";
#  - any other sprite (costumes) gets one recoloured copy, made with the game's shiny hue
#    (GameData::Species.calculateShinyHueOffset), freed when the sprite changes or is disposed.

class Sprite_Character < RPG::Sprite
  alias xorron_shiny_fix_update_v131 update unless method_defined?(:xorron_shiny_fix_update_v131)
  alias xorron_shiny_fix_dispose_v131 dispose unless method_defined?(:xorron_shiny_fix_dispose_v131)

  XORRON_SHINY_SHEETS = {}

  def update
    xorron_shiny_fix_update_v131 rescue super
    return if !@character || disposed?

    pkmn = @character.instance_variable_get(:@xorron_pkmn_ref) rescue nil

    # Prüfe ob das PKMN wirklich ein Shiny ist
    if pkmn && xorron_is_actually_shiny_v131?(pkmn)
      name = @character.character_name.to_s
      if name.start_with?("Followers/") && !name.start_with?("Followers/Shiny/")
        shiny = "Followers/Shiny/" + name.sub("Followers/", "")
        XORRON_SHINY_SHEETS[shiny] = !!pbResolveBitmap("Graphics/Characters/" + shiny) if !XORRON_SHINY_SHEETS.has_key?(shiny)
        if XORRON_SHINY_SHEETS[shiny]
          @character.character_name = shiny   # drawn from the next frame on
          return
        end
      end
      return if name.start_with?("Followers/Shiny/")
      xorron_recolour_v131(pkmn)
    elsif @xorron_shiny_copy
      xorron_free_copy_v131
    end
  end

  def dispose
    xorron_free_copy_v131
    xorron_shiny_fix_dispose_v131
  end

  # One recoloured copy of the current sheet, remade only when the sheet changes
  def xorron_recolour_v131(pkmn)
    src = (@charbitmap && @charbitmap.respond_to?(:bitmap)) ? @charbitmap.bitmap : nil
    return if !src || src.disposed? || self.bitmap != src && self.bitmap != @xorron_shiny_copy
    if !@xorron_shiny_copy || @xorron_shiny_src != src
      xorron_free_copy_v131
      offset = apply_true_shiny_colors_v131(pkmn)
      return if !offset || offset == 0
      @xorron_shiny_copy = src.clone
      @xorron_shiny_copy.hue_change(offset)
      @xorron_shiny_src = src
    end
    self.bitmap = @xorron_shiny_copy
  end

  def xorron_free_copy_v131
    if @xorron_shiny_copy
      self.bitmap = @xorron_shiny_src if self.bitmap == @xorron_shiny_copy && @xorron_shiny_src && !@xorron_shiny_src.disposed?
      @xorron_shiny_copy.dispose if !@xorron_shiny_copy.disposed?
    end
    @xorron_shiny_copy = nil
    @xorron_shiny_src = nil
  end

def xorron_is_actually_shiny_v131?(pkmn)
  return false if !pkmn
  # 1. Absolut strikte Prüfung auf das offizielle Shiny-Flag
  # Wir prüfen @shiny Instanzvariable direkt, um Engine-Übersteuerungen zu umgehen
  is_shiny = pkmn.instance_variable_get(:@shiny)
  return true if is_shiny == true

  # 2. Prüfung auf Fake-Shinies (Events)
  return true if pkmn.respond_to?(:fakeshiny?) && pkmn.fakeshiny?

  # 3. Fusion Shinies (Nur wenn einer der Teile EXPLIZIT shiny ist)
  if pkmn.respond_to?(:shinyOmega?)
    omega = pkmn.shinyOmega?
    if omega && omega.is_a?(Hash)
      # Wir ignorieren pif_shiny, da es bei fast jedem PKMN gesetzt ist
      # Wir prüfen nur body und head auf echte Shiny-Werte (> 0 und nicht nil)
      b_shiny = omega["body_shiny"]
      h_shiny = omega["head_shiny"]
      return true if b_shiny && (b_shiny == true || b_shiny.to_i > 0)
      return true if h_shiny && (h_shiny == true || h_shiny.to_i > 0)
    end
  end
  return false
end

# KIF fix: returns the game's shiny hue for this Pokemon (was: pbGiveFinaleColor, not in 6.8.2)
def apply_true_shiny_colors_v131(pkmn)
  begin
    fusion = (pkmn.isFusion? rescue false)
    body = fusion ? !!pkmn.bodyShiny? : true
    head = fusion ? !!pkmn.headShiny? : true
    body = head = true if fusion && !body && !head
    return GameData::Species.calculateShinyHueOffset(pkmn.species_data.id_number, body, head)
  rescue
    return nil
  end
end
end
