local Gizmo = {}
local Terrain = workspace:FindFirstChildOfClass('Terrain')

local AdornmentProperties = {
	-- Used for lines, rays ...
	Cylinder = {
		Color3 = Color3.new(100, 100, 100), -- have to set it to a value >1 otherwise it wont be white if AlwaysOnTop is true.
		AlwaysOnTop = true,
		Adornee = Terrain,
		Radius = 0.02,
		ZIndex = 1
	},

	-- Used for showing direction of rays and arrows
	Cone = {
		Color3 = Color3.new(100, 100, 100), -- have to set it to a value >1 otherwise it wont be white if AlwaysOnTop is true.
		AlwaysOnTop = true,
		Adornee = Terrain,
		Height = 0.3,
		Radius = 0.05,
		ZIndex = 1
	}
}

local AdornmentHolders = Terrain:FindFirstChild('Gizmo - AdornmentHolders')
if not AdornmentHolders then
	AdornmentHolders = Instance.new('Folder')
	AdornmentHolders.Name = 'Gizmo - AdornmentHolders'
	AdornmentHolders.Parent = Terrain
end

local function CreateBase(AdornmentClass)
	local Object = Instance.new(AdornmentClass .. 'HandleAdornment')

	for Name, Value in next, AdornmentProperties[AdornmentClass] do
		Object[Name] = Value
	end

	Object.Parent = AdornmentHolders
	return Object
end

function Gizmo:DrawLine(Start, End, Offset, Color)
	local Line = CreateBase('Cylinder')

	local Distance = (Start - End).Magnitude
	Offset = Offset or 0

	Line.Height = Distance - Offset
	Line.CFrame = CFrame.lookAt(Start, End) * CFrame.new(0, 0, 0.5 * (Offset - Distance))

	if Color then
		Line.Color3 = Color
	end
	return Line
end
function Gizmo:DrawCone(CFrame, Color)
	local Cone = CreateBase('Cone')

	Cone.CFrame = CFrame
	if Color then
		Cone.Color3 = Color
	end
	return Cone
end

function Gizmo:DrawArrow(Start, End, Color)
	local ConeHeight = AdornmentProperties.Cone.Height

	local Distance = (Start - End).Magnitude

	local Line = Gizmo:DrawLine(Start, End, ConeHeight, Color)
	local Cone = Gizmo:DrawCone(CFrame.lookAt(Start, End) * CFrame.new(0, 0, -Distance + ConeHeight), Color)

	return Line, Cone
end

function Gizmo:DrawRay(Start, Direction, Color)
	return Gizmo:DrawArrow(Start, Start + Direction, Color)
end

return Gizmo