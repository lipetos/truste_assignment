--!strict
--[[
  conveyor service
  lpz
]]

--// imports
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")

local global_types = require(replicated_storage.shared.GlobalTypes)
local conveyor_net = require(replicated_storage.shared.ConveyorNet)

--// assets
local world_folder = workspace:WaitForChild("world")
local conveyor_folder = world_folder:WaitForChild("conveyor_belt")
local conveyor_model = conveyor_folder:WaitForChild("Conveyor")
local server_bags_folder = world_folder:WaitForChild("server_bags")
local spawn_bag_part = conveyor_model:WaitForChild("SpawnBagPart")
local consume_bag_part = conveyor_model:WaitForChild("ConsumeBagPart")

--// vars
local bags_runtime = {}
local current_conveyor: any = nil
local last_update = 0
local last_snapshot = 0
local next_id = 0

local function allocate_id(): number?
  for _ = 1, 256 do
    local candidate = next_id
    next_id += 1

    if next_id > 255 then
      next_id = 0
    end

    if not bags_runtime[candidate] then
      return candidate
    end
  end
end

local DEFAULT_SPEED = 10
local SNAPSHOT_INTERVAL = 0.1

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Exclude
raycast_params.FilterDescendantsInstances = { server_bags_folder }

--// local functions
local function sort_numeric_by_name(a: Instance, b: Instance): boolean
  local na = tonumber(a.Name) or 0
  local nb = tonumber(b.Name) or 0
  return na < nb
end

local function build_path(model)
  local path_model = model:FindFirstChild("Path")
  local points = {}

  for _, child in path_model:GetChildren() do
    if child:IsA("Attachment") then
      table.insert(points, child)
    end
  end

  table.sort(points, sort_numeric_by_name)

  local positions = {}
  for i = 1, #points do
    positions[i] = points[i].WorldCFrame.Position
  end

  local segments = {}
  local cumulative = {}
  local total = 0
  for i = 1, #positions - 1 do
    local len = (positions[i + 1] - positions[i]).Magnitude
    segments[i] = len
    total += len
    cumulative[i] = total
  end

  return {
    points = points,
    positions = positions,
    segments = segments,
    cumulative = cumulative,
    total_length = total,
  }
end

local function progress_at_position_xz(path, x: number, z: number): number
  local best_s = 0
  local best_d2 = math.huge
  local accum_before = 0

  for i = 1, #path.positions - 1 do
    local a = path.positions[i]
    local b = path.positions[i + 1]

    local ax, az = a.X, a.Z
    local bx, bz = b.X, b.Z

    local abx = bx - ax
    local abz = bz - az
    local apx = x - ax
    local apz = z - az

    local ab_len2 = abx * abx + abz * abz
    local t = 0
    if ab_len2 > 0 then
      t = math.clamp((apx * abx + apz * abz) / ab_len2, 0, 1)
    end

    local px = ax + abx * t
    local pz = az + abz * t

    local dx = x - px
    local dz = z - pz
    local d2 = dx * dx + dz * dz

    if d2 < best_d2 then
      best_d2 = d2
      local seg_len = path.segments[i] or 0
      best_s = accum_before + seg_len * t
    end

    accum_before = path.cumulative[i] or accum_before
  end

  return best_s
end

