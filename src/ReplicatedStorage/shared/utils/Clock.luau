local Clock = {}

function Clock.Now()
	return workspace:GetServerTimeNow()
end

function Clock.ToProcess(serverTime)
	return os.clock() - (Clock.Now() - serverTime)
end

return Clock
