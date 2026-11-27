--[[
	FolgaOt - Loja de jogador (comandos)

	!loja                    mostra a ajuda e a situacao da sua loja
	!loja abrir              coloca o seu vendedor no piso a sua frente (na cidade, em protection zone)
	!loja vender 500         poe a venda, por 500 gold cada, o item do slot da flecha (ammo)
	!loja vender 20 coins    o mesmo, mas cobrando em coins
	!loja itens              lista o que esta a venda
	!loja remover 2          devolve o item numero 2 da lista para a sua mochila
	!loja fechar             tira o vendedor do mapa e devolve os itens

	!coins                   mostra quantas coins voce tem
	/coins Nome, 100         (grupo God) da coins para a conta do jogador (use negativo para tirar)

	Taxa, limites e precos maximos ficam em data/lib/core/helblazer_loja.lua.
]]

local function ajuda(player)
	local guid = player:getGuid()
	local itens = Loja.itens(guid)
	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
		"Sua loja esta %s e tem %d de %d itens. Comandos: !loja abrir, !loja vender <preco> [coins], !loja itens, !loja remover <numero>, !loja fechar. " ..
		"O item a vender vai no slot da flecha. O servidor fica com %d%% de cada venda.",
		Loja.estaAberta(guid) and "ABERTA" or "fechada", #itens, HELBLAZER_LOJA.maxItens, HELBLAZER_LOJA.taxa))
end

local function abrir(player)
	local guid = player:getGuid()
	if Loja.estaAberta(guid) then
		return player:sendCancelMessage("Sua loja ja esta aberta. Use !loja fechar para mudar de lugar.")
	end
	if player:isPzLocked() then
		return player:sendCancelMessage("Voce nao pode abrir a loja com battle.")
	end

	local pos = player:getPosition()
	pos:getNextPosition(player:getDirection())
	local tile = Tile(pos)
	if not tile or not tile:hasFlag(TILESTATE_PROTECTIONZONE) or tile:getHouse()
			or tile:hasFlag(TILESTATE_FLOORCHANGE) or tile:hasFlag(TILESTATE_TELEPORT) or tile:getCreatureCount() > 0 then
		return player:sendCancelMessage("Vire para um piso livre da cidade (protection zone, fora de casas) e tente de novo.")
	end
	if pos == player:getTown():getTemplePosition() then
		return player:sendCancelMessage("A loja nao pode ficar no lugar onde os jogadores nascem.")
	end

	local o = player:getOutfit()
	local loja = {nome = player:getName(), x = pos.x, y = pos.y, z = pos.z, outfit = {
		lookType = o.lookType, lookHead = o.lookHead, lookBody = o.lookBody,
		lookLegs = o.lookLegs, lookFeet = o.lookFeet, lookAddons = o.lookAddons}}

	if not Loja.criarVendedor(loja) then
		return player:sendCancelMessage("Nao da para colocar a loja nesse piso.")
	end
	db.query(string.format("INSERT INTO `player_shops` (`player_id`, `posx`, `posy`, `posz`, `looktype`, `lookhead`, `lookbody`, `looklegs`, `lookfeet`, `lookaddons`) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
		guid, pos.x, pos.y, pos.z, o.lookType, o.lookHead, o.lookBody, o.lookLegs, o.lookFeet, o.lookAddons))

	pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
		"Sua loja esta aberta! O vendedor \"%s%s\" fica aqui vendendo, mesmo com voce offline. " ..
		"Os compradores falam hi e trade (gold) ou coins com ele.", HELBLAZER_LOJA.prefixo, player:getName()))
	if #Loja.itens(guid) == 0 then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Sua loja esta vazia. Coloque um item no slot da flecha e digite !loja vender <preco>.")
	end
end

