--[[
	FolgaOt - configuracao dos sistemas: tasks, recompensa diaria, autoloot e criatura do dia.
	Os comandos ficam em data/scripts/helblazer/ (tasks.lua, diario.lua, autoloot.lua, boosted.lua).
	Todos os valores abaixo podem ser mudados; reinicie o servidor depois.
]]

-- ===================== storages (47000 a 47099) =====================
HELBLAZER_STORAGE = {
	taskAtual = 47000,        -- indice da task em andamento (-1 = nenhuma)
	taskKills = 47001,        -- kills da task em andamento
	diariaDia = 47002,        -- dia em que a task diaria foi aceita
	diariaKills = 47003,      -- kills da task diaria
	diariaFeita = 47004,      -- ultimo dia em que a task diaria foi entregue
	diariaTask = 47005,       -- task diaria aceita hoje (indice)
	diarioDia = 47010,        -- ultimo dia em que pegou a recompensa diaria
	diarioSequencia = 47011,  -- dias seguidos
	autolootGold = 47020,     -- 1 = gold vai para o banco
	autolootItens = 47021,    -- 47021 a 47040: ids da lista do autoloot
}

-- ===================== tasks =====================
-- monstros: nomes que contam para a task | exp, gold (banco) e coins: recompensa ao terminar
HELBLAZER_TASKS = {
	{nome = "Trolls",     monstros = {"troll", "swamp troll"},                                 kills = 100, level = 8,   exp = 15000,   gold = 2000,  coins = 0},
	{nome = "Rotworms",   monstros = {"rotworm", "carrion worm"},                              kills = 100, level = 8,   exp = 20000,   gold = 2000,  coins = 0},
	{nome = "Orcs",       monstros = {"orc", "orc spearman", "orc warrior", "orc shaman", "orc berserker", "orc leader", "orc rider", "orc warlord"},
	                                                                                           kills = 150, level = 15,  exp = 60000,   gold = 5000,  coins = 1},
	{nome = "Amazons",    monstros = {"amazon", "valkyrie"},                                   kills = 150, level = 25,  exp = 120000,  gold = 8000,  coins = 2},
	{nome = "Ghouls",     monstros = {"ghoul", "skeleton", "ghost", "mummy"},                  kills = 150, level = 30,  exp = 180000,  gold = 10000, coins = 2},
	{nome = "Cyclops",    monstros = {"cyclops"},                                              kills = 200, level = 40,  exp = 400000,  gold = 15000, coins = 3},
	{nome = "Spiders",    monstros = {"giant spider", "tarantula", "poison spider"},           kills = 150, level = 60,  exp = 900000,  gold = 25000, coins = 5},
	{nome = "Dragons",    monstros = {"dragon", "dragon lord"},                                kills = 200, level = 70,  exp = 2000000, gold = 40000, coins = 8},
	{nome = "Vampires",   monstros = {"vampire", "necromancer", "demon skeleton"},             kills = 200, level = 80,  exp = 2500000, gold = 40000, coins = 8},
	{nome = "Demons",     monstros = {"demon"},                                                kills = 100, level = 130, exp = 8000000, gold = 100000, coins = 20},
}
-- Task diaria: uma task sorteada por dia para cada jogador (so entre as do level dele).
-- Ao terminar ganha a recompensa normal multiplicada por isto, mais coins extras.
HELBLAZER_TASK_DIARIA = {multiplicador = 1.5, coinsExtra = 5}

-- ===================== recompensa diaria (!diario) =====================
-- Dia 1 a 7 de logins seguidos; depois do 7o volta ao dia 1. Gold vai para o banco.
-- pocoes: quantidade de pocoes (mana potion para magos e paladins, health potion para knights)
HELBLAZER_DIARIO = {
	{gold = 5000},
	{gold = 10000},
	{pocoes = 25},
	{gold = 20000},
	{pocoes = 50},
	{gold = 30000},
	{gold = 50000, coins = 10},
}

-- ===================== autoloot =====================
HELBLAZER_AUTOLOOT = {
	maxItens = 20,   -- itens na lista de cada jogador
	distancia = 10,  -- o jogador precisa estar a ate 10 sqm do monstro (mesmo andar)
}

