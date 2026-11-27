-- Helblazer OT - vendedor da loja de jogador ("Loja de Fulano")
-- "trade" abre os itens vendidos em gold e "coins" os vendidos em coins.
-- A logica comum fica em data/lib/core/helblazer_loja.lua.
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local moedaDaJanela = {} -- cid -> moeda da janela aberta

local function saldo(player, moeda)
	if moeda == LOJA_COINS then
		return Loja.getCoins(player:getAccountId())
	end
	return player:getMoney() + player:getBankBalance()
end

-- O servidor chama onBuy com o objeto do jogador (nao com o id)
local function onBuy(comprador, itemId, subType, amount, ignoreCap, inBackpacks)
	local player = Player(comprador)
	local moeda = player and moedaDaJanela[player:getId()]
	local dono = Loja.donoDoVendedor(Npc():getName())
	if not player or not moeda or not dono then
		return
	end

	local row = Loja.buscarItem(dono.id, itemId, moeda)
	if not row then
		player:sendCancelMessage("Esse item acabou.")
		return
	end

	local quantidade = math.min(amount, row.count)
	local total = row.price * quantidade
	if saldo(player, moeda) < total then
		player:sendCancelMessage(string.format("Voce nao tem %d %s.", total, Loja.nomeMoeda(moeda)))
		return
	end

	local entregue = Loja.entregar(player, row.itemid, row.subtype, quantidade)
	if entregue == 0 then
		player:sendCancelMessage("Voce nao tem espaco ou capacidade para esse item.")
		return
	end

	total = row.price * entregue
	if moeda == LOJA_COINS then
		Loja.removeCoins(player:getAccountId(), total)
	else
		player:removeTotalMoney(total)
	end
	Loja.baixarEstoque(row, entregue)

	local recebido = total - math.floor(total * HELBLAZER_LOJA.taxa / 100)
	Loja.creditar(dono, recebido, moeda)

	local nomeItem = Loja.nomeItem(row.itemid, entregue)
	local vendedor = Player(dono.nome)
	if vendedor then
		vendedor:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
			"Sua loja vendeu %s para %s. Voce recebeu %d %s (taxa de %d%%).",
			nomeItem, player:getName(), recebido, Loja.nomeMoeda(moeda), HELBLAZER_LOJA.taxa))
	end
	Loja.registrarVenda(dono, player:getName(), row.itemid, entregue, total, recebido, moeda, vendedor ~= nil)

	local msg = string.format("Voce comprou %s por %d %s.", nomeItem, total, Loja.nomeMoeda(moeda))
	if entregue < amount then
		msg = msg .. (entregue < quantidade and " O resto nao coube." or string.format(" So havia %d no estoque.", row.count))
	end
	player:sendTextMessage(MESSAGE_INFO_DESCR, msg)
	player:setShopMoney(saldo(player, moeda))
end

local function abrirJanela(cid, moeda)
	if not npcHandler:isFocused(cid) then
		return false
	end
	local player = Player(cid)
	local dono = Loja.donoDoVendedor(Npc():getName())
	if not dono then
		npcHandler:say("Esta loja esta fechada.", cid)
		return true
	end
	if dono.id == player:getGuid() then
		npcHandler:say("Esta e a sua loja. Use !loja itens para ver o que esta a venda.", cid)
		return true
	end

	local lista = {}
	for _, row in ipairs(Loja.itens(dono.id, moeda)) do
		lista[#lista + 1] = {
			id = row.itemid, subType = row.subtype, buy = row.price, sell = 0,
			name = string.format("%s (%d)", ItemType(row.itemid):getName(), row.count),
		}
	end
	if #lista == 0 then
		npcHandler:say(string.format("Nao ha itens a venda em %s no momento.", Loja.nomeMoeda(moeda)), cid)
		return true
	end

	moedaDaJanela[cid] = moeda
	openShopWindow(cid, lista, onBuy, nil)
	player:setShopMoney(saldo(player, moeda))
	if moeda == LOJA_COINS then
		npcHandler:say(string.format("Precos em coins. Voce tem %d coins. O numero entre parenteses e o estoque.", Loja.getCoins(player:getAccountId())), cid)
	else
		npcHandler:say("Precos em gold (mochila ou banco). O numero entre parenteses e o estoque.", cid)
	end
	return true
end

keywordHandler:addKeyword({"trade"}, function(cid) return abrirJanela(cid, LOJA_GOLD) end)
keywordHandler:addKeyword({"gold"}, function(cid) return abrirJanela(cid, LOJA_GOLD) end)
keywordHandler:addKeyword({"comprar"}, function(cid) return abrirJanela(cid, LOJA_GOLD) end)
keywordHandler:addKeyword({"coins"}, function(cid) return abrirJanela(cid, LOJA_COINS) end)

npcHandler:setMessage(MESSAGE_GREET, "Ola, |PLAYERNAME|! Diga {trade} para ver os itens em gold ou {coins} para os itens em coins.")
npcHandler:setMessage(MESSAGE_FAREWELL, "Volte sempre, |PLAYERNAME|.")
npcHandler:setMessage(MESSAGE_WALKAWAY, "Volte sempre.")
npcHandler:addModule(FocusModule:new())
