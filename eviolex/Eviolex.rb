#===============================================================================
# Eviolex.rb
# Adds the Eviolex, an offensive version of the Eviolite that boosts
# Attack and Sp. Atk of unevolved Pokemon by 50%.
#===============================================================================

#===============================================================================
# SECTION 1: Item Registration Method
#===============================================================================

def eviolex_register_items
  GameData::Item.register({
    :id          => :EVIOLEX,
    :id_number   => 693,
    :name        => "Eviolex",
    :name_plural => "Eviolexes",
    :pocket      => 1,
    :price       => 4000,
    :description => "Boosts the Attack and Sp. Atk of a Pokemon that can still evolve by 50%.",
    :field_use   => 0,
    :battle_use  => 0,
    :type        => 0,
    :move        => nil
  }) unless GameData::Item.exists?(:EVIOLEX)

  MessageTypes.set(MessageTypes::Items,            693, "Eviolex")
  MessageTypes.set(MessageTypes::ItemPlurals,      693, "Eviolexes")
  MessageTypes.set(MessageTypes::ItemDescriptions, 693, "Boosts the Attack and Sp. Atk of a Pokemon that can still evolve by 50%.")
end

#===============================================================================
# SECTION 2: Hook into GameData.load_all so item survives data reload
#===============================================================================

module GameData
  class << self
    alias eviolex_original_load_all load_all
    def load_all
      eviolex_original_load_all
      eviolex_register_items
      echoln "[Eviolex] Item registered after GameData.load_all"
    end
  end
end

# Also register immediately in case load_all already ran
eviolex_register_items

# KIF fix: sold in KIF's Kuray Shop next to the Eviolite, at the same price,
# so it can be obtained
if defined?(KIF::KurayShop::ITEMS) && !KIF::KurayShop::ITEMS.any? { |e| e[0] == :EVIOLEX }
  KIF::KurayShop::ITEMS << [:EVIOLEX, 4000, 2000]
end

#===============================================================================
# SECTION 3: Battle Effect
#===============================================================================

BattleHandlers::DamageCalcUserItem.add(:EVIOLEX,
  proc { |item, user, target, move, mults, baseDmg, type|
    if user.pokemon.species_data.get_evolutions(true).length > 0
      mults[:attack_multiplier] *= 1.5
    end
  }
)

#===============================================================================
# SECTION 4: Self-Contained Graphics
#===============================================================================

module GameData
  class Item
    class << self
      alias eviolex_original_icon_filename icon_filename
      def icon_filename(item)
        item_id = GameData::Item.try_get(item)&.id
        if item_id == :EVIOLEX
          # KIF fix: KIF finds Graphics/ files inside the mod's own folder
          return "Graphics/Items/EVIOLEX"
        end
        return eviolex_original_icon_filename(item)
      end

      alias eviolex_original_held_icon_filename held_icon_filename
      def held_icon_filename(item)
        item_id = GameData::Item.try_get(item)&.id
        if item_id == :EVIOLEX
          return "Graphics/HeldItems/EVIOLEX"
        end
        return eviolex_original_held_icon_filename(item)
      end
    end
  end
end