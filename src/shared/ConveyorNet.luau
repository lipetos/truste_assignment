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

    SpawnBegin = Packet({
      value = Struct({
        id = ByteNet.uint8,
        m = ByteNet.uint8, -- material index
        r = ByteNet.uint8,
        g = ByteNet.uint8,
        b = ByteNet.uint8,
      }),
      reliabilityType = "reliable",
    }),

    BagClicked = Packet({
      value = Struct({
        id = ByteNet.uint8,
      }),
      reliabilityType = "reliable",
    }),

    ControllerAssigned = Packet({
      value = Struct({
        userId = ByteNet.uint32,
      }),
      reliabilityType = "reliable",
    }),

    SetSpawnRate = Packet({
      value = Struct({
        rate = ByteNet.float32, -- seconds per bag
      }),
      reliabilityType = "reliable",
    }),

    SpawnRateChanged = Packet({
      value = Struct({
        rate = ByteNet.float32,
      }),
      reliabilityType = "reliable",
    }),
  }
end)

