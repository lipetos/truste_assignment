local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local conveyor_net = require(ReplicatedStorage.shared.ConveyorNet)

local replication_service = {}

function replication_service.spawn_begin(id: number, m: number, r: number, g: number, b: number)
  conveyor_net.SpawnBegin.sendToAll({
    id = id,
    m = m,
    r = r,
    g = g,
    b = b,
  })
end

local controller_user_id: number? = nil

local function broadcast_controller()
  conveyor_net.ControllerAssigned.sendToAll({
    userId = controller_user_id or 0,
  })
end

function replication_service.start(set_spawn_rate: (number) -> ())
  Players.PlayerAdded:Connect(function(player)
    if not controller_user_id then
      controller_user_id = player.UserId
      broadcast_controller()
    else
      conveyor_net.ControllerAssigned.sendTo({ userId = controller_user_id or 0 }, player)
    end
  end)
  Players.PlayerRemoving:Connect(function(player)
    if controller_user_id == player.UserId then
      controller_user_id = nil
      local remaining = Players:GetPlayers()[1]

      if remaining then
        controller_user_id = remaining.UserId
      end
      broadcast_controller()
    end
  end)

  conveyor_net.BagClicked.listen(function(payload, player)
    local id = payload.id
    print(string.format("[server] bag clicked id=%d by %s", id, player and player.Name or "unknown"))
  end)

  conveyor_net.SetSpawnRate.listen(function(payload, player)
    local rate = math.clamp(tonumber(payload.rate) or 1, 0.05, 5.0)

    if controller_user_id and player and player.UserId == controller_user_id then
      set_spawn_rate(rate)
      conveyor_net.SpawnRateChanged.sendToAll({ rate = rate })
    end
  end)
end

return replication_service