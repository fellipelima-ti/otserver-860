--[[
	FolgaOt - Criatura do dia
	Todo dia um monstro de HELBLAZER_BOOSTED (data/lib/core/helblazer_sistemas.lua) da mais
	experiencia e tem o loot sorteado duas vezes. O sorteio muda a meia-noite.
	!boosted mostra a criatura de hoje; ela tambem e anunciada no login.
]]

local function anuncio()
	local b = HELBLAZER_BOOSTED
	return string.format("Criatura do dia: %s (+%d%% de experiencia%s). Digite !boosted para ver de novo.",
		helblazerBoostedHoje(), b.bonusExp, b.lootExtra and " e loot em dobro" or "")
end

local boosted = TalkAction("!boosted")

function boosted.onSay(player, words, param)
	player:sendTextMessage(MESSAGE_INFO_DESCR, anuncio())
	return false
end

boosted:register()

local login = CreatureEvent("HelblazerBoostedLogin")

function login.onLogin(player)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, anuncio())
	return true
end

login:register()

-- Experiencia extra
local exp = EventCallback

exp.onGainExperience = function(player, source, experiencia, rawExp)
	if source and source:isMonster() and helblazerEhBoosted(source:getName()) then
		return experiencia * (1 + HELBLAZER_BOOSTED.bonusExp / 100)
	end
	return experiencia
end

exp:register()

-- Loot extra: roda antes do loot normal (indice -1), entao a mensagem "Loot of ..." ja mostra tudo
local loot = EventCallback

loot.onDropLoot = function(monster, corpse)
	if not HELBLAZER_BOOSTED.lootExtra or configManager.getNumber(configKeys.RATE_LOOT) == 0 then
		return
	end
	if not helblazerEhBoosted(monster:getName()) then
		return
	end
	local player = Player(corpse:getCorpseOwner())
	if player and player:getStamina() <= 840 then
		return
	end
	for _, lootItem in ipairs(monster:getType():getLoot()) do
		corpse:createLootItem(lootItem)
	end
end

loot:register(-1)

-- Anuncia a nova criatura quando o dia vira
local virada = GlobalEvent("HelblazerBoostedVirada")
local ultimoDia = nil

function virada.onThink(interval)
	local hoje = helblazerDia()
	if ultimoDia and ultimoDia ~= hoje then
		Game.broadcastMessage(anuncio(), MESSAGE_STATUS_WARNING)
	end
	ultimoDia = hoje
	return true
end

virada:interval(60000)
virada:register()
