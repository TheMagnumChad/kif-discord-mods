module ShinySoulMod
  BASE_COLORS = {
    "Red" => 1,
    "Orange" => 2,
    "Yellow" => 3,
    "Green" => 4,
    "Teal" => 5,
    "Blue" => 6,
    "Purple" => 7,
    "Pink" => 8,
    "Cyan" => 9,
    "Brown" => 10,
    "Black" => 11,
    "White" => 12,
    "Grey" => 13
  }

  INTENSITIES = {
    "Light" => 1,
    "Mid" => 2,
    "Dark" => 3
  }

  ANIMATION_LENGTHS = {
    "Short" => 1,
    "Medium" => 2,
    "Long" => 3
  }

  @enabled = true # Default: Shiny animations enabled
  @selected_base_color = 1 # Default: Red
  @selected_intensity = 2 # Default: Mid
  @selected_animation_length = 2 # Default: Medium

  class << self
    attr_accessor :enabled, :selected_base_color, :selected_intensity, :selected_animation_length
  end

  # KIF fix: the choices are kept in KIF's mod settings file (all saves), so
  # they survive closing the game
  SETTINGS_KEY = :shiny_soul_settings

  def self.load_settings
    return if !defined?(ModSettingsMenu)
    saved = ModSettingsMenu.get(SETTINGS_KEY)
    return if !saved.is_a?(Hash)
    @enabled = saved[:enabled] if [true, false].include?(saved[:enabled])
    @selected_base_color = saved[:color] if BASE_COLORS.values.include?(saved[:color])
    @selected_intensity = saved[:intensity] if INTENSITIES.values.include?(saved[:intensity])
    @selected_animation_length = saved[:length] if ANIMATION_LENGTHS.values.include?(saved[:length])
  end

  def self.save_settings
    return if !defined?(ModSettingsMenu)
    ModSettingsMenu.set(SETTINGS_KEY, { :enabled => @enabled, :color => @selected_base_color,
                                        :intensity => @selected_intensity, :length => @selected_animation_length })
  end

  def self.open_menu
    loop do
      # Refresh the commands each time the menu is displayed
      commands = [
        _INTL("Shiny Animations: #{enabled ? 'ON' : 'OFF'}"),
        _INTL("Select Base Color (#{selected_base_color_label})"),
        _INTL("Select Intensity (#{selected_intensity_label})"),
        _INTL("Select Animation Length (#{selected_animation_length_label})"),
        _INTL("Cancel")
      ]

      choice = pbMessage(_INTL("Shiny Soul Mod Options:"), commands, -1)
      case choice
      when 0
        # Toggle shiny animations on/off
        @enabled = !@enabled
        pbMessage(_INTL("Shiny animations are now #{enabled ? 'enabled' : 'disabled'}."))

      when 1
        # Open the base color selection menu
        select_base_color

      when 2
        # Open the intensity selection menu
        select_intensity

      when 3
        # Open the animation length selection menu
        select_animation_length

      else
        break
      end
    end
    save_settings
  end

  def self.select_base_color
    # Create a list of base color names
    commands = BASE_COLORS.keys.map { |name| _INTL(name) }
    commands << _INTL("Cancel") # Add a cancel option at the end

    # Display the menu and get the player's choice
    choice = pbMessage(_INTL("Select a base color:"), commands, -1)
    if choice >= 0 && choice < BASE_COLORS.keys.size
      # Update the selected base color based on the player's choice
      @selected_base_color = BASE_COLORS.values[choice]
      pbMessage(_INTL("Selected base color: {1}.", commands[choice]))
    else
      pbMessage(_INTL("No base color selected."))
    end
  end

  def self.select_intensity
    # Create a list of intensity names
    commands = INTENSITIES.keys.map { |name| _INTL(name) }
    commands << _INTL("Cancel") # Add a cancel option at the end

    # Display the menu and get the player's choice
    choice = pbMessage(_INTL("Select an intensity:"), commands, -1)
    if choice >= 0 && choice < INTENSITIES.keys.size
      # Update the selected intensity based on the player's choice
      @selected_intensity = INTENSITIES.values[choice]
      pbMessage(_INTL("Selected intensity: {1}.", commands[choice]))
    else
      pbMessage(_INTL("No intensity selected."))
    end
  end

  def self.select_animation_length
    # Create a list of animation length options
    commands = ANIMATION_LENGTHS.keys.map { |name| _INTL(name) }
    commands << _INTL("Cancel") # Add a cancel option at the end

    # Display the menu and get the player's choice
    choice = pbMessage(_INTL("Select an animation length:"), commands, -1)
    if choice >= 0 && choice < ANIMATION_LENGTHS.keys.size
      # Update the selected animation length based on the player's choice
      @selected_animation_length = ANIMATION_LENGTHS.values[choice]
      pbMessage(_INTL("Selected animation length: {1}.", commands[choice]))
    else
      pbMessage(_INTL("No animation length selected."))
    end
  end

  def self.selected_base_color_label
    BASE_COLORS.key(@selected_base_color) || "Red"
  end

  def self.selected_intensity_label
    INTENSITIES.key(@selected_intensity) || "Mid"
  end

  def self.selected_animation_length_label
    ANIMATION_LENGTHS.key(@selected_animation_length) || "Medium"
  end
end

ShinySoulMod.load_settings

