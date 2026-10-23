#===============================================================================
# ** Save Tags
#-------------------------------------------------------------------------------
# Adds the ability to add custom tags to save files (e.g., "Nuzlocke", "Challenge Run").
#
# KIF fix: this used to replace the whole load screen and the save screen with
# copies from PIF 6.4.5 (losing what 6.8.2 and KIF add there) and failed to
# load on KIF. It now wraps the game's own screens and only adds the tag.
# The tag is saved as a plain String; saves still load without this mod.
#===============================================================================
if defined?(ModSettingsMenu)
    ModSettingsMenu.register(:save_tag, {
                                         name: "Change Save Tag",
                                         type: :button,
                                         description: "Modify The Save Tag which is used for orginization",
                                         on_press: proc {
                                                         SaveTag.set_tag
                                                        },
                                         category: "Interface",
                                         searchable: ["tag" "save tag","orginization"]
                                        })

end


module SaveTag
    MAX_LENGTH = 20   # Maximum characters for a tag

    class << self
        attr_accessor :preview   # KIF fix: the tag of the save shown on the load menu
    end

    # Show a menu to enter a new save tag

    def self.set_tag
        current_tag =  $save_tag || ""
        new_tag = pbEnterText("Enter save tag:", 1, MAX_LENGTH)
        $save_tag = new_tag.strip.empty? ? nil : new_tag
        pbMessage("Save tag set to: #{$save_tag || 'None'}")
    end

    # KIF fix: only a non-empty String counts as a tag
    def self.text(value)
        return (value.is_a?(String) && !value.strip.empty?) ? value : nil
    end
end

# KIF fix: v19's SaveData has no "optional", and ensure_class :String would
# mark every save made before this mod as invalid (it has no tag); the value
# is checked when it loads instead.
SaveData.register(:save_tag) do
    save_value { $save_tag.is_a?(String) ? $save_tag : "" }
    load_value { |value|
                 $save_tag = value.is_a?(String) ? value : ""
               }
    new_game_value {""}
end

#===============================================================================
# ** Scene_File
#-------------------------------------------------------------------------------
# Show the save tag in the save/load screen
#===============================================================================
# KIF fix: hooks are prepended modules (KIF prepends some of these methods
# too, and an alias next to a prepend loops)
module SaveTag
    module SaveSceneHook
        def pbStartScreen(*args)
            ret = super
            tag = SaveTag.text($save_tag)
            win = @sprites && @sprites["locwindow"]
            if tag && win
                textColor = ["0070F8,78B8E8","E82010,F8A8B8","0070F8,78B8E8"][$Trainer.gender] rescue "0070F8,78B8E8"
                loctext = win.text.to_s
                loctext += "<br>" unless loctext.end_with?("<br>")
                loctext += _INTL("Tag<r><c3={1}>{2}</c3><br>", textColor, tag)
                newwin = Window_AdvancedTextPokemon.new(loctext)
                newwin.viewport = win.viewport
                newwin.x = win.x
                newwin.y = win.y
                newwin.width = 228 if newwin.width < 228
                newwin.visible = true
                win.dispose
                @sprites["locwindow"] = newwin
            end
            return ret
        end

    end

    module LoadScreenHook
        def load_save_file(*args)
            data = super
            SaveTag.preview = data.is_a?(Hash) ? SaveTag.text(data[:save_tag]) : nil
            return data
        end
    end

    # The tag goes after the slot name on the save panel ("File A - tag"), the
    # way the author showed it; nothing else on the panel moves
    module PanelHook
        def refresh(*args)
            redraw = @refreshBitmap && !@refreshing && !disposed?
            ret = super
            tag = SaveTag.preview
            return ret unless redraw && @isContinue && tag && self.bitmap && !self.bitmap.disposed?
            begin
                x = 16 * 2 + self.bitmap.text_size(@title.to_s).width
                if @trainer.respond_to?(:kif_nz_failed) && @trainer.kif_nz_failed
                    grave = Bitmap.new("Graphics/Icons/menuIcons/GRAVEYARD") rescue nil   # KIF Nuzlocke's mark sits there
                    x += 10 + (grave ? grave.width : 24)
                    grave.dispose if grave
                end
                pbDrawTextPositions(self.bitmap, [[" - " + tag, x, 2 * 2, 0,
                                                   PokemonLoadPanel::TEXTCOLOR, PokemonLoadPanel::TEXTSHADOWCOLOR]])
            rescue StandardError
            end
            return ret
        end
    end
end

PokemonSave_Scene.prepend(SaveTag::SaveSceneHook)
PokemonLoadScreen.prepend(SaveTag::LoadScreenHook)
PokemonLoadPanel.prepend(SaveTag::PanelHook)
