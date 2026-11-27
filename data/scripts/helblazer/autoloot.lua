--[[
	FolgaOt - Autoloot
	Quando um monstro morre, os itens da sua lista saem do corpo e vao direto para a sua mochila.

	!autoloot                      mostra a lista e a ajuda
	!autoloot add dragon ham       poe um item na lista (pelo nome, em ingles, como aparece no jogo)
	!autoloot remove dragon ham    tira um item da lista
	!autoloot gold                 liga/desliga: moedas do loot vao direto para o banco
	!autoloot limpar               esvazia a lista

	So vale para o dono do loot (quem causou mais dano) e se ele estiver perto do monstro.
	Limites em data/lib/core/helblazer_sistemas.lua (HELBLAZER_AUTOLOOT).
]]

local S = HELBLAZER_STORAGE
local MOEDAS = {[ITEM_GOLD_COIN] = true, [ITEM_PLATINUM_COIN] = true, [ITEM_CRYSTAL_COIN] = true}

local function lista(player)
	local itens = {}
	for i = 0, HELBLAZER_AUTOLOOT.maxItens - 1 do
		local id = player:getStorageValue(S.autolootItens + i)
		if id > 0 then
			itens[#itens + 1] = {slot = i, id = id}
		end
	end
	return itens
end

local function goldLigado(player)
	return player:getStorageValue(S.autolootGold) == 1
end

local function mostrar(player)
	local nomes = {}
	for _, it in ipairs(lista(player)) do
		nomes[#nomes + 1] = ItemType(it.id):getName()
	end
	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
		"Autoloot (%d/%d): %s. Gold para o banco: %s. Comandos: !autoloot add <item>, !autoloot remove <item>, !autoloot gold, !autoloot limpar.",
		#nomes, HELBLAZER_AUTOLOOT.maxItens, #nomes > 0 and table.concat(nomes, ", ") or "vazia",
		goldLigado(player) and "ligado" or "desligado"))
end

local function acharItem(nome)
	local it = ItemType(nome)
	if not it or it:getId() == 0 then
		return nil
	end
	return it
end

local comando = TalkAction("!autoloot")

function comando.onSay(player, words, param)
	local acao, resto = param:match("^%s*(%S*)%s*(.-)%s*$")
	acao = (acao or ""):lower()

	if acao == "add" or acao == "adicionar" then
		local it = acharItem(resto)
		if not it then
			player:sendCancelMessage("Item nao encontrado. Use o nome em ingles, como aparece no jogo (ex.: !autoloot add dragon ham).")
			return false
		end
		if not it:isPickupable() or MOEDAS[it:getId()] then
			player:sendCancelMessage(MOEDAS[it:getId()] and "Para o gold use !autoloot gold." or "Esse item nao pode ser pego.")
			return false
		end
		local livre
		for i = 0, HELBLAZER_AUTOLOOT.maxItens - 1 do
			local id = player:getStorageValue(S.autolootItens + i)
			if id == it:getId() then
				player:sendCancelMessage("Esse item ja esta na lista.")
				return false
			end
			if id <= 0 and not livre then
				livre = i
			end
		end
		if not livre then
			player:sendCancelMessage(string.format("Sua lista ja tem %d itens, o maximo.", HELBLAZER_AUTOLOOT.maxItens))
			return false
		end
		player:setStorageValue(S.autolootItens + livre, it:getId())
		player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("%s entrou no autoloot.", it:getName()))
	elseif acao == "remove" or acao == "remover" or acao == "tirar" then
		local it = acharItem(resto)
		for _, item in ipairs(lista(player)) do
			if it and item.id == it:getId() then
				player:setStorageValue(S.autolootItens + item.slot, -1)
				player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("%s saiu do autoloot.", it:getName()))
				return false
			end
		end
		player:sendCancelMessage("Esse item nao esta na sua lista.")
	elseif acao == "gold" then
		local ligar = not goldLigado(player)
		player:setStorageValue(S.autolootGold, ligar and 1 or 0)
		player:sendTextMessage(MESSAGE_INFO_DESCR, ligar and "Gold do loot agora vai direto para o banco." or "Gold do loot voltou a ficar no corpo.")
	elseif acao == "limpar" then
		for _, item in ipairs(lista(player)) do
			player:setStorageValue(S.autolootItens + item.slot, -1)
		end
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Lista do autoloot esvaziada.")
	else
		mostrar(player)
	end
	return false
end

comando:separator(" ")
comando:register()

-- Coleta: roda depois do loot normal (indice 10)
local coleta = EventCallback

coleta.onDropLoot = function(monster, corpse)
	local player = Player(corpse:getCorpseOwner())
	if not player then
		return
	end

	local querGold = goldLigado(player)
	local quer = {}
	local temLista = false
	for _, it in ipairs(lista(player)) do
		quer[it.id] = true
		temLista = true
	end
	if not temLista and not querGold then
		return
	end

	local pPos, mPos = player:getPosition(), corpse:getPosition()
	if pPos.z ~= mPos.z or math.max(math.abs(pPos.x - mPos.x), math.abs(pPos.y - mPos.y)) > HELBLAZER_AUTOLOOT.distancia then
		return
	end

	local coletados, gold, cheio = {}, 0, false
	-- de tras para frente, porque os itens saem do corpo durante o laco
	for i = corpse:getSize() - 1, 0, -1 do
		local item = corpse:getItem(i)
		if item then
			local id = item:getId()
			if querGold and MOEDAS[id] then
				gold = gold + item:getCount() * ItemType(id):getWorth()
				item:remove()
			elseif quer[id] and not cheio then
				local copia = item:clone()
				if player:addItemEx(copia) == RETURNVALUE_NOERROR then
					coletados[#coletados + 1] = item:getCount() > 1 and string.format("%d %s", item:getCount(), ItemType(id):getPluralName()) or ItemType(id):getName()
					item:remove()
				else
					copia:remove()
					cheio = true
				end
			end
		end
	end

	if gold > 0 then
		player:setBankBalance(player:getBankBalance() + gold)
	end
	if #coletados > 0 or gold > 0 or cheio then
		local partes = {}
		if #coletados > 0 then
			partes[#partes + 1] = table.concat(coletados, ", ")
		end
		if gold > 0 then
			partes[#partes + 1] = string.format("%d gold para o banco", gold)
		end
		local msg = "[Autoloot] " .. (#partes > 0 and table.concat(partes, " e ") or "nada")
		if cheio then
			msg = msg .. " (mochila cheia ou sem capacidade: o resto ficou no corpo)"
		end
		player:sendTextMessage(MESSAGE_INFO_DESCR, msg .. ".")
	end
end

coleta:register(10)
