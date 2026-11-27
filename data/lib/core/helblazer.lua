-- Helblazer OT - promocoes de vocacao (usado pelo comando !promote e pelo NPC The Forgotten King)
-- Nao precisa de premium.

HELBLAZER_PROMOCOES = {
	[1] = { level = 20,  preco = 20000 },  -- Sorcerer -> Master Sorcerer, etc.
	[2] = { level = 150, preco = 150000 }, -- Master Sorcerer -> Arch Sorcerer, etc.
}

-- Retorna a proxima vocacao, a etapa (1 ou 2) e a configuracao dela. nil se ja estiver no maximo.
function Player.helblazerProximaPromocao(self)
	local voc = self:getVocation()
	if voc:getId() == VOCATION_NONE then
		return nil
	end
	local proxima = voc:getPromotion()
	if not proxima then
		return nil
	end
	local etapa = voc:getDemotion() and 2 or 1
	return proxima, etapa, HELBLAZER_PROMOCOES[etapa]
end

-- Faz a promocao. Retorna true/false e a mensagem para o jogador.
function Player.helblazerPromover(self)
	local proxima, etapa, cfg = self:helblazerProximaPromocao()
	if not proxima then
		return false, "Voce ja tem a promocao maxima."
	end
	if self:getLevel() < cfg.level then
		return false, string.format("Voce precisa ser level %d para virar %s.", cfg.level, proxima:getName())
	end
	if not self:removeTotalMoney(cfg.preco) then
		return false, string.format("Voce precisa de %d gold (na mochila ou no banco) para virar %s.", cfg.preco, proxima:getName())
	end
	self:setVocation(proxima)
	self:setStorageValue(PlayerStorageKeys.promotion, etapa)
	self:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
	return true, string.format("Parabens! Agora voce e %s.", proxima:getName())
end
