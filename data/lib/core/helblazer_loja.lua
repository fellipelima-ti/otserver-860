--[[
	Helblazer OT - Loja de jogador

	O jogador abre uma loja na cidade e um vendedor com a roupa dele ("Loja de Fulano")
	fica parado vendendo, com o dono online ou offline. Quem compra fala "hi" e "trade"
	(gold) ou "coins" com o vendedor e usa a janela de trade de NPC do 8.60.

	Usado pelo comando !loja (data/scripts/helblazer/loja.lua) e pelo NPC
	(data/npc/scripts/loja.lua). Os dados ficam no banco:
	  player_shops       - lojas abertas (posicao e roupa do vendedor)
	  player_shop_items  - itens a venda (ficam guardados mesmo com a loja fechada)
	  player_shop_sales  - historico de vendas (avisa o vendedor no login)
	  accounts.coins     - saldo de coins da conta
]]

HELBLAZER_LOJA = {
	npc = "Loja",               -- arquivo data/npc/Loja.xml
	prefixo = "Loja de ",       -- nome do vendedor: "Loja de Fulano"
	taxa = 10,                  -- % que o servidor fica de cada venda
	maxItens = 20,              -- itens diferentes por loja
	precoMax = {[0] = 100000000, [1] = 1000000}, -- preco maximo por unidade (gold, coins)
}

LOJA_GOLD = 0
LOJA_COINS = 1

Loja = {}

function Loja.nomeMoeda(moeda)
	return moeda == LOJA_COINS and "coins" or "gold"
end

function Loja.nomeItem(itemId, count)
	local it = ItemType(itemId)
	if count and count > 1 then
		local plural = it:getPluralName()
		return string.format("%dx %s", count, plural ~= "" and plural or it:getName())
	end
	return it:getName()
end

