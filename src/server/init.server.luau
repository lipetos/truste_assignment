--[[
  entry point
]]

local conveyor_service = require(script.Services.ConveyorService)
local replication_service = require(script.Services.ReplicationService)

conveyor_service.start()