# KIF fix: PIF 6.8.2's options screens never show rows added to the base
# PokemonOption_Scene, so the menu is opened from Options > KIF Settings > Mods
if defined?(ModSettingsMenu)
  ModSettingsMenu.register(:shiny_soul_menu, {
    :name => "Shiny Soul Options",
    :type => :button,
    :description => "Colour, intensity and length of your shinies' flash",
    :on_press => proc { ShinySoulMod.open_menu },
    :category => "Interface"
  })
end

# Add Shiny Soul Mod to the options menu
class PokemonOption_Scene
  alias shinysoulmod_pbGetOptions pbGetOptions
  def pbGetOptions(inloadscreen = false)
    options = shinysoulmod_pbGetOptions(inloadscreen)
    options << ButtonOption.new(_INTL("Shiny Soul Options"), proc { ShinySoulMod.open_menu })
    options
  end
end

# Override shiny animation logic in PokeBattle_Scene
class PokeBattle_Scene
  alias shiny_soul_pbCommonAnimation pbCommonAnimation

  def pbCommonAnimation(animName, user = nil, target = nil)
    # KIF fix: no flash when KIF's shiny animation is set to Off
    kif_anim_off = $PokemonSystem && $PokemonSystem.respond_to?(:kurayshinyanim) && $PokemonSystem.kurayshinyanim == 1
    if animName == "Shiny" && ShinySoulMod.enabled && user && !kif_anim_off
      # Only apply the effect to the player's Pokémon
      if user.index.even? # Player's Pokémon have even indices
        playColorAnimation(user, ShinySoulMod.selected_base_color, ShinySoulMod.selected_intensity, ShinySoulMod.selected_animation_length)
      end
    end
    shiny_soul_pbCommonAnimation(animName, user, target)
  end

  # Generalized animation for color-based effects
  def playColorAnimation(battler, base_color_id, intensity_id, animation_length_id)
    sprite = @sprites["pokemon_#{battler.index}"]
    return if !sprite

    # Define color effects based on the selected base color and intensity
    color_effects = {
      1 => { 1 => Color.new(255, 102, 102, 128), 2 => Color.new(255, 0, 0, 128), 3 => Color.new(153, 0, 0, 128) }, # Red
      2 => { 1 => Color.new(255, 200, 102, 128), 2 => Color.new(255, 165, 0, 128), 3 => Color.new(204, 102, 0, 128) }, # Orange
      3 => { 1 => Color.new(255, 255, 153, 128), 2 => Color.new(255, 255, 0, 128), 3 => Color.new(204, 204, 0, 128) }, # Yellow
      4 => { 1 => Color.new(102, 255, 102, 128), 2 => Color.new(0, 255, 0, 128), 3 => Color.new(0, 153, 0, 128) }, # Green
      5 => { 1 => Color.new(153, 255, 255, 128), 2 => Color.new(0, 255, 255, 128), 3 => Color.new(0, 153, 153, 128) }, # Teal
      6 => { 1 => Color.new(102, 102, 255, 128), 2 => Color.new(0, 0, 255, 128), 3 => Color.new(0, 0, 153, 128) }, # Blue
      7 => { 1 => Color.new(204, 153, 255, 128), 2 => Color.new(128, 0, 128, 128), 3 => Color.new(76, 0, 153, 128) }, # Purple
      8 => { 1 => Color.new(255, 182, 193, 128), 2 => Color.new(255, 105, 180, 128), 3 => Color.new(219, 112, 147, 128) }, # Pink
      9 => { 1 => Color.new(173, 216, 230, 128), 2 => Color.new(0, 255, 255, 128), 3 => Color.new(0, 139, 139, 128) }, # Cyan
      10 => { 1 => Color.new(210, 180, 140, 128), 2 => Color.new(139, 69, 19, 128), 3 => Color.new(101, 67, 33, 128) }, # Brown
      11 => { 1 => Color.new(64, 64, 64, 128), 2 => Color.new(32, 32, 32, 128), 3 => Color.new(16, 16, 16, 128) }, # Black
      12 => { 1 => Color.new(255, 255, 255, 128), 2 => Color.new(224, 224, 224, 128), 3 => Color.new(192, 192, 192, 128) }, # White
      13 => { 1 => Color.new(200, 200, 200, 128), 2 => Color.new(128, 128, 128, 128), 3 => Color.new(64, 64, 64, 128) } # Grey
    }

    # Get the selected color effect
    selected_color = color_effects[base_color_id][intensity_id]
    return if !selected_color

    pbSEPlay("Anim/Power2") # Play a sound effect

    # Determine the number of flashes based on animation length
    flashes = case animation_length_id
              when 1 then 2 # Short
              when 2 then 4 # Medium
              when 3 then 6 # Long
              else 4 # Default to Medium
              end

    # Perform multiple flashes with the selected color
    flashes.times do
      pbFlashSprite(sprite, selected_color, 5) # Flash with the selected color
      sprite.zoom_x += 0.1
      sprite.zoom_y += 0.1
      Graphics.update
      sprite.zoom_x -= 0.1
      sprite.zoom_y -= 0.1
    end
  end

  # Helper method to flash a sprite with a color overlay
  def pbFlashSprite(sprite, color, frames)
    return if !sprite || !sprite.bitmap
    original_tone = sprite.tone.clone
    sprite.tone = Tone.new(color.red, color.green, color.blue)
    frames.times do
      sprite.update
      Graphics.update
    end
    sprite.tone = original_tone
  end
end