--!strict
--[[
    conveyor controller
    lpz
]]

--// imports
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")
local players = game:GetService("Players")

local Fusion = require(replicated_storage.packages.Fusion)
local scope = Fusion.scoped(Fusion)

local conveyor_net = require(replicated_storage.shared.ConveyorNet)
local gizmos = require(replicated_storage.packages.gizmos)
local replication_controller = require(script.Parent.ReplicationController)

--// assets
local world_folder = workspace:WaitForChild("world")
local spawned_bags_folder = world_folder:FindFirstChild("spawned_bags") or world_folder
local assets_folder = replicated_storage:WaitForChild("assets")
local bag_template = assets_folder:WaitForChild("BagVisual")

local conveyor_folder = workspace:WaitForChild("world"):WaitForChild("conveyor_belt")
local conveyor_model = conveyor_folder:WaitForChild("Conveyor")
local path_model = conveyor_model:WaitForChild("Path")
local spawn_bag_part = conveyor_model:WaitForChild("SpawnBagPart")

--// local functions
local function sort_numeric_by_name(a: Instance, b: Instance): boolean
  local na = tonumber(a.Name) or 0
  local nb = tonumber(b.Name) or 0
  return na < nb
end

local function build_path()
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
    positions = positions,
    segments = segments,
    cumulative = cumulative,
    total_length = total,
  }
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

local client_path = build_path()
local TOTAL_LENGTH = client_path.total_length
local GRAVITY = workspace.Gravity

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Include
raycast_params.FilterDescendantsInstances = { conveyor_model.Belt }

local id_to_model = {}
local id_to_state = {}

local bagCount = scope:Value(0)

local NETWORK_FALLBACK_INTERVAL = 0.1

local function count_bags()
  local n = 0
  for _ in id_to_model do
    n += 1
  end
  return n
end

local function attach_click_detector(inst: Instance, id)
  local cd = Instance.new("ClickDetector")
  cd.Parent = inst

  cd.MouseClick:Connect(function()
    local nid = id
    print(string.format("[client] bag clicked id=%d", nid))
    conveyor_net.BagClicked.send({ id = nid })
  end)
end

local function ensure_model(id)
  local existing = id_to_model[id]
  if existing and existing.Parent ~= nil then
    return existing
  end

  local numeric_id = tonumber(id)
  local ap = replication_controller.get_appearance(numeric_id)

  local clone = bag_template:Clone()
  clone.Name = tostring(id)
  clone.Anchored = true
  clone.CanCollide = false
  clone.CanQuery = true
  clone.CanTouch = false

  if ap then
    clone.Material = ap.material
    clone.Color = ap.color
  end

  clone.Parent = spawned_bags_folder

  attach_click_detector(clone, id)

  id_to_model[id] = clone
  bagCount:set(count_bags())

  return clone
end

local function cleanup_missing(currentIds: { [string]: boolean })
  for id, model in id_to_model do
    if not currentIds[id] then
      if model and model.Parent ~= nil then
        model:Destroy()
      end
      id_to_model[id] = nil
      id_to_state[id] = nil
    end
  end
  bagCount:set(count_bags())
end

local function get_interpolated_pos(state, now: number): Vector3
  local t0 = state.t0 or now
  local t1 = state.t1 or (now + NETWORK_FALLBACK_INTERVAL)
  if t1 <= t0 then
    return state.target
  end
  local alpha = math.clamp((now - t0) / (t1 - t0), 0, 1)
  return state.current:Lerp(state.target, alpha)
end

local function apply_transform(model: Instance, pos: Vector3, dir: Vector3)
  local look = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
  local cf = CFrame.new(pos, pos + look)
  if model:IsA("Model") then
    model:PivotTo(cf)
  elseif model:IsA("BasePart") then
    model.CFrame = cf
  end
end

local function gethalf_height(inst: Instance): number
  if inst:IsA("BasePart") then
    return inst.Size.Y * 0.5
  end
  if inst:IsA("Model") then
    local _, size = inst:GetBoundingBox()
    return size.Y * 0.5
  end
  return 0.5
end

