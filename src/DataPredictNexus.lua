local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local DataPredictLibraryLinker = script.DataPredictLibraryLinker.Value
local TensorL2DLibraryLinker = script.TensorL2DLibraryLinker.Value

local defaultPort = 4444

local defaultSyncTime = 3 * 60

local logTypeArray = {"Error", "Warning"}

local DataPredictNexusInstancesArray = {}

local DataPredictNexus = {}

DataPredictNexus.__index = DataPredictNexus

function DataPredictNexus.new(propertyTable: {})
	
	local instanceId: any = propertyTable.instanceId
	
	local existingInstance = DataPredictNexusInstancesArray[instanceId]

	if existingInstance then return existingInstance end
	
	local address: string = propertyTable.address
	
	local port: string = propertyTable.port or defaultPort
	
	local apiKey: string = propertyTable.apiKey
	
	local encryptionKey: string = propertyTable.encryptionKey
	
	local syncTime: number = propertyTable.syncTime or defaultSyncTime
	
	if (not encryptionKey) then warn("Without an encryption key, the data will not be encrypted. This means that the hackers can intercept the unencrypted data.") end

	local logArray = {}

	local syncThread = nil
	
	local function addLog(logType, logMessage)
		
		if (not table.find(logTypeArray, logType)) then error("Invalid log type.") end
		
		table.insert(logArray, {logType, logMessage})
		
	end
	
	local function deleteLog(position)
		
		table.remove(logArray, position)
		
	end
	
	local function clearAllLogs()
		
		table.clear(logArray)
		
	end
	
	local function onSucessfulSync(responseBody)
		
		
		
	end
	
	local function onSync()
		
		local addressWithPort = address .. ":" .. port
		
		local requestDictionary = {
			
			apiKey = apiKey,
			
		}
		
		local requestBody = HttpService:JSONEncode(requestDictionary)
		
		local success, responseBody = pcall(function() return HttpService:PostAsync(addressWithPort, requestBody, Enum.HttpContentType.ApplicationJson) end)

		if (not success) then addLog("Error", "Unable to fetch response from " .. addressWithPort .. ".") return end
		
		onSucessfulSync(responseBody)
		
	end
	
	local function startSync()
		
		if (syncThread) then error("Already syncing.") end
		
		syncThread = task.spawn(function()
			
			while true do
				
				onSync()
				
				task.wait(syncTime)
				
			end
			
		end)
		
	end
	
	local function stopSync()
		
		if (not syncThread) then error("Currently not syncing.") end
		
		task.cancel(syncThread)
		
		syncThread = nil
		
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
