local ReplicationController = require(script.Controllers.ReplicationController)
local SpawnRateController = require(script.Controllers.SpawnRateController)
local ConveyorController = require(script.Controllers.ConveyorController)

ReplicationController.start()
SpawnRateController.start()
ConveyorController.start()