-- Cria as tabelas e a coluna de coins (seguro rodar a cada inicializacao)
function Loja.instalar()
	db.query([[CREATE TABLE IF NOT EXISTS `player_shops` (
		`player_id` int NOT NULL,
		`posx` int NOT NULL, `posy` int NOT NULL, `posz` int NOT NULL,
		`looktype` int NOT NULL DEFAULT 128, `lookhead` int NOT NULL DEFAULT 0,
		`lookbody` int NOT NULL DEFAULT 0, `looklegs` int NOT NULL DEFAULT 0,
		`lookfeet` int NOT NULL DEFAULT 0, `lookaddons` int NOT NULL DEFAULT 0,
		PRIMARY KEY (`player_id`),
		FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8]])
	db.query([[CREATE TABLE IF NOT EXISTS `player_shop_items` (
		`id` int NOT NULL AUTO_INCREMENT,
		`player_id` int NOT NULL,
		`itemid` int NOT NULL, `subtype` int NOT NULL DEFAULT 0,
		`count` int NOT NULL, `price` int unsigned NOT NULL,
		`currency` tinyint NOT NULL DEFAULT 0,
		PRIMARY KEY (`id`), KEY `player_id` (`player_id`),
		FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8]])
	db.query([[CREATE TABLE IF NOT EXISTS `player_shop_sales` (
		`id` int NOT NULL AUTO_INCREMENT,
		`player_id` int NOT NULL, `buyer` varchar(255) NOT NULL,
		`itemid` int NOT NULL, `count` int NOT NULL,
		`total` bigint unsigned NOT NULL, `received` bigint unsigned NOT NULL,
		`currency` tinyint NOT NULL DEFAULT 0,
		`date` bigint NOT NULL, `notified` tinyint NOT NULL DEFAULT 0,
		PRIMARY KEY (`id`), KEY `player_id` (`player_id`),
		FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8]])

	local r = db.storeQuery("SELECT 1 FROM `information_schema`.`columns` WHERE `table_schema` = DATABASE() AND `table_name` = 'accounts' AND `column_name` = 'coins'")
	if r then
		result.free(r)
	else
		db.query("ALTER TABLE `accounts` ADD `coins` int unsigned NOT NULL DEFAULT 0")
	end
end

-- ===================== coins (guardadas na conta) =====================

function Loja.getCoins(accountId)
	local r = db.storeQuery("SELECT `coins` FROM `accounts` WHERE `id` = " .. accountId)
	if not r then
		return 0
	end
	local coins = result.getNumber(r, "coins")
	result.free(r)
	return coins
end

function Loja.addCoins(accountId, quantidade)
	return db.query(string.format("UPDATE `accounts` SET `coins` = `coins` + %d WHERE `id` = %d", quantidade, accountId))
end

function Loja.removeCoins(accountId, quantidade)
	if Loja.getCoins(accountId) < quantidade then
		return false
	end
	return db.query(string.format("UPDATE `accounts` SET `coins` = `coins` - %d WHERE `id` = %d AND `coins` >= %d", quantidade, accountId, quantidade))
end

-- ===================== lojas e itens =====================

function Loja.estaAberta(playerId)
	local r = db.storeQuery("SELECT 1 FROM `player_shops` WHERE `player_id` = " .. playerId)
	if r then
		result.free(r)
		return true
	end
	return false
end

-- Itens a venda, em ordem fixa (o numero usado no !loja remover)
function Loja.itens(playerId, moeda)
	local filtro = moeda and (" AND `currency` = " .. moeda) or ""
	local lista = {}
	local r = db.storeQuery("SELECT `id`, `itemid`, `subtype`, `count`, `price`, `currency` FROM `player_shop_items` WHERE `player_id` = " .. playerId .. filtro .. " ORDER BY `id`")
	if r then
		repeat
			lista[#lista + 1] = {
				id = result.getNumber(r, "id"),
				itemid = result.getNumber(r, "itemid"),
				subtype = result.getNumber(r, "subtype"),
				count = result.getNumber(r, "count"),
				price = result.getNumber(r, "price"),
				currency = result.getNumber(r, "currency"),
			}
		until not result.next(r)
		result.free(r)
	end
	return lista
end

function Loja.buscarItem(playerId, itemId, moeda)
	for _, row in ipairs(Loja.itens(playerId, moeda)) do
		if row.itemid == itemId then
			return row
		end
	end
	return nil
end

function Loja.baixarEstoque(row, quantidade)
	if quantidade >= row.count then
		db.query("DELETE FROM `player_shop_items` WHERE `id` = " .. row.id)
	else
		db.query(string.format("UPDATE `player_shop_items` SET `count` = `count` - %d WHERE `id` = %d", quantidade, row.id))
	end
end

-- Dono da loja a partir do nome do vendedor ("Loja de Fulano")
function Loja.donoDoVendedor(nomeNpc)
	local prefixo = HELBLAZER_LOJA.prefixo
	if nomeNpc:sub(1, #prefixo) ~= prefixo then
		return nil
	end
	local r = db.storeQuery("SELECT `p`.`id`, `p`.`name`, `p`.`account_id` FROM `players` `p` INNER JOIN `player_shops` `s` ON `s`.`player_id` = `p`.`id` WHERE `p`.`name` = " .. db.escapeString(nomeNpc:sub(#prefixo + 1)))
	if not r then
		return nil
	end
	local dono = {id = result.getNumber(r, "id"), nome = result.getString(r, "name"), conta = result.getNumber(r, "account_id")}
	result.free(r)
	return dono
end

-- Item pode ir para a loja? (so itens "comuns": sem texto, ids, tempo ou conteudo)
function Loja.podeVender(item)
	local it = ItemType(item:getId())
	if not it:isMovable() or not it:isPickupable() then
		return false, "Esse item nao pode ser vendido."
	end
	if it:getId() == ITEM_GOLD_COIN or it:getId() == ITEM_PLATINUM_COIN or it:getId() == ITEM_CRYSTAL_COIN then
		return false, "Dinheiro nao pode ser vendido na loja."
	end
	for _, attr in ipairs({ITEM_ATTRIBUTE_ACTIONID, ITEM_ATTRIBUTE_UNIQUEID, ITEM_ATTRIBUTE_TEXT, ITEM_ATTRIBUTE_WRITER,
			ITEM_ATTRIBUTE_DESCRIPTION, ITEM_ATTRIBUTE_NAME, ITEM_ATTRIBUTE_DURATION, ITEM_ATTRIBUTE_DECAYSTATE}) do
		if item:hasAttribute(attr) then
			return false, "Esse item tem algo especial (texto, tempo de uso ou marca) e nao pode ir para a loja."
		end
	end
	if item:isContainer() and item:getSize() > 0 then
		return false, "Esvazie o container antes de vender."
	end
	return true
end

-- Subtipo guardado: carga de runas e liquido de frascos (stackables usam a quantidade)
function Loja.subtipo(item)
	local it = ItemType(item:getId())
	if it:isStackable() then
		return 0
	end
	return item:getSubType()
end

-- Entrega `quantidade` unidades de um item ao jogador. Retorna quantas couberam.
function Loja.entregar(player, itemId, subtipo, quantidade)
	local it = ItemType(itemId)
	local entregue = 0
	while entregue < quantidade do
		local item
		if it:isStackable() then
			item = Game.createItem(itemId, math.min(100, quantidade - entregue))
		else
			item = Game.createItem(itemId, subtipo > 0 and subtipo or nil)
		end
		if not item then
			break
		end
		local n = it:isStackable() and item:getCount() or 1
		if player:addItemEx(item) ~= RETURNVALUE_NOERROR then
			item:remove()
			break
		end
		entregue = entregue + n
	end
	return entregue
end

-- Credita o vendedor: gold vai para o banco, coins para a conta
function Loja.creditar(dono, valor, moeda)
	if valor <= 0 then
		return
	end
	if moeda == LOJA_COINS then
		Loja.addCoins(dono.conta, valor)
		return
	end
	local online = Player(dono.nome)
	if online then
		online:setBankBalance(online:getBankBalance() + valor)
	else
		db.query(string.format("UPDATE `players` SET `balance` = `balance` + %d WHERE `id` = %d", valor, dono.id))
	end
end

function Loja.registrarVenda(dono, comprador, itemId, quantidade, total, recebido, moeda, avisado)
	db.query(string.format("INSERT INTO `player_shop_sales` (`player_id`, `buyer`, `itemid`, `count`, `total`, `received`, `currency`, `date`, `notified`) VALUES (%d, %s, %d, %d, %d, %d, %d, %d, %d)",
		dono.id, db.escapeString(comprador), itemId, quantidade, total, recebido, moeda, os.time(), avisado and 1 or 0))
end

-- Cria o vendedor no mapa. `loja` = {nome, x, y, z, outfit}
function Loja.criarVendedor(loja)
	local npc = Game.createNpc(HELBLAZER_LOJA.npc, Position(loja.x, loja.y, loja.z), false, true, HELBLAZER_LOJA.prefixo .. loja.nome)
	if npc then
		npc:setOutfit(loja.outfit)
		npc:setDirection(DIRECTION_SOUTH)
	end
	return npc
end

function Loja.removerVendedor(nomeDono)
	local npc = Npc(HELBLAZER_LOJA.prefixo .. nomeDono)
	if npc then
		npc:remove()
	end
end

-- Recria todos os vendedores (ao ligar o servidor)
function Loja.carregarTodas()
	local total = 0
	local r = db.storeQuery("SELECT `p`.`name`, `s`.* FROM `player_shops` `s` INNER JOIN `players` `p` ON `p`.`id` = `s`.`player_id`")
	if not r then
		return total
	end
	repeat
		local loja = {
			nome = result.getString(r, "name"),
			x = result.getNumber(r, "posx"), y = result.getNumber(r, "posy"), z = result.getNumber(r, "posz"),
			outfit = {
				lookType = result.getNumber(r, "looktype"), lookHead = result.getNumber(r, "lookhead"),
				lookBody = result.getNumber(r, "lookbody"), lookLegs = result.getNumber(r, "looklegs"),
				lookFeet = result.getNumber(r, "lookfeet"), lookAddons = result.getNumber(r, "lookaddons"),
			},
		}
		if Loja.criarVendedor(loja) then
			total = total + 1
		else
			print(string.format(">> [Loja] Nao foi possivel colocar a loja de %s em %d, %d, %d.", loja.nome, loja.x, loja.y, loja.z))
		end
	until not result.next(r)
	result.free(r)
	return total
end
