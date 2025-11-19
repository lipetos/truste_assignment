local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.packages.ByteNet)

return ByteNet.defineNamespace("Conveyor", function()
  local Packet = ByteNet.definePacket
  local Struct = ByteNet.struct

  return {
    Positions = Packet({
      value = ByteNet.array(Struct({
        id = ByteNet.uint8,
        s = ByteNet.uint8,
      })),
      reliabilityType = "unreliable",
    }),
  }
end)

