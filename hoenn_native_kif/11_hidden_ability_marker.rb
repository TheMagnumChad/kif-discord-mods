module HoennNativeKIFHiddenAbilityMarker
  def hno_ha_eligible?
    return false unless @pokemon && @pokemon.respond_to?(:hasHiddenAbility?)
    return false unless @pokemon.hasHiddenAbility?
    return false if @erased || !defined?($game_map) || !$game_map
    return false unless @map_id == $game_map.map_id
    return false unless $game_map.events[@id].equal?(self)
    true
  end

  def hno_ha_dispose
    if @hno_ha_marker
      begin
        bmp = @hno_ha_marker.bitmap
        @hno_ha_marker.dispose unless @hno_ha_marker.disposed?
        bmp.dispose if bmp && !bmp.disposed?
      rescue StandardError
      end
    end
    @hno_ha_marker = nil
    @hno_ha_phase = nil
    @hno_ha_period = nil
  end

  # Brief, occasional gold glint instead of a permanent label
  def hno_ha_create
    return unless defined?(Sprite) && defined?(Bitmap)
    sp = Sprite.new
    bmp = Bitmap.new(15, 15)
    gold = Color.new(255, 218, 99)
    pale = Color.new(255, 249, 197)
    # Small four-point sparkle, with a brighter centre
    bmp.fill_rect(7, 0, 1, 15, gold)
    bmp.fill_rect(0, 7, 15, 1, gold)
    bmp.fill_rect(5, 5, 5, 5, gold)
    bmp.fill_rect(6, 6, 3, 3, pale)
    sp.bitmap = bmp
    sp.ox = 7
    sp.oy = 7
    sp.z = 9998
    sp.visible = false
    @hno_ha_marker = sp
    # Randomized initial offset prevents a whole group flashing in unison
    rate = Graphics.frame_rate
    @hno_ha_period = [rate * 5, 1].max
    @hno_ha_phase = rand(@hno_ha_period)
  rescue StandardError => e
    sp.dispose if sp && !sp.disposed?
    bmp.dispose if bmp && !bmp.disposed?
    @hno_ha_marker = nil
    HoennNativeKIF.log("HA sparkle create: #{e.class}: #{e.message}") if defined?(HoennNativeKIF)
  end

  def update(*args)
    result = super
    if hno_ha_eligible?
      hno_ha_create unless @hno_ha_marker && !@hno_ha_marker.disposed?
      if @hno_ha_marker && !@hno_ha_marker.disposed?
        rate = Graphics.frame_rate
        duration = [(rate * 0.45).to_i, 1].max
        period = @hno_ha_period || [rate * 5, 1].max
        phase = (Graphics.frame_count + (@hno_ha_phase || 0)) % period
        active = phase < duration
        @hno_ha_marker.visible = active && !(@transparent || @opacity == 0)
        if active
          # A small pulse that fades in and out without obscuring the sprite
          progress = phase.to_f / duration
          strength = progress < 0.5 ? progress * 2 : (1.0 - progress) * 2
          @hno_ha_marker.opacity = (215 * strength).to_i
          @hno_ha_marker.zoom_x = 0.65 + 0.35 * strength
          @hno_ha_marker.zoom_y = @hno_ha_marker.zoom_x
          @hno_ha_marker.x = screen_x + 11
          @hno_ha_marker.y = screen_y - 37
        end
      end
    else
      hno_ha_dispose if @hno_ha_marker
    end
    result
  end

  def despawn(*args)
    hno_ha_dispose
    super
  end
end

OverworldPokemonEvent.prepend(HoennNativeKIFHiddenAbilityMarker)
