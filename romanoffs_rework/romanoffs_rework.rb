#===============================================================================
# Romanoff's Rework
# A rebalance of 156 Pokemon: types, base stats, EV yields, abilities and some
# moves.
#
# KIF fix: the original file re-registered every species from 2024 data
# ("All Pokemons default data", KIF 0.19.8), which also put that old data back
# on the 400+ species Romanoff never changed. This version keeps only
# Romanoff's own changes and applies them on top of the game's data each time
# it loads. Tutor moves list what he added and removed. The KURAY_* triples
# are not in KIF 1.x and are left out.
#===============================================================================
module RomanoffRework
  CHANGES = {
    :BULBASAUR => {:abilities=>[:OVERGROW, :EFFECTSPORE]},
    :IVYSAUR => {:abilities=>[:OVERGROW, :EFFECTSPORE]},
    :VENUSAUR => {:abilities=>[:OVERGROW, :EFFECTSPORE]},
    :CHARMANDER => {:abilities=>[:BLAZE, :WHITESMOKE]},
    :CHARMELEON => {:abilities=>[:BLAZE, :WHITESMOKE]},
    :CHARIZARD => {:abilities=>[:BLAZE, :WHITESMOKE]},
    :SQUIRTLE => {:abilities=>[:TORRENT, :SHELLARMOR]},
    :WARTORTLE => {:abilities=>[:TORRENT, :SHELLARMOR]},
    :BLASTOISE => {:type2=>:STEEL, :abilities=>[:TORRENT, :SHELLARMOR]},
    :BUTTERFREE => {:base_stats=>{:HP=>60, :ATTACK=>45, :DEFENSE=>50, :SPECIAL_ATTACK=>80, :SPECIAL_DEFENSE=>80, :SPEED=>100}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>1, :SPECIAL_DEFENSE=>0, :SPEED=>2}},
    :BEEDRILL => {:base_stats=>{:HP=>65, :ATTACK=>95, :DEFENSE=>40, :SPECIAL_ATTACK=>45, :SPECIAL_DEFENSE=>95, :SPEED=>75}},
    :PIDGEY => {:abilities=>[:TANGLEDFEET, :UNAWARE]},
    :PIDGEOTTO => {:abilities=>[:TANGLEDFEET, :UNAWARE]},
    :PIDGEOT => {:abilities=>[:TANGLEDFEET, :UNAWARE]},
    :EKANS => {:base_stats=>{:HP=>60, :ATTACK=>75, :DEFENSE=>44, :SPECIAL_ATTACK=>30, :SPECIAL_DEFENSE=>54, :SPEED=>75}},
    :ARBOK => {:type2=>:DARK, :base_stats=>{:HP=>95, :ATTACK=>120, :DEFENSE=>69, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>79, :SPEED=>80}},
    :NINETALES => {:type2=>:PSYCHIC, :base_stats=>{:HP=>108, :ATTACK=>76, :DEFENSE=>75, :SPECIAL_ATTACK=>81, :SPECIAL_DEFENSE=>100, :SPEED=>100}, :evs=>{:HP=>1, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>1}, :abilities=>[:FLASHFIRE, :PRESSURE]},
    :JIGGLYPUFF => {:base_stats=>{:HP=>115, :ATTACK=>45, :DEFENSE=>20, :SPECIAL_ATTACK=>45, :SPECIAL_DEFENSE=>25, :SPEED=>60}},
    :WIGGLYTUFF => {:base_stats=>{:HP=>190, :ATTACK=>70, :DEFENSE=>60, :SPECIAL_ATTACK=>75, :SPECIAL_DEFENSE=>75, :SPEED=>15}},
    :VILEPLUME => {:base_stats=>{:HP=>100, :ATTACK=>75, :DEFENSE=>85, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>90, :SPEED=>50}, :evs=>{:HP=>1, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>2, :SPECIAL_DEFENSE=>0, :SPEED=>0}, :abilities=>[:CHLOROPHYLL, :EFFECTSPORE], :hidden_abilities=>[:ADAPTABILITY]},
    :VENONAT => {:base_stats=>{:HP=>60, :ATTACK=>55, :DEFENSE=>50, :SPECIAL_ATTACK=>55, :SPECIAL_DEFENSE=>55, :SPEED=>30}},
    :VENOMOTH => {:base_stats=>{:HP=>70, :ATTACK=>90, :DEFENSE=>60, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>75, :SPEED=>90}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>2, :SPECIAL_DEFENSE=>0, :SPEED=>1}},
    :MEOWTH => {:base_stats=>{:HP=>40, :ATTACK=>60, :DEFENSE=>35, :SPECIAL_ATTACK=>45, :SPECIAL_DEFENSE=>40, :SPEED=>90}},
    :PERSIAN => {:base_stats=>{:HP=>80, :ATTACK=>80, :DEFENSE=>60, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>65, :SPEED=>115}},
    :PSYDUCK => {:type2=>:PSYCHIC},
    :GOLDUCK => {:type2=>:PSYCHIC},
    :WEEPINBELL => {:abilities=>[:CHLOROPHYLL, :MERCILESS]},
    :VICTREEBEL => {:abilities=>[:CHLOROPHYLL, :MERCILESS]},
    :FARFETCHD => {:type1=>:FLYING, :type2=>:FIGHTING, :base_stats=>{:HP=>52, :ATTACK=>125, :DEFENSE=>55, :SPECIAL_ATTACK=>58, :SPECIAL_DEFENSE=>62, :SPEED=>60}, :evs=>{:HP=>0, :ATTACK=>2, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}, :moves=>[[1, :BRAVEBIRD], [1, :POISONJAB], [1, :PECK], [1, :SANDATTACK], [1, :LEER], [1, :FURYCUTTER], [7, :FURYATTACK], [9, :AERIALACE], [13, :KNOCKOFF], [15, :DOUBLEKICK], [19, :SLASH], [21, :AIRCUTTER], [25, :SWORDSDANCE], [29, :SKYUPPERCUT], [31, :AGILITY], [33, :NIGHTSLASH], [37, :ACROBATICS], [40, :SACREDSWORD], [43, :FEINT], [45, :FALSESWIPE], [49, :AIRSLASH], [55, :BRAVEBIRD]], :tutor_moves=>{:add=>[:FOCUSPUNCH, :LOWSWEEP, :ROCKSMASH], :remove=>[]}, :abilities=>[:INNERFOCUS, :SUPERLUCK]},
    :SEEL => {:type1=>:ICE, :type2=>:ICE},
    :DEWGONG => {:type1=>:ICE, :type2=>:WATER, :base_stats=>{:HP=>90, :ATTACK=>70, :DEFENSE=>80, :SPECIAL_ATTACK=>70, :SPECIAL_DEFENSE=>130, :SPEED=>70}},
    :HITMONCHAN => {:base_stats=>{:HP=>50, :ATTACK=>90, :DEFENSE=>120, :SPECIAL_ATTACK=>35, :SPECIAL_DEFENSE=>110, :SPEED=>50}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>2, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}, :abilities=>[:IRONFIST, :CLEARBODY], :hidden_abilities=>[:ANALYTIC]},
    :RHYHORN => {:type2=>:GROUND},
    :TANGELA => {:abilities=>[:GOOEY, :LEAFGUARD]},
    :SEAKING => {:base_stats=>{:HP=>80, :ATTACK=>95, :DEFENSE=>65, :SPECIAL_ATTACK=>92, :SPECIAL_DEFENSE=>80, :SPEED=>68}, :evs=>{:HP=>0, :ATTACK=>1, :DEFENSE=>0, :SPECIAL_ATTACK=>1, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :JYNX => {:type1=>:PSYCHIC, :type2=>:ICE},
    :VAPOREON => {:abilities=>[:WATERABSORB, :RAINDISH]},
    :JOLTEON => {:abilities=>[:VOLTABSORB, :QUICKFEET], :hidden_abilities=>[:COMPOUNDEYES]},
    :FLAREON => {:abilities=>[:FLASHFIRE, :FLAMEBODY]},
    :OMANYTE => {:type1=>:WATER, :type2=>:ROCK},
    :OMASTAR => {:type1=>:WATER, :type2=>:ROCK},
    :CHIKORITA => {:abilities=>[:OVERGROW, :REGENERATOR]},
    :BAYLEEF => {:abilities=>[:OVERGROW, :REGENERATOR]},
    :MEGANIUM => {:abilities=>[:OVERGROW, :REGENERATOR]},
    :CYNDAQUIL => {:abilities=>[:BLAZE, :FLAMEBODY]},
    :QUILAVA => {:abilities=>[:BLAZE, :FLAMEBODY]},
    :TYPHLOSION => {:abilities=>[:BLAZE, :FLAMEBODY]},
    :TOTODILE => {:abilities=>[:TORRENT, :STRONGJAW]},
    :CROCONAW => {:abilities=>[:TORRENT, :STRONGJAW]},
    :FERALIGATR => {:abilities=>[:TORRENT, :STRONGJAW]},
    :SENTRET => {:base_stats=>{:HP=>65, :ATTACK=>46, :DEFENSE=>34, :SPECIAL_ATTACK=>45, :SPECIAL_DEFENSE=>45, :SPEED=>20}, :evs=>{:HP=>1, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}, :abilities=>[:RUNAWAY, :INFILTRATOR]},
    :FURRET => {:base_stats=>{:HP=>125, :ATTACK=>76, :DEFENSE=>64, :SPECIAL_ATTACK=>75, :SPECIAL_DEFENSE=>55, :SPEED=>90}, :evs=>{:HP=>2, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}, :abilities=>[:RUNAWAY, :INFILTRATOR], :hidden_abilities=>[:FLUFFY]},
    :HOOTHOOT => {:type1=>:FLYING, :type2=>:PSYCHIC, :hidden_abilities=>[:RATTLED]},
    :NOCTOWL => {:type1=>:FLYING, :type2=>:PSYCHIC, :hidden_abilities=>[:RATTLED]},
    :LEDYBA => {:base_stats=>{:HP=>40, :ATTACK=>50, :DEFENSE=>30, :SPECIAL_ATTACK=>40, :SPECIAL_DEFENSE=>80, :SPEED=>80}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>1}, :moves=>[[1, :TACKLE], [5, :SUPERSONIC], [8, :SWIFT], [12, :LIGHTSCREEN], [12, :REFLECT], [12, :SAFEGUARD], [15, :MACHPUNCH], [19, :SILVERWIND], [19, :ARMTHRUST], [22, :COMETPUNCH], [26, :BATONPASS], [29, :AGILITY], [33, :BUGBUZZ], [36, :AIRSLASH], [40, :DOUBLEEDGE]]},
    :LEDIAN => {:type2=>:FIGHTING, :base_stats=>{:HP=>65, :ATTACK=>90, :DEFENSE=>50, :SPECIAL_ATTACK=>55, :SPECIAL_DEFENSE=>130, :SPEED=>110}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>2, :SPEED=>1}, :moves=>[[0, :DETECT], [1, :TACKLE], [1, :SUPERSONIC], [1, :SWIFT], [1, :DETECT], [1, :VACUUMWAVE], [5, :SUPERSONIC], [8, :SWIFT], [12, :LIGHTSCREEN], [12, :REFLECT], [12, :SAFEGUARD], [15, :MACHPUNCH], [20, :SILVERWIND], [24, :COMETPUNCH], [25, :ARMTHRUST], [29, :BATONPASS], [33, :AGILITY], [35, :DYNAMICPUNCH], [38, :BUGBUZZ], [42, :AIRSLASH], [47, :DOUBLEEDGE]]},
    :ARIADOS => {:base_stats=>{:HP=>70, :ATTACK=>105, :DEFENSE=>75, :SPECIAL_ATTACK=>80, :SPECIAL_DEFENSE=>75, :SPEED=>40}},
    :IGGLYBUFF => {:base_stats=>{:HP=>90, :ATTACK=>30, :DEFENSE=>15, :SPECIAL_ATTACK=>40, :SPECIAL_DEFENSE=>20, :SPEED=>80}},
    :BELLOSSOM => {:type2=>:FAIRY, :base_stats=>{:HP=>75, :ATTACK=>100, :DEFENSE=>85, :SPECIAL_ATTACK=>90, :SPECIAL_DEFENSE=>100, :SPEED=>50}, :evs=>{:HP=>0, :ATTACK=>2, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>0}, :moves=>[[0, :MAGICALLEAF], [1, :MAGICALLEAF], [1, :LEAFSTORM], [1, :LEAFBLADE], [1, :MEGADRAIN], [1, :SWEETSCENT], [1, :STUNSPORE], [1, :SUNNYDAY], [1, :DISARMINGVOICE], [28, :PSYCHOCUT], [33, :PLAYROUGH], [37, :FIERYDANCE], [39, :QUIVERDANCE], [42, :LUNARDANCE], [49, :PETALBLIZZARD], [57, :FLEURCANNON], [59, :PETALDANCE], [69, :LEAFSTORM]], :tutor_moves=>{:add=>[:DRAININGKISS, :PLAYROUGH, :RAINDANCE], :remove=>[]}, :abilities=>[:CHLOROPHYLL, :HEALER], :hidden_abilities=>[:DOWNLOAD]},
    :SUDOWOODO => {:abilities=>[:SOLIDROCK, :ROCKHEAD], :hidden_abilities=>[:SANDFORCE]},
    :POLITOED => {:type2=>:FAIRY, :moves=>[[1, :BUBBLEBEAM], [1, :HYPNOSIS], [1, :DOUBLESLAP], [1, :PERISHSONG], [1, :PLAYROUGH], [27, :SWAGGER], [37, :BOUNCE], [43, :PLAYROUGH], [48, :HYPERVOICE], [55, :MOONBLAST]], :tutor_moves=>{:add=>[:MOONBLAST, :PLAYROUGH], :remove=>[]}},
    :ESPEON => {:abilities=>[:SYNCHRONIZE, :TINTEDLENS]},
    :UMBREON => {:abilities=>[:SYNCHRONIZE, :REGENERATOR]},
    :MISDREAVUS => {:moves=>[[1, :GROWL], [1, :PSYWAVE], [5, :SPITE], [10, :ASTONISH], [14, :CONFUSERAY], [16, :FAIRYWIND], [19, :MEANLOOK], [23, :HEX], [25, :AROMATICMIST], [28, :PSYBEAM], [32, :PAINSPLIT], [34, :DAZZLINGGLEAM], [37, :PAYBACK], [41, :SHADOWBALL], [43, :MOONLIGHT], [46, :PERISHSONG], [48, :MISTYTERRAIN], [50, :GRUDGE], [55, :POWERGEM], [60, :CRAFTYSHIELD]], :tutor_moves=>{:add=>[:DRAININGKISS, :MOONBLAST], :remove=>[]}},
    :UNOWN => {:type1=>:DARK, :base_stats=>{:HP=>48, :ATTACK=>96, :DEFENSE=>48, :SPECIAL_ATTACK=>96, :SPECIAL_DEFENSE=>48, :SPEED=>72}},
    :WOBBUFFET => {:base_stats=>{:HP=>190, :ATTACK=>58, :DEFENSE=>58, :SPECIAL_ATTACK=>58, :SPECIAL_DEFENSE=>58, :SPEED=>33}},
    :GIRAFARIG => {:type1=>:PSYCHIC, :type2=>:NORMAL, :abilities=>[:MAGICGUARD, :SAPSIPPER], :hidden_abilities=>[:MAGICBOUNCE]},
    :FORRETRESS => {:type1=>:STEEL, :type2=>:BUG},
    :DUNSPARCE => {:base_stats=>{:HP=>135, :ATTACK=>98, :DEFENSE=>70, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>65, :SPEED=>66}, :evs=>{:HP=>2, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :STEELIX => {:base_stats=>{:HP=>75, :ATTACK=>103, :DEFENSE=>200, :SPECIAL_ATTACK=>55, :SPECIAL_DEFENSE=>72, :SPEED=>30}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>3, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :QWILFISH => {:type1=>:POISON, :type2=>:WATER},
    :SCIZOR => {:type1=>:STEEL, :type2=>:BUG},
    :TEDDIURSA => {:moves=>[[1, :FLING], [1, :COVET], [1, :SCRATCH], [1, :DOUBLEKICK], [1, :BABYDOLLEYES], [1, :LICK], [1, :FAKETEARS], [8, :FURYSWIPES], [15, :FEINTATTACK], [22, :SWEETSCENT], [25, :PLAYNICE], [29, :SLASH], [36, :CHARM], [43, :REST], [43, :SNORE], [50, :THRASH], [57, :FLING]]},
    :URSARING => {:type2=>:FIGHTING, :base_stats=>{:HP=>90, :ATTACK=>140, :DEFENSE=>85, :SPECIAL_ATTACK=>55, :SPECIAL_DEFENSE=>75, :SPEED=>55}, :moves=>[[1, :HAMMERARM], [1, :COVET], [1, :SCRATCH], [1, :LEER], [1, :LICK], [1, :REVENGE], [1, :FAKETEARS], [8, :FURYSWIPES], [15, :FEINTATTACK], [22, :SWEETSCENT], [25, :PLAYNICE], [29, :SLASH], [32, :SUBMISSION], [38, :SCARYFACE], [47, :REST], [49, :SNORE], [50, :SUPERPOWER], [58, :THRASH], [67, :HAMMERARM]]},
    :MAGCARGO => {:base_stats=>{:HP=>50, :ATTACK=>50, :DEFENSE=>130, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>110, :SPEED=>30}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>2, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>0}},
    :OCTILLERY => {:base_stats=>{:HP=>75, :ATTACK=>75, :DEFENSE=>75, :SPECIAL_ATTACK=>135, :SPECIAL_DEFENSE=>75, :SPEED=>45}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>2, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :DELIBIRD => {:base_stats=>{:HP=>45, :ATTACK=>85, :DEFENSE=>45, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>45, :SPEED=>115}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>1, :SPECIAL_DEFENSE=>0, :SPEED=>1}},
    :STANTLER => {:type2=>:GRASS, :moves=>[[1, :MEFIRST], [1, :TACKLE], [3, :LEER], [7, :ASTONISH], [10, :HYPNOSIS], [12, :MEGADRAIN], [13, :STOMP], [16, :SANDATTACK], [21, :TAKEDOWN], [22, :BULLETSEED], [23, :CONFUSERAY], [27, :CALMMIND], [30, :AROMATHERAPY], [33, :ROLEPLAY], [35, :GIGADRAIN], [38, :ZENHEADBUTT], [40, :HORNLEECH], [43, :JUMPKICK], [49, :IMPRISON], [50, :CAPTIVATE], [55, :MEFIRST]]},
    :SMOOCHUM => {:type1=>:PSYCHIC, :type2=>:ICE},
    :CELEBI => {:type1=>:GRASS, :type2=>:PSYCHIC},
    :MISMAGIUS => {:type2=>:FAIRY, :moves=>[[1, :MYSTICALFIRE], [1, :POWERGEM], [1, :PHANTOMFORCE], [1, :LUCKYCHANT], [1, :MAGICALLEAF], [1, :GROWL], [1, :PSYWAVE], [1, :SPITE], [1, :ASTONISH], [1, :FAIRYWIND]], :tutor_moves=>{:add=>[:DRAININGKISS, :MOONBLAST, :MOONLIGHT], :remove=>[]}},
    :HONCHKROW => {:base_stats=>{:HP=>125, :ATTACK=>125, :DEFENSE=>52, :SPECIAL_ATTACK=>105, :SPECIAL_DEFENSE=>52, :SPEED=>71}, :evs=>{:HP=>1, :ATTACK=>2, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :BONSLY => {:abilities=>[:SOLIDROCK, :ROCKHEAD], :hidden_abilities=>[:SANDFORCE]},
    :WEAVILE => {:abilities=>[:PRESSURE, :PICKPOCKET], :hidden_abilities=>[:PROTEAN]},
    :RHYPERIOR => {:type1=>:ROCK, :type2=>:GROUND},
    :TANGROWTH => {:abilities=>[:GOOEY, :LEAFGUARD]},
    :LEAFEON => {:abilities=>[:LEAFGUARD, :CHLOROPHYLL], :hidden_abilities=>[:SAPSIPPER]},
    :GLACEON => {:abilities=>[:SNOWCLOAK, :ICEBODY], :hidden_abilities=>[:REFRIGERATE]},
    :TREECKO => {:abilities=>[:OVERGROW, :SUPERLUCK]},
    :GROVYLE => {:abilities=>[:OVERGROW, :SUPERLUCK]},
    :SCEPTILE => {:abilities=>[:OVERGROW, :SUPERLUCK]},
    :TORCHIC => {:abilities=>[:BLAZE, :FLASHFIRE]},
    :COMBUSKEN => {:abilities=>[:BLAZE, :FLASHFIRE]},
    :BLAZIKEN => {:abilities=>[:BLAZE, :FLASHFIRE]},
    :MUDKIP => {:abilities=>[:TORRENT, :SANDRUSH]},
    :MARSHTOMP => {:abilities=>[:TORRENT, :SANDRUSH]},
    :SWAMPERT => {:abilities=>[:TORRENT, :SANDRUSH]},
    :SPIRITOMB => {:type1=>:GHOST, :type2=>:DARK, :base_stats=>{:HP=>90, :ATTACK=>92, :DEFENSE=>108, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>108, :SPEED=>35}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>1, :SPECIAL_ATTACK=>1, :SPECIAL_DEFENSE=>1, :SPEED=>0}},
    :MAWILE => {:base_stats=>{:HP=>50, :ATTACK=>140, :DEFENSE=>105, :SPECIAL_ATTACK=>75, :SPECIAL_DEFENSE=>55, :SPEED=>50}, :evs=>{:HP=>0, :ATTACK=>2, :DEFENSE=>1, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :SHIELDON => {:type2=>:ROCK, :moves=>[[1, :TACKLE], [1, :PROTECT], [6, :TAUNT], [10, :METALSOUND], [15, :TAKEDOWN], [19, :IRONDEFENSE], [20, :ROCKTOMB], [24, :SWAGGER], [28, :ANCIENTPOWER], [33, :ENDURE], [37, :METALBURST], [42, :IRONHEAD], [46, :HEAVYSLAM]]},
    :BASTIODON => {:type1=>:STEEL},
    :DUSCLOPS => {:abilities=>[:PRESSURE, :FRISK], :hidden_abilities=>[:MUMMY]},
    :DUSKNOIR => {:base_stats=>{:HP=>45, :ATTACK=>130, :DEFENSE=>135, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>135, :SPEED=>45}, :evs=>{:HP=>0, :ATTACK=>1, :DEFENSE=>1, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>0}, :abilities=>[:PRESSURE, :FRISK], :hidden_abilities=>[:BADDREAMS]},
    :WAILORD => {:base_stats=>{:HP=>170, :ATTACK=>90, :DEFENSE=>45, :SPECIAL_ATTACK=>90, :SPECIAL_DEFENSE=>45, :SPEED=>80}, :abilities=>[:WATERVEIL, :PRESSURE], :hidden_abilities=>[:DRIZZLE]},
    :TURTWIG => {:abilities=>[:OVERGROW, :STURDY]},
    :GROTLE => {:abilities=>[:OVERGROW, :STURDY]},
    :TORTERRA => {:abilities=>[:OVERGROW, :STURDY]},
    :CHIMCHAR => {:abilities=>[:BLAZE, :GUTS]},
    :MONFERNO => {:abilities=>[:BLAZE, :GUTS]},
    :INFERNAPE => {:abilities=>[:BLAZE, :GUTS]},
    :PIPLUP => {:abilities=>[:TORRENT, :ICEBODY]},
    :PRINPLUP => {:abilities=>[:TORRENT, :ICEBODY]},
    :EMPOLEON => {:abilities=>[:TORRENT, :ICEBODY]},
    :PAWNIARD => {:base_stats=>{:HP=>45, :ATTACK=>85, :DEFENSE=>70, :SPECIAL_ATTACK=>40, :SPECIAL_DEFENSE=>60, :SPEED=>60}},
    :BISHARP => {:base_stats=>{:HP=>65, :ATTACK=>125, :DEFENSE=>100, :SPECIAL_ATTACK=>60, :SPECIAL_DEFENSE=>100, :SPEED=>70}, :evs=>{:HP=>0, :ATTACK=>2, :DEFENSE=>1, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :AGGRON => {:base_stats=>{:HP=>95, :ATTACK=>110, :DEFENSE=>180, :SPECIAL_ATTACK=>60, :SPECIAL_DEFENSE=>60, :SPEED=>50}},
    :FLYGON => {:type1=>:BUG},
    :SYLVEON => {:abilities=>[:CUTECHARM, :DAZZLING]},
    :LOPUNNY => {:type2=>:FIGHTING},
    :BANETTE => {:base_stats=>{:HP=>64, :ATTACK=>115, :DEFENSE=>65, :SPECIAL_ATTACK=>83, :SPECIAL_DEFENSE=>63, :SPEED=>115}, :evs=>{:HP=>0, :ATTACK=>2, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>1}},
    :COFAGRIGUS => {:type2=>:ROCK, :base_stats=>{:HP=>58, :ATTACK=>75, :DEFENSE=>145, :SPECIAL_ATTACK=>105, :SPECIAL_DEFENSE=>125, :SPEED=>30}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>2, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>0}, :moves=>[[0, :SCARYFACE], [1, :SCARYFACE], [1, :ASTONISH], [1, :PROTECT], [1, :DISABLE], [1, :HAZE], [1, :ANCIENTPOWER], [1, :ROCKBLAST], [5, :DISABLE], [9, :HAZE], [13, :NIGHTSHADE], [17, :HEX], [21, :WILLOWISP], [25, :OMINOUSWIND], [29, :CURSE], [33, :POWERSPLIT], [33, :GUARDSPLIT], [35, :STEALTHROCK], [39, :SHADOWBALL], [40, :ROCKSLIDE], [45, :GRUDGE], [51, :MEANLOOK], [57, :DESTINYBOND]], :tutor_moves=>{:add=>[:SANDSTORM, :STONEEDGE], :remove=>[]}},
    :GALVANTULA => {:type1=>:ELECTRIC, :type2=>:BUG},
    :HAXORUS => {:base_stats=>{:HP=>106, :ATTACK=>147, :DEFENSE=>95, :SPECIAL_ATTACK=>75, :SPECIAL_DEFENSE=>80, :SPEED=>97}},
    :VOLCARONA => {:type1=>:FIRE, :type2=>:BUG},
    :LATIAS => {:type1=>:PSYCHIC, :type2=>:DRAGON},
    :DEOXYS => {:hidden_abilities=>[:ANALYTIC]},
    :VIBRAVA => {:type1=>:BUG, :type2=>:BUG},
    :SHUPPET => {:base_stats=>{:HP=>44, :ATTACK=>75, :DEFENSE=>35, :SPECIAL_ATTACK=>63, :SPECIAL_DEFENSE=>33, :SPEED=>75}},
    :YAMASK => {:type2=>:ROCK, :base_stats=>{:HP=>38, :ATTACK=>45, :DEFENSE=>95, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>75, :SPEED=>30}, :moves=>[[1, :ASTONISH], [1, :PROTECT], [1, :ROLLOUT], [5, :DISABLE], [9, :HAZE], [13, :NIGHTSHADE], [17, :HEX], [21, :WILLOWISP], [25, :OMINOUSWIND], [26, :ANCIENTPOWER], [29, :CURSE], [33, :POWERSPLIT], [33, :GUARDSPLIT], [37, :SHADOWBALL], [41, :GRUDGE], [45, :MEANLOOK], [49, :DESTINYBOND]], :tutor_moves=>{:add=>[:ROCKSLIDE, :SANDSTORM, :STONEEDGE], :remove=>[]}},
    :JOLTIK => {:type1=>:ELECTRIC, :type2=>:BUG},
    :FRAXURE => {:base_stats=>{:HP=>80, :ATTACK=>117, :DEFENSE=>70, :SPECIAL_ATTACK=>40, :SPECIAL_DEFENSE=>56, :SPEED=>67}},
    :LARVESTA => {:type1=>:FIRE, :type2=>:BUG},
    :STUNFISK => {:type1=>:ELECTRIC, :type2=>:GROUND},
    :SABLEYE => {:abilities=>[:MAGICBOUNCE, :STALL]},
    :GLALIE => {:base_stats=>{:HP=>85, :ATTACK=>85, :DEFENSE=>85, :SPECIAL_ATTACK=>85, :SPECIAL_DEFENSE=>85, :SPEED=>85}, :evs=>{:HP=>2, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>1}},
    :FROSLASS => {:base_stats=>{:HP=>70, :ATTACK=>95, :DEFENSE=>70, :SPECIAL_ATTACK=>95, :SPECIAL_DEFENSE=>70, :SPEED=>110}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>3}},
    :TRUBBISH => {:base_stats=>{:HP=>50, :ATTACK=>50, :DEFENSE=>62, :SPECIAL_ATTACK=>60, :SPECIAL_DEFENSE=>62, :SPEED=>65}},
    :GARBODOR => {:base_stats=>{:HP=>80, :ATTACK=>95, :DEFENSE=>102, :SPECIAL_ATTACK=>95, :SPECIAL_DEFENSE=>102, :SPEED=>75}, :evs=>{:HP=>0, :ATTACK=>1, :DEFENSE=>1, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>1, :SPEED=>0}},
    :TREVENANT => {:base_stats=>{:HP=>85, :ATTACK=>112, :DEFENSE=>130, :SPECIAL_ATTACK=>65, :SPECIAL_DEFENSE=>82, :SPEED=>56}, :evs=>{:HP=>0, :ATTACK=>1, :DEFENSE=>2, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>0}},
    :ALTARIA => {:base_stats=>{:HP=>75, :ATTACK=>70, :DEFENSE=>90, :SPECIAL_ATTACK=>100, :SPECIAL_DEFENSE=>105, :SPEED=>80}, :evs=>{:HP=>0, :ATTACK=>0, :DEFENSE=>0, :SPECIAL_ATTACK=>1, :SPECIAL_DEFENSE=>2, :SPEED=>0}},
    :AMAURA => {:type1=>:ICE, :type2=>:ROCK},
    :AURORUS => {:type1=>:ICE, :type2=>:ROCK},
    :LYCANROC_N => {:type1=>:DARK, :base_stats=>{:HP=>85, :ATTACK=>130, :DEFENSE=>75, :SPECIAL_ATTACK=>55, :SPECIAL_DEFENSE=>75, :SPEED=>67}, :moves=>[[0, :COUNTER], [0, :ACCELEROCK], [1, :ACCELEROCK], [1, :REVERSAL], [1, :TAUNT], [1, :TACKLE], [1, :LEER], [1, :SANDATTACK], [1, :BITE], [4, :SANDATTACK], [7, :BITE], [12, :HOWL], [15, :ROCKTHROW], [18, :ODORSLEUTH], [23, :ROCKTOMB], [26, :ROAR], [29, :STEALTHROCK], [34, :ROCKSLIDE], [37, :SCARYFACE], [40, :CRUNCH], [45, :ROCKCLIMB], [48, :STONEEDGE]]},
    :BRUXISH => {:type1=>:PSYCHIC, :type2=>:WATER, :base_stats=>{:HP=>80, :ATTACK=>105, :DEFENSE=>70, :SPECIAL_ATTACK=>70, :SPECIAL_DEFENSE=>70, :SPEED=>100}, :evs=>{:HP=>0, :ATTACK=>1, :DEFENSE=>0, :SPECIAL_ATTACK=>0, :SPECIAL_DEFENSE=>0, :SPEED=>1}},
    :CHESPIN => {:abilities=>[:OVERGROW, :IRONBARBS]},
    :QUILLADIN => {:abilities=>[:OVERGROW, :IRONBARBS]},
    :CHESNAUGHT => {:abilities=>[:OVERGROW, :IRONBARBS]},
    :FENNEKIN => {:abilities=>[:BLAZE, :MAGICGUARD]},
    :BRAIXEN => {:abilities=>[:BLAZE, :MAGICGUARD]},
    :DELPHOX => {:abilities=>[:BLAZE, :MAGICGUARD]},
    :FROAKIE => {:abilities=>[:TORRENT, :QUICKFEET]},
    :FROGADIER => {:abilities=>[:TORRENT, :QUICKFEET]},
    :GRENINJA => {:abilities=>[:TORRENT, :QUICKFEET]},
    :SWIRLIX => {:base_stats=>{:HP=>82, :ATTACK=>48, :DEFENSE=>66, :SPECIAL_ATTACK=>59, :SPECIAL_DEFENSE=>57, :SPEED=>49}},
    :SLURPUFF => {:base_stats=>{:HP=>122, :ATTACK=>65, :DEFENSE=>96, :SPECIAL_ATTACK=>95, :SPECIAL_DEFENSE=>85, :SPEED=>72}},
    :LUVDISC => {:abilities=>[:SWIFTSWIM, :REGENERATOR]},
  }

  def self.valid(field, v)
    case field
    when :type1, :type2
      return GameData::Type.exists?(v) ? v : nil
    when :abilities, :hidden_abilities
      return v.select { |a| GameData::Ability.exists?(a) }
    when :moves
      return v.select { |m| GameData::Move.exists?(m[1]) }.map(&:dup)
    when :tutor_moves, :egg_moves
      return { :add => v[:add].select { |m| GameData::Move.exists?(m) }, :remove => v[:remove] }
    end
    return v.is_a?(Hash) ? v.dup : v
  end

  # After every game data load (a fresh copy of the game's data each time)
  def self.apply
    data = GameData::Species::DATA
    return if data.equal?(@data)
    @data = data
    missing = []
    CHANGES.each do |id, fields|
      sp = data[id]
      (missing << id; next) unless sp
      fields.each do |field, v|
        v = valid(field, v)
        next if v.nil?
        if field == :tutor_moves || field == :egg_moves
          list = Array(sp.send(field)) - v[:remove]
          v = list + (v[:add] - list)
        end
        sp.instance_variable_set("@#{field}", v)
      end
    end
    KIF::Perf.bump_token if defined?(KIF::Perf) && KIF::Perf.respond_to?(:bump_token)   # cached fusion data
    @recalc = true
    echoln("[Romanoff's Rework] not in this game: #{missing.join(', ')}") unless missing.empty?
  end

  # Pokemon already caught keep the stats they were last calculated with:
  # recalculated once after the data changed
  def self.recalc_owned
    return unless @recalc && $Trainer
    @recalc = false
    list = $Trainer.party.compact
    if $PokemonStorage
      $PokemonStorage.maxBoxes.times do |b|
        $PokemonStorage.maxPokemon(b).times { |s| pk = $PokemonStorage[b, s]; list << pk if pk }
      end
    end
    list.each { |pk| pk.calc_stats unless pk.egg? }
  rescue StandardError => e
    echoln("[Romanoff's Rework] stats not recalculated: #{e.class}: #{e.message}")
  end
end

if defined?(KIF::DataLoad)
  KIF::DataLoad.after_load_all("Romanoff's Rework") { RomanoffRework.apply }
end
RomanoffRework.apply if defined?(GameData::Species::DATA) && !GameData::Species::DATA.empty?
Events.onMapSceneChange += proc { |_sender, _e| RomanoffRework.recalc_owned }
