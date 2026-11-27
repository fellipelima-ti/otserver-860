-- Helblazer OT - The Forgotten King: 1a e 2a promocao (sem premium)
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

function onCreatureAppear(cid)              npcHandler:onCreatureAppear(cid)            end
function onCreatureDisappear(cid)           npcHandler:onCreatureDisappear(cid)         end
function onCreatureSay(cid, type, msg)      npcHandler:onCreatureSay(cid, type, msg)    end
function onThink()                          npcHandler:onThink()                        end

local function oferecer(cid, message, keywords, parameters, node)
	if not npcHandler:isFocused(cid) then
		return false
	end
	local player = Player(cid)
	local proxima, etapa, cfg = player:helblazerProximaPromocao()
	if not proxima then
		npcHandler:say("Voce ja alcancou a promocao maxima. Nao ha mais nada que eu possa fazer por voce.", cid)
		npcHandler:resetNpc(cid)
		return false
	end
	npcHandler:say(string.format("Posso te tornar {%s} por %d gold. Voce precisa ser level %d. Aceita?", proxima:getName(), cfg.preco, cfg.level), cid)
	return true
end

local function promover(cid, message, keywords, parameters, node)
	if not npcHandler:isFocused(cid) then
		return false
	end
	local _, msg = Player(cid):helblazerPromover()
	npcHandler:say(msg, cid)
	npcHandler:resetNpc(cid)
	return true
end

for _, palavra in ipairs({"promot", "promocao", "promover"}) do
	local node = keywordHandler:addKeyword({palavra}, oferecer)
	node:addChildKeyword({"yes"}, promover)
	node:addChildKeyword({"sim"}, promover)
	node:addChildKeyword({"no"}, StdModule.say, {npcHandler = npcHandler, onlyFocus = true, text = "Volte quando estiver pronto.", reset = true})
	node:addChildKeyword({"nao"}, StdModule.say, {npcHandler = npcHandler, onlyFocus = true, text = "Volte quando estiver pronto.", reset = true})
end

npcHandler:setMessage(MESSAGE_GREET, "Saudacoes, |PLAYERNAME|. Eu posso te dar uma {promocao}.")
npcHandler:addModule(FocusModule:new())
