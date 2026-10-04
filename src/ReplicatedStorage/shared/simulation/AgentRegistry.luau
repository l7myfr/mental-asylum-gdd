local AgentRegistry = {}

local agents = {}
local cache = {}

function AgentRegistry.Register(character, getInput)
	agents[character] = getInput
end

function AgentRegistry.Unregister(character)
	agents[character] = nil
	cache[character] = nil
end

function AgentRegistry.GetAgents()
	for character in agents do
		if not character.Parent then
			AgentRegistry.Unregister(character)
		end
	end

	return agents
end

function AgentRegistry.ReadInput(character, now, deltaTime)
	local cached = cache[character]

	if cached and cached.time == now then
		return cached.input
	end

	local input = agents[character](character, now, deltaTime)
	cache[character] = {
		time = now,
		input = input,
	}

	return input
end

return AgentRegistry
