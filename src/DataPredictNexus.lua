local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local DataPredictLibraryLinker = script.DataPredictLibraryLinker.Value
local TensorL2DLibraryLinker = script.TensorL2DLibraryLinker.Value

local defaultSyncTime = 3 * 60

local logTypeArray = {"Error", "Warning"}

local DataPredictNexusInstancesArray = {}

local DataPredictNexus = {}

DataPredictNexus.__index = DataPredictNexus

function DataPredictNexus.new(propertyTable: {})
	
	local instanceId: any = propertyTable.instanceId
	
	local address: string = propertyTable.address
	
	local apiKey: string = propertyTable.apiKey
	
	local encryptionKey: string = propertyTable.encryptionKey
	
	local syncTime: number = propertyTable.syncTime
	
	local existingInstance = DataPredictNexusInstancesArray[instanceId]
	
	if existingInstance then return existingInstance end
	
	if (not encryptionKey) then warn("Without an encryption key, the data will not be encrypted. This means that the hackers can intercept the unencrypted data.") end
	
	local self = {
		
		instanceId = instanceId,
		
		address = address,
		
		apiKey = apiKey,
		
		encryptionKey = encryptionKey,
		
		syncTime = syncTime,
		
		logArray = {},
		
		syncThread = nil,
		
	}
	
	local function addLog(logType, logMessage)
		
		if (not table.find(logTypeArray, logType)) then error("Invalid log type.") end
		
		table.insert(self.logArray, {logType, logMessage})
		
	end
	
	local function deleteLog(position)
		
		table.remove(self.logArray, position)
		
	end
	
	local function clearAllLogs()
		
		table.clear(self.logArray)
		
	end
	
	local function onSync()
		
		local requestDictionary = {
			
			apiKey = self.apiKey,
			
		}
		
		local requestBody = HttpService:JSONEncode(requestDictionary)
		
		local success, response = pcall(function() return HttpService:PostAsync(self.address, requestBody, Enum.HttpContentType.ApplicationJson) end)

		if (not success) then addLog("Error", "Unable to fetch response from " .. self.address .. ".") return end
		
	end
	
	local function startSync()
		
		if (self.syncThread) then error("Already syncing.") end
		
		local syncTime = self.syncTime
		
		self.syncThread = task.spawn(function()
			
			while true do
				
				onSync()
				
				task.wait(syncTime)
				
			end
			
		end)
		
	end
	
	local function stopSync()
		
		local syncThread = self.syncThread
		
		if (not syncThread) then error("Currently not syncing.") end
		
		task.cancel(syncThread)
		
		self.syncThread = nil
		
	end
	
	return {
		
		addLog = addLog,
		deleteLog = deleteLog,
		clearAllLogs = clearAllLogs,
		
		startSync = startSync,
		stopSync = stopSync
			
		
	}
	
end


return DataPredictNexus
