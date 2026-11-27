--[[
	FolgaOt - Sistema de Teleportes

	1) PORTAIS FISICOS: criados automaticamente no mapa toda vez que o servidor liga.
	   Para adicionar um portal, coloque uma linha em HELBLAZER_PORTAIS.
	   "de" = onde o portal aparece | "para" = onde o jogador vai.
	   Use o comando !pos dentro do jogo para descobrir coordenadas.

	2) COMANDO !tp: "!tp" mostra a lista, "!tp jorvik" teleporta.
	   So funciona dentro de protection zone (templo/depot) e sem battle,
	   para ninguem usar como fuga de PvP.
]]

local TELEPORT_ITEM = 1387 -- magic forcefield (portal azul)

local TREKOLT = Position(95, 117, 7)
local RHYVES  = Position(159, 387, 6)
local VARAK   = Position(242, 429, 12)
local JORVIK  = Position(496, 172, 7)
local SAUND   = Position(240, 566, 7)

HELBLAZER_PORTAIS = {
	-- Templo de Trekolt -> outras cidades
	{ nome = "Rhyves", de = Position(92, 114, 7),  para = RHYVES },
	{ nome = "Varak",  de = Position(92, 117, 7),  para = VARAK },
	{ nome = "Jorvik", de = Position(92, 120, 7),  para = JORVIK },
	{ nome = "Saund",  de = Position(93, 114, 7),  para = SAUND },
	-- Volta para Trekolt
	{ nome = "Trekolt", de = Position(158, 389, 6), para = TREKOLT },
	{ nome = "Trekolt", de = Position(240, 428, 12), para = TREKOLT },
	{ nome = "Trekolt", de = Position(493, 169, 7), para = TREKOLT },
	{ nome = "Trekolt", de = Position(237, 563, 7), para = TREKOLT },
}

-- Destinos do comando !tp. "level" = level minimo. "preco" = custo em gold (0 = gratis).
HELBLAZER_DESTINOS = {
	-- Cidades
	{ nome = "trekolt",  pos = TREKOLT, level = 1,   preco = 0 },
	{ nome = "rhyves",   pos = RHYVES,  level = 1,   preco = 0 },
	{ nome = "varak",    pos = VARAK,   level = 1,   preco = 0 },
	{ nome = "jorvik",   pos = JORVIK,  level = 1,   preco = 0 },
	{ nome = "saund",    pos = SAUND,   level = 1,   preco = 0 },
	-- Hunts
	{ nome = "trolls",   pos = Position(41, 97, 8),    level = 8,   preco = 0 },
	{ nome = "rotworms", pos = Position(211, 386, 8),  level = 8,   preco = 0 },
	{ nome = "orcs",     pos = Position(241, 355, 7),  level = 15,  preco = 0 },
	{ nome = "amazons",  pos = Position(261, 521, 7),  level = 25,  preco = 100 },
	{ nome = "ghouls",   pos = Position(113, 475, 10), level = 30,  preco = 100 },
	{ nome = "cyclops",  pos = Position(206, 485, 6),  level = 40,  preco = 200 },
	{ nome = "spiders",  pos = Position(148, 519, 7),  level = 60,  preco = 300 },
	{ nome = "dragons",  pos = Position(151, 577, 6),  level = 70,  preco = 500 },
	{ nome = "vampires", pos = Position(146, 488, 13), level = 80,  preco = 500 },
	{ nome = "demons",   pos = Position(193, 649, 13), level = 130, preco = 1000 },
}

-- ===================== Portais fisicos =====================
local portais = GlobalEvent("HelblazerPortais")

function portais.onStartup()
	local criados = 0
	for _, cfg in ipairs(HELBLAZER_PORTAIS) do
		local tile = Tile(cfg.de)
		if not tile or not tile:getGround() then
			print(string.format("[FolgaOt] Portal '%s' ignorado: tile invalido em %d,%d,%d", cfg.nome, cfg.de.x, cfg.de.y, cfg.de.z))
		elseif not Tile(cfg.para) then
			print(string.format("[FolgaOt] Portal '%s' ignorado: destino invalido", cfg.nome))
		else
			local item = Game.createItem(TELEPORT_ITEM, 1, cfg.de)
			local tp = item and Teleport(item.uid)
			if tp then
				tp:setDestination(cfg.para)
				tp:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "Portal para " .. cfg.nome .. ".")
				criados = criados + 1
			end
		end
	end
	print(string.format(">> FolgaOt: %d portais criados", criados))
	return true
end

portais:register()

-- ===================== Comando !tp =====================
local function listaDestinos()
	local nomes = {}
	for _, d in ipairs(HELBLAZER_DESTINOS) do
		local info = {}
		if d.level > 1 then info[#info + 1] = "lv" .. d.level end
		if d.preco > 0 then info[#info + 1] = d.preco .. "gp" end
		nomes[#nomes + 1] = d.nome .. (#info > 0 and (" (" .. table.concat(info, ", ") .. ")") or "")
	end
	return table.concat(nomes, ", ")
end

local tpCmd = TalkAction("!tp")

function tpCmd.onSay(player, words, param)
	param = param:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if param == "" then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Use: !tp <destino>. Destinos: " .. listaDestinos())
		return false
	end

	local destino
	for _, d in ipairs(HELBLAZER_DESTINOS) do
		if d.nome == param then destino = d break end
	end
	if not destino then
		player:sendCancelMessage("Destino nao encontrado. Digite !tp para ver a lista.")
		return false
	end

	if not player:getGroup():getAccess() then
		if player:isPzLocked() or player:getCondition(CONDITION_INFIGHT, CONDITIONID_DEFAULT) then
			player:sendCancelMessage("Voce nao pode se teleportar com battle.")
			return false
		end
		if not Tile(player:getPosition()):hasFlag(TILESTATE_PROTECTIONZONE) then
			player:sendCancelMessage("Voce precisa estar em uma protection zone (templo ou depot).")
			return false
		end
		if player:getLevel() < destino.level then
			player:sendCancelMessage("Voce precisa ser level " .. destino.level .. " para ir para " .. destino.nome .. ".")
			return false
		end
		if destino.preco > 0 and not player:removeMoney(destino.preco) then
			player:sendCancelMessage("Voce precisa de " .. destino.preco .. " gold para ir para " .. destino.nome .. ".")
			return false
		end
	end

	player:getPosition():sendMagicEffect(CONST_ME_POFF)
	player:teleportTo(destino.pos)
	destino.pos:sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MESSAGE_INFO_DESCR, "Voce foi teleportado para " .. destino.nome .. ".")
	return false
end

tpCmd:separator(" ")
tpCmd:register()
