--[[
	Tasks
	!task                  mostra as tasks do seu level e o progresso
	!task dragons          comeca a task de Dragons (uma por vez; pode repetir quantas vezes quiser)
	!task cancelar         desiste da task atual (perde o progresso)
	!task diaria           aceita a task diaria (sorteada para voce, muda a meia-noite)

	As tasks e recompensas ficam em data/lib/core/helblazer_sistemas.lua (HELBLAZER_TASKS).
	Conta a kill para quem deu mais dano e para quem deu o ultimo golpe.
]]

local S = HELBLAZER_STORAGE

local function taskAtual(player)
	local idx = player:getStorageValue(S.taskAtual)
	return HELBLAZER_TASKS[idx] and idx or nil
end

local function diariaAtiva(player)
	return player:getStorageValue(S.diariaDia) == helblazerDia() and player:getStorageValue(S.diariaFeita) ~= helblazerDia()
end

local function premioTexto(task, mult, coinsExtra)
	mult = mult or 1
	local coins = math.floor(task.coins * mult) + (coinsExtra or 0)
	return string.format("%d exp, %d gold%s", math.floor(task.exp * mult), math.floor(task.gold * mult), coins > 0 and (", " .. coins .. " coins") or "")
end

local function mostrar(player)
	local linhas = {"Tasks (digite !task <nome> para comecar):", ""}
	for i, task in ipairs(HELBLAZER_TASKS) do
		if player:getLevel() >= task.level then
			linhas[#linhas + 1] = string.format("%s - %d kills, level %d: %s", task.nome, task.kills, task.level, premioTexto(task))
		end
	end

	local atual = taskAtual(player)
	linhas[#linhas + 1] = ""
	if atual then
		local t = HELBLAZER_TASKS[atual]
		linhas[#linhas + 1] = string.format("Task atual: %s (%d/%d). Para desistir: !task cancelar", t.nome, math.max(0, player:getStorageValue(S.taskKills)), t.kills)
	else
		linhas[#linhas + 1] = "Voce nao tem task em andamento."
	end

	local d = diariaAtiva(player) and player:getStorageValue(S.diariaTask) or player:helblazerTaskDiaria()
	if HELBLAZER_TASKS[d] then
		local t = HELBLAZER_TASKS[d]
		local cfg = HELBLAZER_TASK_DIARIA
		if player:getStorageValue(S.diariaFeita) == helblazerDia() then
			linhas[#linhas + 1] = "Task diaria: ja entregue hoje. Volte amanha!"
		elseif diariaAtiva(player) then
			linhas[#linhas + 1] = string.format("Task diaria: %s (%d/%d).", t.nome, math.max(0, player:getStorageValue(S.diariaKills)), t.kills)
		else
			linhas[#linhas + 1] = string.format("Task diaria de hoje: %s - %d kills: %s. Digite !task diaria para aceitar.",
				t.nome, t.kills, premioTexto(t, cfg.multiplicador, cfg.coinsExtra))
		end
	end
	player:showTextDialog(1950, table.concat(linhas, "\n")) -- livro
end

local comando = TalkAction("!task")

function comando.onSay(player, words, param)
	param = param:lower():gsub("^%s+", ""):gsub("%s+$", "")

	if param == "" then
		mostrar(player)
	elseif param == "cancelar" then
		if not taskAtual(player) then
			player:sendCancelMessage("Voce nao tem task em andamento.")
		else
			player:setStorageValue(S.taskAtual, -1)
			player:setStorageValue(S.taskKills, 0)
			player:sendTextMessage(MESSAGE_INFO_DESCR, "Task cancelada.")
		end
	elseif param == "diaria" then
		local d = player:helblazerTaskDiaria()
		if not d then
			player:sendCancelMessage("Nao ha task diaria para o seu level.")
		elseif player:getStorageValue(S.diariaFeita) == helblazerDia() then
			player:sendCancelMessage("Voce ja entregou a task diaria de hoje. Volte amanha!")
		elseif diariaAtiva(player) then
			player:sendCancelMessage("Voce ja aceitou a task diaria. Veja o progresso com !task.")
		else
			player:setStorageValue(S.diariaDia, helblazerDia())
			player:setStorageValue(S.diariaTask, d)
			player:setStorageValue(S.diariaKills, 0)
			local t = HELBLAZER_TASKS[d]
			player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Task diaria aceita: mate %d %s ate a meia-noite.", t.kills, t.nome))
		end
	else
		local escolhida
		for i, task in ipairs(HELBLAZER_TASKS) do
			if task.nome:lower() == param then
				escolhida = i
			end
		end
		if not escolhida then
			player:sendCancelMessage("Task nao encontrada. Digite !task para ver a lista.")
		elseif taskAtual(player) then
			player:sendCancelMessage("Voce ja tem uma task. Termine ou use !task cancelar.")
		elseif player:getLevel() < HELBLAZER_TASKS[escolhida].level then
			player:sendCancelMessage(string.format("Essa task precisa de level %d.", HELBLAZER_TASKS[escolhida].level))
		else
			local t = HELBLAZER_TASKS[escolhida]
			player:setStorageValue(S.taskAtual, escolhida)
			player:setStorageValue(S.taskKills, 0)
			player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Task iniciada: mate %d %s. Recompensa: %s.", t.kills, t.nome, premioTexto(t)))
		end
	end
	return false
end

comando:separator(" ")
comando:register()

local function avisarProgresso(player, rotulo, kills, total)
	if kills % 10 == 0 or total - kills <= 5 then
		player:sendTextMessage(MESSAGE_STATUS_DEFAULT, string.format("[%s] %d/%d", rotulo, kills, total))
	end
end

local kill = CreatureEvent("HelblazerTaskKill")

function kill.onKill(player, target)
	if not target:isMonster() or target:getMaster() then
		return true
	end
	local nome = target:getName()

	local atual = taskAtual(player)
	if atual and helblazerTaskDoMonstro(HELBLAZER_TASKS[atual], nome) then
		local t = HELBLAZER_TASKS[atual]
		local kills = math.max(0, player:getStorageValue(S.taskKills)) + 1
		if kills >= t.kills then
			player:setStorageValue(S.taskAtual, -1)
			player:setStorageValue(S.taskKills, 0)
			local texto = player:helblazerRecompensa(t.exp, t.gold, t.coins)
			player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Task %s completa! Voce ganhou: %s.", t.nome, texto))
		else
			player:setStorageValue(S.taskKills, kills)
			avisarProgresso(player, "Task " .. t.nome, kills, t.kills)
		end
	end

	if diariaAtiva(player) then
		local t = HELBLAZER_TASKS[player:getStorageValue(S.diariaTask)]
		if t and helblazerTaskDoMonstro(t, nome) then
			local kills = math.max(0, player:getStorageValue(S.diariaKills)) + 1
			player:setStorageValue(S.diariaKills, kills)
			if kills >= t.kills then
				local cfg = HELBLAZER_TASK_DIARIA
				player:setStorageValue(S.diariaFeita, helblazerDia())
				local texto = player:helblazerRecompensa(math.floor(t.exp * cfg.multiplicador), math.floor(t.gold * cfg.multiplicador),
					math.floor(t.coins * cfg.multiplicador) + cfg.coinsExtra)
				player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_RED)
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Task diaria completa! Voce ganhou: %s.", texto))
			else
				avisarProgresso(player, "Diaria " .. t.nome, kills, t.kills)
			end
		end
	end
	return true
end

kill:register()

local login = CreatureEvent("HelblazerTaskLogin")

function login.onLogin(player)
	player:registerEvent("HelblazerTaskKill")
	return true
end

login:register()
