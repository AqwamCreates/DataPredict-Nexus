local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local DataPredictLibraryLinker = script.DataPredictLibraryLinker.Value
local TensorL2DLibraryLinker = script.TensorL2DLibraryLinker.Value

local defaultPort = 4444

local defaultSyncTime = 3 * 60

local defaultNumberOfSyncRetry = 3

local defaultSyncRetryDelay = 2

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
	
	local numberOfSyncRetry = propertyTable.numberOfSyncRetry or defaultNumberOfSyncRetry
	
	local syncRetryDelay = propertyTable.syncRetryDelay or defaultSyncRetryDelay
	
	if (not encryptionKey) then warn("Without an encryption key, the data will not be encrypted. This means that the hackers can intercept the unencrypted data.") end
	
	local commandFunctionArray = {}
	
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
	
	local function onCommandReceived(command, value)
		
		local commandFunction = commandFunctionArray[command]
		
		if (not commandFunction) then addLog("Warning", "Command function for " .. command .. " does not exist.") return end
		
		commandFunction(value)
		
	end
	
	local function processResponseDictionary(responseDictionary)
		
		for command, value in responseDictionary do
			
			onCommandReceived(command, value)
			
		end
		
	end
	
	local function fetchResponseDictionary()
		
		local addressWithPort = address .. ":" .. port
		
		local requestDictionary = {
			
			apiKey = apiKey,
			
		}
		
		local requestBody = HttpService:JSONEncode(requestDictionary)
		
		local currentSyncRetryDelay = syncRetryDelay
		
		for attempt = 1, numberOfSyncRetry, 1 do
			
			local success, responseBody = pcall(function() return HttpService:PostAsync(addressWithPort, requestBody, Enum.HttpContentType.ApplicationJson) end)
			
			if success then return HttpService:JSONDecode(responseBody) end
			
			addLog("Warning", "Sync attempt " .. attempt .. " failed. Retrying in " .. syncRetryDelay .. " seconds.")
			
			task.wait(currentSyncRetryDelay)
			
			currentSyncRetryDelay = currentSyncRetryDelay * 2 -- Exponential backoff
			
		end
		
		addLog("Warning", "Unable to fetch response from " .. addressWithPort .. ".")
		
		return nil
		
	end
	
	local function startSync()
		
		if (syncThread) then error("Already syncing.") end
		
		syncThread = task.spawn(function()
			
			while true do
				
				local responseDictionary = fetchResponseDictionary()
				
				if responseDictionary then processResponseDictionary(responseDictionary) end
				
				task.wait(syncTime)
				
			end
			
		end)
		
	end
	
	local function stopSync()
		
		if (not syncThread) then error("Currently not syncing.") end
		
		task.cancel(syncThread)
		
		syncThread = nil
		
	end
	
	local function addCommand(commandName, functionToRun)
		
		commandFunctionArray[commandName] = functionToRun
		
	end
	
	local function removeCommand(commandName)
		
		commandFunctionArray[commandName] = nil
		
	end
	
	return {
		
		addLog = addLog,
		deleteLog = deleteLog,
		clearAllLogs = clearAllLogs,
		
		startSync = startSync,
		stopSync = stopSync,
		
		addCommand = addCommand,
		removeCommand = removeCommand
		
	}
	
end

return DataPredictNexus
