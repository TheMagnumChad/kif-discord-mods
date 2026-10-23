# KIF fix: the original set SAFARI_STEPS = 0 for good (constant redefined warning, and the
# "Infinite Safari" menu toggle did nothing). Now the toggle switches it between 0 (infinite)
# and the game's own value.
module XorronSafari
  GAME_STEPS = Settings::SAFARI_STEPS unless defined?(GAME_STEPS)

  def self.apply
    on = !defined?(XorronModSettings) || XorronModSettings.enabled?("infinite_safari_enabled")
    want = on ? 0 : GAME_STEPS
    return if Settings::SAFARI_STEPS == want
    Settings.send(:remove_const, :SAFARI_STEPS)
    Settings.const_set(:SAFARI_STEPS, want)
    # a game started while infinite has 0 steps left: give it the full count when switched off
    if want > 0 && $PokemonGlobal && pbSafariState.inProgress? && pbSafariState.steps <= 0
      pbSafariState.steps = want
    end
  end
end

XorronSafari.apply
