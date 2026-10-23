#===============================================================================
# Xorron's Graphic Overhaul 2.3 (Continuous Brightness Lock)
#===============================================================================
# KIF fix: in KIF, Graphics.frame_rate is the game's logic rate (KIF's FrameRate hook), so setting
# it to 60/90 ran the whole game 1.5x/2.25x fast. The option now sets the rate KIF draws the
# overworld at (KIF::FrameRate.apply), the same thing KIF's "Frame rate" setting does; the game
# keeps running 40 steps a second. "Off" goes back to KIF's own "Frame rate" setting.
# KIF fix: removed the "Performance Tweaks (NPC Speed)" part that raised every map event's move
# frequency to 4 every 2 seconds: it changed how the game's own NPCs and scripted events move
# (and stayed changed with the option off), and only made up for the sped-up logic rate.

module XorronGraphics
  def self.apply_fps(target)
    return if target <= 0

    # Framerate setzen
    if defined?(KIF::FrameRate) && KIF::FrameRate.respond_to?(:apply)
      KIF::FrameRate.apply(target) if KIF::FrameRate.target != target   # KIF fix: display rate
    elsif Graphics.frame_rate != target
      Graphics.frame_rate = target
    end

    # KONTINUIERLICHER HELLIGKEITS-LOCK
    # Wir erzwingen 255 in JEDEM Update-Zyklus, solange High-FPS aktiv ist
    Graphics.brightness = 255 if Graphics.respond_to?(:brightness)
  end

  def self.restore_classic
    if defined?(KIF::FrameRate) && KIF::FrameRate.respond_to?(:apply)
      # KIF fix: back to KIF's own Frame rate setting, once
      if @kif_applied != false
        KIF::FrameRate.apply if KIF::FrameRate.target != KIF::FrameRate.wanted
        @kif_applied = false
      end
      return
    end
    if Graphics.frame_rate > 40
      Graphics.frame_rate = 40
      Graphics.brightness = 255 if Graphics.respond_to?(:brightness)
      # Map-Tönung neu triggern
      if $game_screen
        $game_screen.start_tone_change($game_screen.tone, 1)
      end
    end
  end

  def self.mark_applied; @kif_applied = true; end
end

# Automatischer Sync
Events.onMapUpdate += proc { |_sender, e|
  if defined?(XorronModSettings)
    fps_mode = XorronModSettings.get("graphic_fps_mode") || 0
    if fps_mode == 1
      XorronGraphics.apply_fps(60); XorronGraphics.mark_applied
    elsif fps_mode == 2
      XorronGraphics.apply_fps(90); XorronGraphics.mark_applied
    else
      XorronGraphics.restore_classic
    end
  end
}
