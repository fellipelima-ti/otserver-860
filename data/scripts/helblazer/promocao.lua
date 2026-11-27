--[[
	FolgaOt - comando !promote
	"!promote"     mostra qual e a proxima promocao, o level e o preco
	"!promote sim" faz a promocao (cobra da mochila ou do banco)
	Level e preco ficam em data/lib/core/helblazer.lua (HELBLAZER_PROMOCOES).
]]

local promote = TalkAction("!promote")

function promote.onSay(player, words, param)
	local proxima, etapa, cfg = player:helblazerProximaPromocao()
	if not proxima then
		player:sendCancelMessage("Voce ja tem a promocao maxima.")
		return false
	end

	if param:lower():gsub("%s", "") ~= "sim" then
		player:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
			"%da promocao: %s -> %s. Requisitos: level %d e %d gold. Para confirmar digite: !promote sim",
			etapa, player:getVocation():getName(), proxima:getName(), cfg.level, cfg.preco))
		return false
	end

	if player:isPzLocked() then
		player:sendCancelMessage("Voce nao pode se promover com battle.")
		return false
	end

	local ok, msg = player:helblazerPromover()
	if ok then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, msg)
	else
		player:sendCancelMessage(msg)
	end
	return false
end

promote:separator(" ")
promote:register()
