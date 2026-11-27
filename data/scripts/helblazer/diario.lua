--[[
	FolgaOt - Recompensa diaria
	!diario uma vez por dia. Dias seguidos aumentam o premio (tabela HELBLAZER_DIARIO em
	data/lib/core/helblazer_sistemas.lua). Se passar um dia sem pegar, a sequencia volta ao dia 1.
]]

local S = HELBLAZER_STORAGE

local function proximoDia(player)
	local hoje = helblazerDia()
	local ultimo = player:getStorageValue(S.diarioDia)
	local sequencia = math.max(0, player:getStorageValue(S.diarioSequencia))
	if ultimo == hoje then
		return nil, sequencia
	end
	if ultimo ~= hoje - 1 then
		sequencia = 0
	end
	return sequencia % #HELBLAZER_DIARIO + 1, sequencia + 1
end

local diario = TalkAction("!diario")

function diario.onSay(player, words, param)
	local dia, sequencia = proximoDia(player)
	if not dia then
		player:sendCancelMessage(string.format("Voce ja pegou a recompensa de hoje (%d dia(s) seguidos). Volte amanha!", sequencia))
		return false
	end

	local premio = HELBLAZER_DIARIO[dia]
	player:setStorageValue(S.diarioDia, helblazerDia())
	player:setStorageValue(S.diarioSequencia, sequencia)
	local texto = player:helblazerRecompensa(0, premio.gold, premio.coins, premio.pocoes)
	player:getPosition():sendMagicEffect(CONST_ME_GIFT_WRAPS)

	local proximo = HELBLAZER_DIARIO[dia % #HELBLAZER_DIARIO + 1]
	local partesProximo = {}
	if proximo.gold then partesProximo[#partesProximo + 1] = proximo.gold .. " gold" end
	if proximo.pocoes then partesProximo[#partesProximo + 1] = proximo.pocoes .. " pocoes" end
	if proximo.coins then partesProximo[#partesProximo + 1] = proximo.coins .. " coins" end
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Recompensa diaria (dia %d de %d): %s. Amanha: %s.", dia, #HELBLAZER_DIARIO, texto, table.concat(partesProximo, " e ")))
	return false
end

diario:register()

local login = CreatureEvent("HelblazerDiarioLogin")

function login.onLogin(player)
	if proximoDia(player) then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Sua recompensa diaria esta disponivel! Digite !diario.")
	end
	return true
end

login:register()