-- ===================== criatura do dia =====================
HELBLAZER_BOOSTED = {
	bonusExp = 50, -- % a mais de experiencia
	lootExtra = true, -- o loot e sorteado duas vezes
	monstros = {"Troll", "Rotworm", "Orc Warrior", "Orc Berserker", "Amazon", "Valkyrie", "Ghoul", "Cyclops",
		"Elf Scout", "Wild Warrior", "Minotaur", "Mummy", "Giant Spider", "Dragon", "Dragon Lord",
		"Vampire", "Necromancer", "Demon Skeleton", "Demon"},
}

-- ===================== funcoes comuns =====================

-- Numero do dia de hoje (muda a meia-noite, no fuso do servidor)
function helblazerDia()
	local t = os.date("*t")
	return math.floor(os.time({year = t.year, month = t.month, day = t.day, hour = 12}) / 86400)
end

-- Numero "aleatorio" fixo para uma semente (o mesmo o dia todo, mesmo reiniciando)
function helblazerSorteio(semente, n)
	local x = (semente * 2654435761) % 4294967296
	return math.floor(x / 65536) % n + 1
end

function helblazerBoostedHoje()
	local lista = HELBLAZER_BOOSTED.monstros
	return lista[helblazerSorteio(helblazerDia() + 7, #lista)]
end

function helblazerEhBoosted(nome)
	return nome:lower() == helblazerBoostedHoje():lower()
end

-- 1 sorcerer, 2 druid, 3 paladin, 4 knight (vale para as promocoes tambem)
function Player.helblazerVocacaoBase(self)
	local id = self:getVocation():getId()
	if id == 0 then
		return 0
	end
	return (id - 1) % 4 + 1
end

function helblazerTaskDoMonstro(task, nomeMonstro)
	nomeMonstro = nomeMonstro:lower()
	for _, nome in ipairs(task.monstros) do
		if nome == nomeMonstro then
			return true
		end
	end
	return false
end

-- Task diaria do jogador hoje (indice em HELBLAZER_TASKS), entre as que o level permite
function Player.helblazerTaskDiaria(self)
	local possiveis = {}
	for i, task in ipairs(HELBLAZER_TASKS) do
		if self:getLevel() >= task.level then
			possiveis[#possiveis + 1] = i
		end
	end
	if #possiveis == 0 then
		return nil
	end
	-- usa so as 4 tasks mais altas que o jogador pode fazer, para nao cair em trolls no level 200
	local inicio = math.max(1, #possiveis - 3)
	local idx = helblazerSorteio(helblazerDia() * 31 + self:getGuid(), #possiveis - inicio + 1)
	return possiveis[inicio + idx - 1]
end

-- Entrega exp, gold (banco), coins e itens. Retorna o texto do que foi dado.
function Player.helblazerRecompensa(self, exp, gold, coins, pocoes)
	local partes = {}
	if exp and exp > 0 then
		self:addExperience(exp, true)
		partes[#partes + 1] = string.format("%d de experiencia", exp)
	end
	if gold and gold > 0 then
		self:setBankBalance(self:getBankBalance() + gold)
		partes[#partes + 1] = string.format("%d gold (no banco)", gold)
	end
	if coins and coins > 0 then
		Loja.addCoins(self:getAccountId(), coins)
		partes[#partes + 1] = string.format("%d coins", coins)
	end
	if pocoes and pocoes > 0 then
		local id = self:helblazerVocacaoBase() == 4 and 7618 or 7620 -- health potion / mana potion
		local item = Game.createItem(id, pocoes)
		if item and self:addItemEx(item) ~= RETURNVALUE_NOERROR then
			-- sem espaco: vai para o chao, embaixo do jogador
			item:remove()
			Game.createItem(id, pocoes, self:getPosition())
			self:sendTextMessage(MESSAGE_INFO_DESCR, "Sua mochila esta cheia: as pocoes ficaram no chao, embaixo de voce.")
		end
		partes[#partes + 1] = string.format("%d %s", pocoes, ItemType(id):getPluralName())
	end
	return table.concat(partes, ", ")
end