local function mountUI()
  local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
  local gui = scope:New "ScreenGui" {
    Name = "ConveyorHUD",
    ResetOnSpawn = false,
    Parent = playerGui,

    [scope.Children] = {
      scope:New "Frame" {
        Name = "BagCounter",
        BackgroundTransparency = 0.35,
        Size = UDim2.fromOffset(220, 44),
        Position = UDim2.fromOffset(20, 20),

        [scope.Children] = {
          scope:New "UIStroke" {
            Thickness = 1,
            Transparency = 0.25,
          },
          scope:New "UICorner" {
            CornerRadius = UDim.new(0, 8),
          },
          scope:New "TextLabel" {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamMedium,
            TextScaled = true,
            TextColor3 = Color3.fromRGB(0, 0, 0),
            Text = scope:Computed(function(use)
              return string.format("Bags: %d", use(bagCount))
            end),
          }
        }
      }
    }
  }

  return gui
end

--// controller
local conveyor_controller = {}

function conveyor_controller.start()
  mountUI()

  conveyor_net.Positions.listen(function(bags)
    local present = {}
    local now = os.clock()

    for _, item in bags do
      local id = item.id
      present[id] = true

      local model = ensure_model(id)
      local s_norm = math.clamp(item.s / 255, 0, 1)
      local dist = s_norm * TOTAL_LENGTH

      local base_cf = sample_cframe_at_distance(client_path, dist)
      local base_pos = base_cf.Position

      local new_pos = Vector3.new(base_pos.X, base_pos.Y, base_pos.Z)

      local state = id_to_state[id]
      if state then
        local interp = get_interpolated_pos(state, now)
        local interval = math.max(0.05, math.min(0.5, now - (state.last_packet_at or now)))

        local dir = (new_pos - interp)
        if dir.Magnitude > 1e-4 then
          state.dir = dir.Unit
        end

        state.current = interp
        state.target = new_pos
        state.t0 = now
        state.t1 = now + interval
        state.last_packet_at = now
        state.baseY = base_pos.Y
      else
        id_to_state[id] = {
          current = new_pos,
          target = new_pos,
          dir = Vector3.zAxis,
          t0 = now,
          t1 = now + NETWORK_FALLBACK_INTERVAL,
          last_packet_at = now,

          y = spawn_bag_part.Position.Y,
          vy = 0,
          grounded = false,
          baseY = base_pos.Y,
          last_update = now,
          half_height = gethalf_height(model),
        }

        apply_transform(model, new_pos, Vector3.zAxis)
      end
    end

    cleanup_missing(present)
  end)

  run_service.RenderStepped:Connect(function()
    local now = os.clock()
    for id, model in id_to_model do
      local state = id_to_state[id]
      if state then
        local pos = get_interpolated_pos(state, now)

        local dt = math.min((now - (state.last_update or now)), 0.1)
        state.last_update = now

        if not state.grounded then
          state.vy = (state.vy or 0) - GRAVITY * dt
          state.y = (state.y or pos.Y) + (state.vy or 0) * dt

          local origin = Vector3.new(pos.X, (state.y or pos.Y) + 2, pos.Z)
          local result = workspace:Raycast(origin, Vector3.new(0, -100, 0), raycast_params)
          local half_h = state.half_height or 0.5

          if result then
            local ground_y = result.Position.Y + half_h
            if (state.y or pos.Y) <= ground_y then
              state.y = ground_y
              state.vy = 0
              state.grounded = true
            end
          else
            state.grounded = false
          end
        else
          local origin = Vector3.new(pos.X, (state.y or pos.Y) + 2, pos.Z)
          local result = workspace:Raycast(origin, Vector3.new(0, -100, 0), raycast_params)
          local half_h = state.half_height or 0.5

          if not result then
            state.grounded = false
          else
            local ground_y = result.Position.Y + half_h
            if (state.y or pos.Y) - ground_y > 0.25 then
              state.grounded = false
            else
              state.y = math.max(state.y or pos.Y, ground_y)
            end
          end
        end

        local render_pos = Vector3.new(pos.X, state.y or pos.Y, pos.Z)
        apply_transform(model, render_pos, state.dir or Vector3.zAxis)
      end
    end
  end)
end

return conveyor_controller