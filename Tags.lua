local TOCNAME,EC=...

local RECIPE_SLOT_ALIASES = {
	["2h weapon"] = {"2h weapon", "2h weap", "2h", "2 hand weapon", "2 hander"},
	["boots"] = {"boots", "boot", "feet"},
	["bracer"] = {"bracer", "bracers", "wrist"},
	["chest"] = {"chest"},
	["cloak"] = {"cloak", "back", "cape"},
	["gloves"] = {"gloves", "glove", "hands", "hand"},
	["shield"] = {"shield"},
	["weapon"] = {"weapon", "weap"},
}

local RECIPE_EFFECT_PHRASE_OVERRIDES = {
	["Enchant Cloak - Lesser Agility"] = {"3 agi", "3 agility"},
}

local function TrimText(value)
	if type(value) ~= "string" then
		return ""
	end
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function CopyNormalizedTags(values)
	local out = {}
	local seen = {}

	for _, value in ipairs(values or {}) do
		local cleanedValue = TrimText(string.lower(tostring(value or "")))
		if cleanedValue ~= "" and not seen[cleanedValue] then
			seen[cleanedValue] = true
			out[#out + 1] = cleanedValue
		end
	end

	return out
end

local function GetRecipeSlotKeyAndEffect(recipeName)
	local patterns = {
		{"^Enchant%s+2H Weapon%s+%-%s+(.+)$", "2h weapon"},
		{"^Enchant%s+Boots%s+%-%s+(.+)$", "boots"},
		{"^Enchant%s+Bracer%s+%-%s+(.+)$", "bracer"},
		{"^Enchant%s+Chest%s+%-%s+(.+)$", "chest"},
		{"^Enchant%s+Cloak%s+%-%s+(.+)$", "cloak"},
		{"^Enchant%s+Gloves%s+%-%s+(.+)$", "gloves"},
		{"^Enchant%s+Shield%s+%-%s+(.+)$", "shield"},
		{"^Enchant%s+Weapon%s+%-%s+(.+)$", "weapon"},
	}

	for _, entry in ipairs(patterns) do
		local effectName = type(recipeName) == "string" and recipeName:match(entry[1]) or nil
		if effectName and effectName ~= "" then
			return entry[2], TrimText(string.lower(effectName))
		end
	end

	return nil, nil
end

local function GetNumericPhraseVariants(phrase)
	if type(phrase) ~= "string" then
		return {}
	end

	local variants = {}
	local seen = {}

	local function AddVariant(value)
		local cleanedValue = TrimText(string.lower(tostring(value or "")))
		if cleanedValue ~= "" and not seen[cleanedValue] then
			seen[cleanedValue] = true
			variants[#variants + 1] = cleanedValue
		end
	end

	AddVariant(phrase)

	local amount, statName = phrase:match("^([+]?%d+)%s+([%a]+)$")
	if amount and statName then
		AddVariant(amount .. statName)
		if string.sub(amount, 1, 1) ~= "+" then
			AddVariant("+" .. amount .. " " .. statName)
			AddVariant("+" .. amount .. statName)
		end
	end

	return variants
end

function EC.BuildSpecificRecipeTagList(recipeName, effectPhrases, extraTags)
	local slotKey, derivedEffect = GetRecipeSlotKeyAndEffect(recipeName)
	local slotAliases = slotKey and RECIPE_SLOT_ALIASES[slotKey] or nil
	local tags = {recipeName}
	local phrases = {}
	local seenPhrases = {}

	local function AddPhrase(phrase)
		local cleanedPhrase = TrimText(string.lower(tostring(phrase or "")))
		if cleanedPhrase ~= "" and not seenPhrases[cleanedPhrase] then
			seenPhrases[cleanedPhrase] = true
			phrases[#phrases + 1] = cleanedPhrase
		end
	end

	if type(effectPhrases) == "table" and #effectPhrases > 0 then
		for _, phrase in ipairs(effectPhrases) do
			AddPhrase(phrase)
		end
	else
		AddPhrase(derivedEffect)
		for _, phrase in ipairs(RECIPE_EFFECT_PHRASE_OVERRIDES[recipeName] or {}) do
			AddPhrase(phrase)
		end
	end

	if slotAliases and #phrases > 0 then
		for _, phrase in ipairs(phrases) do
			for _, phraseVariant in ipairs(GetNumericPhraseVariants(phrase)) do
				for _, slotAlias in ipairs(slotAliases) do
					tags[#tags + 1] = phraseVariant .. " to " .. slotAlias
					tags[#tags + 1] = phraseVariant .. " " .. slotAlias
					tags[#tags + 1] = slotAlias .. " " .. phraseVariant
				end
			end
		end
	end

	for _, extraTag in ipairs(extraTags or {}) do
		tags[#tags + 1] = extraTag
	end

	return CopyNormalizedTags(tags)
end

local function MergeRecipeTagEntries(baseEntries, extraEntries)
	local merged = {}

	for recipeName, value in pairs(baseEntries or {}) do
		merged[recipeName] = value
	end

	for recipeName, value in pairs(extraEntries or {}) do
		merged[recipeName] = value
	end

	return merged
end

local function langSplit(source)
	local ret={}
	for recipeName,value in pairs(source or {}) do
		if type(value) == "table" then
			ret[recipeName] = CopyNormalizedTags(value)
		else
			ret[recipeName]=EC.Tool.Split(value:lower(),",")
		end
	end
	return ret
end

EC.DefaultPrefixTags = {"lf", "wtb", "looking for"}
-- MIGHT NEED THIS ONE LATER
EC.DefaultEnchanterTags = {"lf enchanter", "looking for enchanter", "any enchanters online", "need enchanter"}

-- ******IMPORTANT******
-- You can't have just a token number be part of the pattern or it will wrongly match on item links
-- ie "spellpower to weapon,40" will match LF JC [Relentless Earthstorm Diamond] due to the "40"
-- if instead of "40" it would be "+40" or "40+" thats okay
EC.DefaultRecipeTags={
	enGB = langSplit(MergeRecipeTagEntries({
	["Enchant 2H Weapon - Major Agility"] = "Enchant 2H Weapon - Major Agility,35 agi",
	["Enchant 2H Weapon - Savagery"] = "Enchant 2H Weapon - Savagery,savagery",
	["Enchant Boots - Boar's Speed"] = "Enchant Boots - Boar's Speed,boar",
	["Enchant Boots - Cat's Swiftness"] = "Enchant Boots - Cat's Swiftness,cats,cat's,cat swift",
	["Enchant Boots - Dexterity"] = "Enchant Boots - Dexterity,dex to boots,dex to feet,12 agi to boots,12 agi to feet,12 agi boot,dexterity to boot,boots agil",
	["Enchant Boots - Fortitude"] = "Enchant Boots - Fortitude,fortitude to boots,fortitude to feet,fort to boots,fort boot,fort to feet,12 stam to boot,boots stamina",
	["Enchant Boots - Minor Speed"] = "Enchant Boots - Minor Speed,minor speed,speed to boot,speed to feet,minor move speed,minor movespeed,move speed to boots",
	["Enchant Boots - Surefooted"] = "Enchant Boots - Surefooted,surefoot",
	["Enchant Boots - Vitality"] = "Enchant Boots - Vitality,vitality to feet,vitality to boots",
	["Enchant Bracer - Assault"] = "Enchant Bracer - Assault,bracers assault,assault to bracer,bracers assault,24 ap,24 attack power,ap to bracer",
	["Enchant Bracer - Brawn"] = "Enchant Bracer - Brawn,12 strength,12 str,brawn,str to bracer,strength to bracer",
	["Enchant Bracer - Fortitude"] = "Enchant Bracer - Fortitude,fortitude to wrist,fortitude to bracer,12 stam to bracers,12 stam to wrist,12 stamina to wrist,12 stamina to bracer",
	["Enchant Bracer - Healing Power"] = "Enchant Bracer - Healing Power,24 healing,24 heal,healing power to wrist,healing power to bracer,healing power bracer",
	["Enchant Bracer - Major Defense"] = "Enchant Bracer - Major Defense,12 def,def to bracer,def to wrist,defense to bracer",
	["Enchant Bracer - Major Intellect"] = "Enchant Bracer - Major Intellect,12 int to wrist,12 int to bracer,major intellect to bracer,major intellect to wrist",
	["Enchant Bracer - Restore Mana Prime"] = "Enchant Bracer - Restore Mana Prime,mp5 to wrist,mp5 to bracer,restore mana prime",
	["Enchant Bracer - Spellpower"] = "Enchant Bracer - Spellpower,sp to wrist,sp to bracer,spell damage to wrist,spell damage to bracer,spelldamage to wrist,spelldamage to bracer,spellpower to wrist,spellpower to bracer,15sp,15 sp ,bracer spell,15 spell power",
	["Enchant Bracer - Stats"] = "Enchant Bracer - Stats,stats to bracer,stats to wrist",
	["Enchant Bracer - Superior Healing"] = "Enchant Bracer - Superior Healing,healing to bracer,healing to wrist,heal to bracer,heal to wrist,superior healing bracer,30 healing to bracer,30 healing bracer,30 healing wrist,30 healing to wrist",
	["Enchant Chest - Exceptional Health"] = "Enchant Chest - Exceptional Health,150 hp,150hp,exceptional health,health to chest,150 health,150+ health",
	["Enchant Chest - Exceptional Stats"] = "Enchant Chest - Exceptional Stats,6 stat,6 all stat,6 to stat,exceptional stats,6 to chest",
	["Enchant Chest - Greater Stats"] = "Enchant Chest - Greater Stats,+4 stat,greater stat,4+ chest,4+ to chest,4 to chest,4 stat",
	["Enchant Chest - Major Resilience"] = "Enchant Chest - Major Resilience,resil to chest,15 resil,major resilience,resil chest,15 res,15+ res,res to chest,res chest,15 resil to chest,major resil",
	["Enchant Chest - Major Spirit"] = "Enchant Chest - Major Spirit,major spirit chest,major spirit to chest,15 spirit,15+ spirit",
	["Enchant Chest - Restore Mana Prime"] = "Enchant Chest - Restore Mana Prime,mp5 to chest",
	["Enchant Cloak - Dodge"] = "Enchant Cloak - Dodge,dodge",
	["Enchant Cloak - Greater Agility"] = "Enchant Cloak - Greater Agility,greater agility to back,greater agility to cloak,12 agi to back,12 agi to cloak,12 agility to cloak,12 agility to back,agi to cloak,agility to cloak,agility to back",
	["Enchant Cloak - Greater Arcane Resistance"] = "Enchant Cloak - Greater Arcane Resistance,arcane res",
	["Enchant Cloak - Greater Fire Resistance"] = "Enchant Cloak - Greater Fire Resistance,fire res",
	["Enchant Cloak - Greater Nature Resistance"] = "Enchant Cloak - Greater Nature Resistance,nature res",
	["Enchant Cloak - Greater Shadow Resistance"] = "Enchant Cloak - Greater Shadow Resistance,shadow res",
	["Enchant Cloak - Major Armor"] = "Enchant Cloak - Major Armor,major armor,120 armor,120 armour,120+",
	["Enchant Cloak - Major Resistance"] = "Enchant Cloak - Major Resistance,major resis,7 resis,7 resist,7 resistance,major res to cloak",
	["Enchant Cloak - Spell Penetration"] = "Enchant Cloak - Spell Penetration,spell pen,pen to cloak,pen to back",
	["Enchant Cloak - Stealth"] = "Enchant Cloak - Stealth,stealth",
	["Enchant Cloak - Subtlety"] = "Enchant Cloak - Subtlety,subtlety,2%",
	["Enchant Gloves - Advanced Herbalism"] = "Enchant Gloves - Advanced Herbalism,advanced herb,advance herb,herb to hand,herb to glove,+herb,herbalism to hand,herbalism to glove",
	["Enchant Gloves - Advanced Mining"] = "Enchant Gloves - Advanced Mining,advanced mining,mining to hand, mining to glove",
	["Enchant Gloves - Assault"] = "Enchant Gloves - Assault,assault to glove,assault to hand,gloves assault,glove assault,26 ap,26 attack power,ap to gloves",
	["Enchant Gloves - Blasting"] = "Enchant Gloves - Blasting,blasting to gloves,blasting to hands,crit to glove,crit to hand",
	["Enchant Gloves - Fire Power"] = "Enchant Gloves - Fire Power,fire power,20 fire",
	["Enchant Gloves - Frost Power"] = "Enchant Gloves - Frost Power,frost power,20 frost",
	["Enchant Gloves - Healing Power"] = "Enchant Gloves - Healing Power,+30 healing,30+ heal",
	["Enchant Gloves - Major Healing"] = "Enchant Gloves - Major Healing,35 heal,healing to glove,healing to hand,heal to glove,heal to hand",
	["Enchant Gloves - Major Spellpower"] = "Enchant Gloves - Major Spellpower,major spellpower,major spell power,sp to hand,20sp to glove,20 sp to glove,20+ sp to glove,20sp glove,",
	["Enchant Gloves - Major Strength"] = "Enchant Gloves - Major Strength,major str,15 str,15+ str,str glove",
	["Enchant Gloves - Riding Skill"] = "Enchant Gloves - Riding Skill,riding speed,riding skill,+riding",
	["Enchant Gloves - Shadow Power"] = "Enchant Gloves - Shadow Power,shadow power,20 shadow",
	["Enchant Gloves - Spell Strike"] = "Enchant Gloves - Spell Strike,spell strike,hit to glove,hit to hand,15 hit,15 spell hit",
	["Enchant Gloves - Superior Agility"] = "Enchant Gloves - Superior Agility,superior agility,15 agi,15agi,15+ agi ",
	["Enchant Gloves - Threat"] = "Enchant Gloves - Threat,threat",
	["Enchant Shield - Intellect"] = "Enchant Shield - Intellect,12 int to shield,12 intellect to shield,12 int shield,12 intellect shield",
	["Enchant Shield - Major Stamina"] = "Enchant Shield - Major Stamina,stam to shield,18 stam,18+ stam,stamina to shield",
	["Enchant Shield - Resilience"] = "Enchant Shield - Resilience,res to shield,resilience to shield,12 res",
	["Enchant Shield - Resistance"] = "Enchant Shield - Resistance",
	["Enchant Shield - Shield Block"] = "Enchant Shield - Shield Block,shield block,15 block,block rating",
	["Enchant Shield - Tough Shield"] = "Enchant Shield - Tough Shield,block value,18 block,18 value",
	["Enchant Weapon - Battlemaster"] = "Enchant Weapon - Battlemaster,battlemaster",
	["Enchant Weapon - Crusader"] = "Enchant Weapon - Crusader,crusader",
	["Enchant Weapon - Fiery Weapon"] = "Enchant Weapon - Fiery Weapon,fiery",
	["Enchant Weapon - Healing Power"] = "Enchant Weapon - Healing Power,55 heal,55+",
	["Enchant Weapon - Lifestealing"] = "Enchant Weapon - Lifestealing,lifesteal,life steal",
	["Enchant Weapon - Major Healing"] = "Enchant Weapon - Major Healing,81 heal,81+ heal,major healing weapon,weapon major healing",
	["Enchant Weapon - Major Intellect"] = "Enchant Weapon - Major Intellect,30 int,30+ int",
	["Enchant Weapon - Major Spellpower"] = "Enchant Weapon - Major Spellpower,spellpower to weap,40 sp,40 spell,40+ spell,sp to weap,weapon major spell",
	["Enchant Weapon - Mighty Spirit"] = "Enchant Weapon - Mighty Spirit,20 spirit,20+ spirit",
	["Enchant Weapon - Mongoose"] = "Enchant Weapon - Mongoose,mongoose",
	["Enchant Weapon - Potency"] = "Enchant Weapon - Potency,potency",
	["Enchant Weapon - Soulfrost"] = "Enchant Weapon - Soulfrost,soulfrost,soul frost",
	["Enchant Weapon - Spell Power"] = "Enchant Weapon - Spell Power,30 sp,30+ sp",
	["Enchant Weapon - Spellsurge"] = "Enchant Weapon - Spellsurge,spellsurge,spell surge",
	["Enchant Weapon - Sunfire"] = "Enchant Weapon - Sunfire,sunfire,sun fire",
	["Enchant Weapon - Greater Agility"] = "Enchant Weapon - Greater Agility,20 agi",
	["Superior Mana Oil"] = "Superior Mana Oil",
	["Superior Wizard Oil"] = "Superior Wizard Oil",
	}, {
	["Enchant 2H Weapon - Agility"] = EC.BuildSpecificRecipeTagList("Enchant 2H Weapon - Agility", {"25 agi", "25 agility"}),
	["Enchant 2H Weapon - Greater Impact"] = EC.BuildSpecificRecipeTagList("Enchant 2H Weapon - Greater Impact", {"greater impact", "7 dmg", "7 damage"}),
	["Enchant 2H Weapon - Major Intellect"] = EC.BuildSpecificRecipeTagList("Enchant 2H Weapon - Major Intellect", {"major intellect", "9 int", "9 intellect"}),
	["Enchant 2H Weapon - Major Spirit"] = EC.BuildSpecificRecipeTagList("Enchant 2H Weapon - Major Spirit", {"major spirit", "9 spirit"}),
	["Enchant 2H Weapon - Superior Impact"] = EC.BuildSpecificRecipeTagList("Enchant 2H Weapon - Superior Impact", {"superior impact", "9 dmg", "9 damage"}),
	["Enchant Boots - Greater Agility"] = EC.BuildSpecificRecipeTagList("Enchant Boots - Greater Agility", {"greater agility", "7 agi", "7 agility"}),
	["Enchant Boots - Greater Stamina"] = EC.BuildSpecificRecipeTagList("Enchant Boots - Greater Stamina", {"greater stamina", "7 stam", "7 stamina"}),
	["Enchant Boots - Spirit"] = EC.BuildSpecificRecipeTagList("Enchant Boots - Spirit", {"5 spirit"}),
	["Enchant Bracer - Greater Intellect"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Greater Intellect", {"greater intellect", "7 int", "7 intellect"}),
	["Enchant Bracer - Greater Stamina"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Greater Stamina", {"greater stamina", "7 stam", "7 stamina"}),
	["Enchant Bracer - Greater Strength"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Greater Strength", {"greater strength", "7 str", "7 strength"}),
	["Enchant Bracer - Mana Regeneration"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Mana Regeneration", {"mana regeneration", "4 mp5", "4 mana per 5"}),
	["Enchant Bracer - Superior Spirit"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Superior Spirit", {"superior spirit", "9 spirit"}),
	["Enchant Bracer - Superior Stamina"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Superior Stamina", {"superior stamina", "9 stam", "9 stamina"}),
	["Enchant Bracer - Superior Strength"] = EC.BuildSpecificRecipeTagList("Enchant Bracer - Superior Strength", {"superior strength", "9 str", "9 strength"}),
	["Enchant Chest - Defense"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Defense", {"defense", "15 def", "15 defense"}),
	["Enchant Chest - Exceptional Mana"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Exceptional Mana", {"exceptional mana", "150 mana"}),
	["Enchant Chest - Major Health"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Major Health", {"major health", "100 hp", "100 health"}),
	["Enchant Chest - Major Mana"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Major Mana", {"major mana", "100 mana"}),
	["Enchant Chest - Stats"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Stats", {"3 stat", "3 stats", "3 all stat", "3 all stats"}),
	["Enchant Chest - Superior Mana"] = EC.BuildSpecificRecipeTagList("Enchant Chest - Superior Mana", {"superior mana", "65 mana"}),
	["Enchant Cloak - Greater Resistance"] = EC.BuildSpecificRecipeTagList("Enchant Cloak - Greater Resistance", {"greater resistance", "5 resist", "5 resistance", "5 all resist", "5 all resistance"}),
	["Enchant Cloak - Steelweave"] = EC.BuildSpecificRecipeTagList("Enchant Cloak - Steelweave", {"steelweave", "12 def", "12 defense"}, {"steelweave"}),
	["Enchant Cloak - Superior Defense"] = EC.BuildSpecificRecipeTagList("Enchant Cloak - Superior Defense", {"superior defense", "70 armor", "70 armour"}),
	["Enchant Gloves - Greater Agility"] = EC.BuildSpecificRecipeTagList("Enchant Gloves - Greater Agility", {"greater agility", "7 agi", "7 agility"}),
	["Enchant Gloves - Greater Strength"] = EC.BuildSpecificRecipeTagList("Enchant Gloves - Greater Strength", {"greater strength", "7 str", "7 strength"}),
	["Enchant Gloves - Minor Haste"] = EC.BuildSpecificRecipeTagList("Enchant Gloves - Minor Haste", {"minor haste", "1 haste"}, {"minor haste"}),
	["Enchant Shield - Greater Spirit"] = EC.BuildSpecificRecipeTagList("Enchant Shield - Greater Spirit", {"greater spirit", "7 spirit"}),
	["Enchant Shield - Greater Stamina"] = EC.BuildSpecificRecipeTagList("Enchant Shield - Greater Stamina", {"greater stamina", "7 stam", "7 stamina"}),
	["Enchant Shield - Superior Spirit"] = EC.BuildSpecificRecipeTagList("Enchant Shield - Superior Spirit", {"superior spirit", "9 spirit"}),
	["Enchant Weapon - Agility"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Agility", {"15 agi", "15 agility"}),
	["Enchant Weapon - Deathfrost"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Deathfrost", {"deathfrost", "death frost"}, {"deathfrost", "death frost"}),
	["Enchant Weapon - Demonslaying"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Demonslaying", {"demonslaying"}, {"demonslaying"}),
	["Enchant Weapon - Executioner"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Executioner", {"executioner"}, {"executioner"}),
	["Enchant Weapon - Greater Striking"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Greater Striking", {"greater striking", "4 dmg", "4 damage"}),
	["Enchant Weapon - Icy Chill"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Icy Chill", {"icy chill"}, {"icy chill"}),
	["Enchant Weapon - Major Striking"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Major Striking", {"major striking", "7 dmg", "7 damage"}),
	["Enchant Weapon - Mighty Intellect"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Mighty Intellect", {"mighty intellect", "22 int", "22 intellect"}),
	["Enchant Weapon - Strength"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Strength", {"15 str", "15 strength"}),
	["Enchant Weapon - Superior Striking"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Superior Striking", {"superior striking", "5 dmg", "5 damage"}),
	["Enchant Weapon - Unholy Weapon"] = EC.BuildSpecificRecipeTagList("Enchant Weapon - Unholy Weapon", {"unholy weapon"}, {"unholy weapon"}),
	})),
}

EC.DefaultRecipeBlacklists = {
	enGB = langSplit({
	["Enchant 2H Weapon - Major Agility"] = "glove,gloves,hand,hands,cloak,back,boots,feet,chest,bracer,wrist,shield",
	["Enchant Gloves - Superior Agility"] = "weapon,wep,2h,staff,polearm,sword,axe,mace,dagger,bow,gun,crossbow,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Gloves - Major Healing"] = "weapon,wep,2h,staff,polearm,sword,axe,mace,dagger,bow,gun,crossbow,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Weapon - Major Healing"] = "glove,gloves,hand,hands,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Gloves - Major Spellpower"] = "weapon,wep,2h,staff,polearm,sword,axe,mace,dagger,bow,gun,crossbow,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Weapon - Major Spellpower"] = "glove,gloves,hand,hands,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Weapon - Spell Power"] = "glove,gloves,hand,hands,chest,bracer,wrist,cloak,back,boots,feet,shield",
	["Enchant Bracer - Spellpower"] = "weapon,wep,glove,gloves,hand,hands,chest,cloak,back,boots,feet,shield",
	["Enchant Bracer - Restore Mana Prime"] = "chest",
	["Enchant Chest - Restore Mana Prime"] = "bracer,wrist",
	["Enchant Chest - Major Resilience"] = "shield",
	["Enchant Shield - Resilience"] = "chest",
	}),
}
