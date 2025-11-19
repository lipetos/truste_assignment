--[[
  replication contoller
  lpz
]]

--// imports
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")

local conveyor_net = require(replicated_storage.shared.ConveyorNet)

local world = workspace:WaitForChild("world")
local conveyor_folder = world:WaitForChild("conveyor_belt")
local conveyor_model = conveyor_folder:WaitForChild("Conveyor")
local spawn_bag_part = conveyor_model:WaitForChild("SpawnBagPart")

local assets_folder = replicated_storage:WaitForChild("assets")
local bag_template = assets_folder:WaitForChild("BagVisual")

local spawning_until_by_id: { [number]: number } = {}
local fx_by_id: { [number]: Instance } = {}
local appearance_by_id: { [number]: { material: Enum.Material, color: Color3 } } = {}
local duration_by_id: { [number]: number } = {}

local function emit(inst: Instance)
  for i,v in inst:GetDescendants() do
    if v:IsA("ParticleEmitter") then
      v:Emit(v:GetAttribute("EmitCount"))
    end
  end
end

local function apply_appearance(inst: Instance, material: Enum.Material, color: Color3)
  inst.Material = material
  inst.Color = color
end

local function update_fx(dt: number)
  local now = os.clock()
  for id, fx in fx_by_id do
    local until_t = spawning_until_by_id[id] or 0
    local dur = duration_by_id[id] or (spawn_bag_part:GetAttribute("spawn_rate") or 1)
    local start_t = until_t - dur

    local k = math.clamp((now - start_t) / math.max(1e-3, dur), 0, 1)
    if k >= 1 then
      if fx.Parent then
        emit(spawn_bag_part.DoneCreating)
        fx:Destroy()
      end
      fx_by_id[id] = nil
      duration_by_id[id] = nil
    else
      local magnitude = 0.15 * (k * k)
      local offset = Vector3.new(
        (math.random() - 0.5) * 2 * magnitude,
        (math.random() - 0.5) * 2 * magnitude,
        (math.random() - 0.5) * 2 * magnitude
      )
      local base_pos = spawn_bag_part.Position

      if fx:IsA("Model") then
        fx:PivotTo(CFrame.new(base_pos + offset))
      else
        fx.CFrame = CFrame.new(base_pos + offset)
      end

      local hl = fx:FindFirstChildOfClass("Highlight")
      if hl then
        hl.FillTransparency = 1 - k
      end
    end
  end
end

local ReplicationController = {}

function ReplicationController.start()
  conveyor_net.SpawnBegin.listen(function(payload)
    local id = payload.id
    local rate = spawn_bag_part:GetAttribute("spawn_rate") or 1
    duration_by_id[id] = rate
    spawning_until_by_id[id] = os.clock() + rate

    local fx = bag_template:Clone()
    fx.Name = "SpawnFX_" .. tostring(id)

    local MATERIALS = Enum.Material:GetEnumItems()
    local mat = MATERIALS[payload.m]

    local col = Color3.fromRGB(payload.r, payload.g, payload.b)
    appearance_by_id[id] = { material = mat, color = col }

    apply_appearance(fx, mat, col)

    fx.Anchored = true

    local hl = Instance.new("Highlight")
    hl.Name = "SpawnHighlight"
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 1
    hl.FillTransparency = 1
    hl.Parent = fx

    fx.Parent = world
    fx_by_id[id] = fx
  end)

  run_service.RenderStepped:Connect(function(dt)
    update_fx(dt)
  end)
end

function ReplicationController.is_spawn_ready(id: number): boolean
  local until_t = spawning_until_by_id[id]
  if not until_t then return true end
  return os.clock() >= until_t
end

function ReplicationController.get_appearance(id: number)
  return appearance_by_id[id]
end

return ReplicationController