local function vender(player, args)
	local preco = tonumber(args[2])
	local moeda = (args[3] and args[3]:lower() == "coins") and LOJA_COINS or LOJA_GOLD
	local precoMax = HELBLAZER_LOJA.precoMax[moeda]
	if not preco or preco ~= math.floor(preco) or preco < 1 or preco > precoMax then
		return player:sendCancelMessage(string.format("Use: !loja vender <preco> [coins]. Preco de 1 a %d %s por unidade.", precoMax, Loja.nomeMoeda(moeda)))
	end

	local item = player:getSlotItem(CONST_SLOT_AMMO)
	if not item then
		return player:sendCancelMessage("Coloque o item que quer vender no slot da flecha (ammo).")
	end
	local ok, motivo = Loja.podeVender(item)
	if not ok then
		return player:sendCancelMessage(motivo)
	end

	local guid = player:getGuid()
	local itemId, subtipo = item:getId(), Loja.subtipo(item)
	local quantidade = ItemType(itemId):isStackable() and item:getCount() or 1
	local existente = Loja.buscarItem(guid, itemId, moeda)

	if existente then
		if existente.subtype ~= subtipo then
			return player:sendCancelMessage("Voce ja vende esse item com outra carga/liquido. Remova o anterior primeiro.")
		end
		if not db.query(string.format("UPDATE `player_shop_items` SET `count` = `count` + %d, `price` = %d WHERE `id` = %d", quantidade, preco, existente.id)) then
			return player:sendCancelMessage("Erro ao salvar. Tente de novo.")
		end
		quantidade = existente.count + quantidade
	else
		if #Loja.itens(guid) >= HELBLAZER_LOJA.maxItens then
			return player:sendCancelMessage(string.format("Sua loja ja tem %d itens diferentes, o maximo.", HELBLAZER_LOJA.maxItens))
		end
		if not db.query(string.format("INSERT INTO `player_shop_items` (`player_id`, `itemid`, `subtype`, `count`, `price`, `currency`) VALUES (%d, %d, %d, %d, %d, %d)",
				guid, itemId, subtipo, quantidade, preco, moeda)) then
			return player:sendCancelMessage("Erro ao salvar. Tente de novo.")
		end
	end
	item:remove()

	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("A venda: %s por %d %s cada. Voce recebe %d%% de cada venda.",
		Loja.nomeItem(itemId, quantidade), preco, Loja.nomeMoeda(moeda), 100 - HELBLAZER_LOJA.taxa))
	if not Loja.estaAberta(guid) then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Sua loja esta fechada. Use !loja abrir para comecar a vender.")
	end
end