local function sample_cframe_at_distance(path, distance: number): CFrame
  local total = path.total_length

  if total <= 0 then
    return CFrame.new(path.positions[1])
  end

  if distance <= 0 then
    local p0 = path.positions[1]
    local p1 = path.positions[2]

    local dir = (p1 - p0).Unit
    local up = Vector3.yAxis

    local right = dir:Cross(up).Unit
    local adjusted_up = right:Cross(dir).Unit

    return CFrame.fromMatrix(p0, right, adjusted_up, dir)
  end

  if distance >= total then
    local pN1 = path.positions[#path.positions - 1]
    local pN = path.positions[#path.positions]

    local dir = (pN - pN1).Unit
    local up = Vector3.yAxis

    local right = dir:Cross(up).Unit
    local adjustedUp = right:Cross(dir).Unit

    return CFrame.fromMatrix(pN, right, adjustedUp, dir)
  end

  for i = 1, #path.segments do
    local prevCum = if i == 1 then 0 else path.cumulative[i - 1]
    if distance <= path.cumulative[i] then
      local seg_len = path.segments[i]
      local t = (distance - prevCum) / seg_len

      local a = path.positions[i]
      local b = path.positions[i + 1]

      local pos = a:Lerp(b, t)

      local dir = (b - a).Unit
      local up = Vector3.yAxis

      local right = dir:Cross(up).Unit
      local adjusted_up = right:Cross(dir).Unit

      return CFrame.fromMatrix(pos, right, adjusted_up, dir)
    end
  end

  return CFrame.new(path.positions[#path.positions])
end

--// service
local conveyor_service = {}

function conveyor_service.start()
  conveyor_service.setup_conveyor(conveyor_model)

  run_service.Heartbeat:Connect(function(dt: number)
    conveyor_service.update(dt)
  end)
end

-- setups the conveyor
-- lpz
function conveyor_service.setup_conveyor(conveyor_inst)
  local path_info = build_path(conveyor_inst)

  current_conveyor = {
    instance = conveyor_inst,
    spawned_bags = {},
    last_spawned_bag = 0,

    is_busy = false,

    config = {
      spawn_rate = 0.3 -- seconds
    },

    path = path_info
  }
end

-- updates the conveyor
-- lpz
function conveyor_service.update(dt: number)
  if not current_conveyor then return end
  if current_conveyor.is_busy then return end

  if os.clock() - current_conveyor.last_spawned_bag > current_conveyor.config.spawn_rate then
    conveyor_service.spawn_bag(current_conveyor)
    current_conveyor.last_spawned_bag = os.clock()
  end

  local path = current_conveyor.path

  if not path then return end

  for i = #current_conveyor.spawned_bags, 1, -1 do
    local id = current_conveyor.spawned_bags[i]
    local state = bags_runtime[id]

    if not state then
      table.remove(current_conveyor.spawned_bags, i)
    else
      local since_spawn = os.clock() - state.spawned_at
      if since_spawn >= state.fall_time then
        local t_move = since_spawn - state.fall_time
        state.progress = state.s0 + state.speed * t_move
      else
        state.progress = state.s0
      end

      if state.progress >= path.total_length then
        bags_runtime[id] = nil
        table.remove(current_conveyor.spawned_bags, i)
      end
    end
  end

  if os.clock() - last_snapshot >= SNAPSHOT_INTERVAL then
    last_snapshot = os.clock()

    local payload = {}
    local idx = 1
    for pid, s in pairs(bags_runtime) do
      local s_norm = math.clamp(s.progress / current_conveyor.path.total_length, 0, 1)
      local s_u8 = math.floor(s_norm * 255 + 0.5)

      payload[idx] = { id = pid, s = s_u8 }

      idx += 1
    end
    if idx > 1 then
      conveyor_net.Positions.sendToAll(payload)
    end
  end
end

-- spawns a bag
-- lpz
function conveyor_service.spawn_bag(conveyor)
  if current_conveyor.is_busy then return end

  local path = current_conveyor.path

  if not path then return end

  local spawn_pos = spawn_bag_part.Position

  local s0 = progress_at_position_xz(path, spawn_pos.X, spawn_pos.Z)

  local fall_time = 0
  local ground_y = sample_cframe_at_distance(path, s0 or 0).Position.Y
  local origin = spawn_pos + Vector3.new(0, 1, 0)
  local result = workspace:Raycast(origin, Vector3.new(0, -100, 0), raycast_params)
  if result then
    ground_y = result.Position.Y
  end
  local d = math.max(0, spawn_pos.Y - ground_y)

  if d > 0 then
    fall_time = math.sqrt(2 * d / workspace.Gravity)
  end

  local id = allocate_id()
  if not id then
    return
  end

  table.insert(conveyor.spawned_bags, id)

  bags_runtime[id] = {
    id = id,
    progress = s0 or 0,

    speed = DEFAULT_SPEED,
    s0 = s0,
    spawned_at = os.clock(),
    fall_time = fall_time,
    spawnY = spawn_pos.Y,
    ground_y = ground_y,
  }
end

return conveyor_service