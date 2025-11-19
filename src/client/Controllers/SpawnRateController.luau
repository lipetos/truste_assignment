--!strict
--[[
  spawn rate slider controller
  shows a slider to one assigned controller client
  lpz
]]

local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")

local Fusion = require(replicated_storage.packages.Fusion)
local scope = Fusion.scoped(Fusion)

local conveyor_net = require(replicated_storage.shared.ConveyorNet)

local world = workspace:WaitForChild("world")
local conveyor_folder = world:WaitForChild("conveyor_belt")
local conveyor_model = conveyor_folder:WaitForChild("Conveyor")
local spawn_bag_part = conveyor_model:WaitForChild("SpawnBagPart")

local local_player = players.LocalPlayer

local assigned_user_id = scope:Value(0)
local rate_value = scope:Value(spawn_bag_part:GetAttribute("spawn_rate") or 1.0)
local is_drag = scope:Value(false)

local function clamp_rate(r: number): number
  return math.clamp(r, 0.05, 5.0)
end

local function send_rate(r: number)
  conveyor_net.SetSpawnRate.send({ rate = clamp_rate(r) })
end

local function mount_ui()
  local player_gui = local_player:WaitForChild("PlayerGui")
  local gui = scope:New "ScreenGui" {
    Name = "SpawnRateUI",
    ResetOnSpawn = false,
    Parent = player_gui,

    [scope.Children] = {
      scope:New "Frame" {
        Name = "Panel",
        BackgroundTransparency = 0.35,
        Size = UDim2.fromOffset(280, 80),
        Position = UDim2.fromOffset(20, 80),

        [scope.Children] = {
          scope:New "UICorner" { CornerRadius = UDim.new(0, 8) },
          scope:New "UIStroke" { Thickness = 1, Transparency = 0.25 },

          scope:New "TextLabel" {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = "Spawn interval (seconds)",
            TextScaled = true,
            TextColor3 = Color3.fromRGB(0,0,0),
            Size = UDim2.fromOffset(260, 18),
            Position = UDim2.fromOffset(10, 6),
          },

          scope:New "TextLabel" {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = scope:Computed(function(use)
              return string.format("%.2fs", clamp_rate(use(rate_value)))
            end),
            TextScaled = true,
            TextColor3 = Color3.fromRGB(0,0,0),
            Size = UDim2.fromOffset(60, 20),
            Position = UDim2.fromOffset(210, 28),
          },

          scope:New "Frame" {
            Name = "Track",
            BackgroundColor3 = Color3.fromRGB(50,50,50),
            BackgroundTransparency = 0.6,
            Size = UDim2.fromOffset(260, 10),
            Position = UDim2.fromOffset(10, 50),
            [scope.Children] = {
              scope:New "UICorner" { CornerRadius = UDim.new(0, 5) },
              scope:New "TextButton" {
                Name = "Knob",
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Color3.fromRGB(255,255,255),
                Size = UDim2.fromOffset(14, 14),
                Position = scope:Computed(function(use)
                  local r = clamp_rate(use(rate_value))
                  local t = (r - 0.05) / (5.0 - 0.05)
                  local x = t * (260 - 14)

                  return UDim2.fromOffset(x, -2)
                end),

                [scope.OnEvent "InputBegan"] = function(input)
                  if not input then return end
                  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    is_drag:set(true)
                  end
                end,
                [scope.OnEvent "InputEnded"] = function(input)
                  if not input then return end
                  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if scope.peek(is_drag) then
                      is_drag:set(false)
                      send_rate(scope.peek(rate_value))
                    end
                  end
                end,
              }
            }
          }
        }
      }
    }
  }

  uis.InputChanged:Connect(function(input)
    if not scope.peek(is_drag) then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
      return
    end

    local track_abs_pos = gui.Panel.Track.AbsolutePosition
    local track_abs_size = gui.Panel.Track.AbsoluteSize
    local rel = math.clamp((input.Position.X - track_abs_pos.X) / math.max(1, track_abs_size.X), 0, 1)
    local r = 0.05 + rel * (5.0 - 0.05)
    rate_value:set(clamp_rate(r))
  end)

  return gui
end

local mounted: Instance? = nil

local controller = {}

function controller.start()
  spawn_bag_part:GetAttributeChangedSignal("spawn_rate"):Connect(function()
    local v = spawn_bag_part:GetAttribute("spawn_rate")

    rate_value:set(clamp_rate(v))
  end)

  conveyor_net.SpawnRateChanged.listen(function(payload)
    rate_value:set(clamp_rate(payload.rate))
  end)

  conveyor_net.ControllerAssigned.listen(function(payload)
    assigned_user_id:set(payload.userId)

    if players.LocalPlayer.UserId == payload.userId then
      if not mounted then
        mounted = mount_ui()
      end
    else
      if mounted then
        mounted:Destroy()
        mounted = nil
      end
    end
  end)
end

return controller