local function listar(player)
	local itens = Loja.itens(player:getGuid())
	if #itens == 0 then
		return player:sendTextMessage(MESSAGE_INFO_DESCR, "Sua loja nao tem itens. Use !loja vender <preco> com o item no slot da flecha.")
	end
	local linhas = {"Itens da sua loja:"}
	for i, row in ipairs(itens) do
		linhas[#linhas + 1] = string.format("%d) %s - %d %s cada", i, Loja.nomeItem(row.itemid, row.count), row.price, Loja.nomeMoeda(row.currency))
	end
	linhas[#linhas + 1] = "Para tirar um item: !loja remover <numero>"
	player:showTextDialog(ITEM_PARCEL, table.concat(linhas, "\n"))
end

-- Devolve os itens de uma linha da loja; retorna true se devolveu tudo
local function devolver(player, row)
	local entregue = Loja.entregar(player, row.itemid, row.subtype, row.count)
	if entregue > 0 then
		Loja.baixarEstoque(row, entregue)
	end
	return entregue == row.count, entregue
end

local function remover(player, args)
	local itens = Loja.itens(player:getGuid())
	local n = tonumber(args[2])
	local row = n and itens[n]
	if not row then
		return player:sendCancelMessage("Use: !loja remover <numero>. Veja os numeros com !loja itens.")
	end
	local tudo, entregue = devolver(player, row)
	if tudo then
		player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("%s voltou para voce.", Loja.nomeItem(row.itemid, entregue)))
	elseif entregue > 0 then
		player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Voltaram %d. O resto continua na loja: libere espaco e use !loja remover %d de novo.", entregue, n))
	else
		player:sendCancelMessage("Voce nao tem espaco ou capacidade para receber o item.")
	end
end

local function fechar(player)
	local guid = player:getGuid()
	if Loja.estaAberta(guid) then
		Loja.removerVendedor(player:getName())
		db.query("DELETE FROM `player_shops` WHERE `player_id` = " .. guid)
	end

	local faltou = 0
	for _, row in ipairs(Loja.itens(guid)) do
		if not devolver(player, row) then
			faltou = faltou + 1
		end
	end
	if faltou > 0 then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Loja fechada. Alguns itens nao couberam e continuam guardados: libere espaco e use !loja itens e !loja remover.")
	else
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Loja fechada. Os itens voltaram para voce.")
	end
end

local loja = TalkAction("!loja")

function loja.onSay(player, words, param)
	local args = {}
	for palavra in param:gmatch("%S+") do
		args[#args + 1] = palavra
	end
	local acao = args[1] and args[1]:lower() or ""

	if acao == "abrir" then
		abrir(player)
	elseif acao == "vender" then
		vender(player, args)
	elseif acao == "itens" or acao == "lista" then
		listar(player)
	elseif acao == "remover" or acao == "tirar" then
		remover(player, args)
	elseif acao == "fechar" then
		fechar(player)
	else
		ajuda(player)
	end
	return false
end

loja:separator(" ")
loja:register()

-- !coins: saldo de coins da conta
local coins = TalkAction("!coins")

function coins.onSay(player, words, param)
	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Sua conta tem %d coins.", Loja.getCoins(player:getAccountId())))
	return false
end

coins:register()

-- /coins Nome, quantidade (so o grupo God)
local darCoins = TalkAction("/coins")

function darCoins.onSay(player, words, param)
	-- grupo God (id 6 em data/XML/groups.xml), o mesmo que o criar-conta.sh --admin da
	if player:getGroup():getId() < 6 then
		return true
	end

	local nome, quantidade = param:match("^%s*(.-)%s*,%s*(-?%d+)%s*$")
	quantidade = tonumber(quantidade)
	if not nome or not quantidade then
		player:sendCancelMessage("Use: /coins Nome, quantidade")
		return false
	end

	local r = db.storeQuery("SELECT `account_id`, `name` FROM `players` WHERE `name` = " .. db.escapeString(nome))
	if not r then
		player:sendCancelMessage("Jogador nao encontrado.")
		return false
	end
	local conta, nomeReal = result.getNumber(r, "account_id"), result.getString(r, "name")
	result.free(r)

	if quantidade < 0 and Loja.getCoins(conta) < -quantidade then
		quantidade = -Loja.getCoins(conta)
	end
	Loja.addCoins(conta, quantidade)
	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("%s agora tem %d coins.", nomeReal, Loja.getCoins(conta)))

	local alvo = Player(nomeReal)
	if alvo and quantidade > 0 then
		alvo:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Voce recebeu %d coins. Saldo: %d coins.", quantidade, Loja.getCoins(conta)))
	end
	return false
end

darCoins:separator(" ")
darCoins:register()

-- Ao ligar o servidor: cria as tabelas (se faltarem) e recoloca os vendedores
local iniciar = GlobalEvent("HelblazerLojaStartup")

function iniciar.onStartup()
	Loja.instalar()
	local total = Loja.carregarTodas()
	if total > 0 then
		print(string.format(">> %d loja(s) de jogador carregada(s).", total))
	end
	return true
end

iniciar:register()

-- No login: avisa o que a loja vendeu enquanto o jogador estava offline
local avisoLogin = CreatureEvent("HelblazerLojaLogin")

function avisoLogin.onLogin(player)
	local guid = player:getGuid()
	local r = db.storeQuery("SELECT COUNT(*) AS `vendas`, SUM(CASE WHEN `currency` = 0 THEN `received` ELSE 0 END) AS `gold`, " ..
		"SUM(CASE WHEN `currency` = 1 THEN `received` ELSE 0 END) AS `coins` FROM `player_shop_sales` WHERE `player_id` = " .. guid .. " AND `notified` = 0")
	if r then
		local vendas, gold, coins = result.getNumber(r, "vendas"), result.getNumber(r, "gold"), result.getNumber(r, "coins")
		result.free(r)
		if vendas > 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
				"Enquanto voce estava fora, sua loja fez %d venda(s): %d gold (ja no banco) e %d coins.", vendas, gold, coins))
			db.query("UPDATE `player_shop_sales` SET `notified` = 1 WHERE `player_id` = " .. guid .. " AND `notified` = 0")
		end
	end
	return true
end

avisoLogin:register()
