local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local DataPredictLibraryLinker = script.DataPredictLibraryLinker.Value
local TensorL2DLibraryLinker = script.TensorL2DLibraryLinker.Value

local LogStore = DataStoreService:GetDataStore("DataPredictLogStore")

local ResponseDictionaryCacheStore = MemoryStoreService:GetSortedMap("DataPredictNexusResponseDictionaryCacheStore")

local defaultPort = 4444

local defaultSyncTime = 3 * 60

local defaultNumberOfSyncRetry = 3

local defaultSyncRetryDelay = 2

local logTypeArray = {"Normal", "Warning", "Error"}

local responseDictionaryCacheKey = "latestResponse"

local placeId = game.PlaceId

local gameJobId = game.JobId

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
	
	local modelDataArray = {}
	
	local logArray = {}

	local isSyncThreadRunning = false
	
	local function addLog(logType, logMessage)
		
		if (not table.find(logTypeArray, logType)) then error("Invalid log type.") end
		
		local currentTime = os.time()
		
		local logInfoArray = {currentTime, logType, logMessage}
		
		table.insert(logArray, logInfoArray)
		
		local success, errorMessage = pcall(function() 
			
			local jobIdString = tostring(gameJobId)
			
			LogStore:SetAsync(jobIdString, logArray) 
			
		end)
		
		if (not success) then warn("Failed to save log to DataStore: " .. errorMessage) end
		
	end
	
	local function removeLog(position)
		
		table.remove(logArray, position)
		
	end
	
	local function getLogArray()
		
		return logArray
		
	end
	
	local function clearAllLogs()
		
		table.clear(logArray)
		
	end
	
	local function onCommandReceived(command, valueDictionary)
		
		local commandFunction = commandFunctionArray[command]
		
		if (not commandFunction) then addLog("Error", "Command function for " .. command .. " does not exist.") return end
		
		local commandSuccess = pcall(commandFunction, valueDictionary)
		
		if (not commandSuccess) then addLog("Error", "Unable to run " .. command .. " command.") end
		
	end
	
	local function processResponseDictionary(responseDictionary)
		
		for command, valueDictionary in responseDictionary do
			
			onCommandReceived(command, valueDictionary)
			
		end
		
	end
	
	local function fetchResponseDictionary()
		
		local cachedResponseDictionary = ResponseDictionaryCacheStore:GetAsync(responseDictionaryCacheKey)
		
		if (cachedResponseDictionary) then return cachedResponseDictionary end
		
		local addressWithPort = address .. ":" .. port
		
		local requestDictionary = {
			
			apiKey = apiKey,
			
		}
		
		local requestBody = HttpService:JSONEncode(requestDictionary)
		
		local currentSyncRetryDelay = syncRetryDelay
		
		for attempt = 1, numberOfSyncRetry, 1 do
			
			local responseSuccess, responseBody = pcall(function() return HttpService:PostAsync(addressWithPort, requestBody, Enum.HttpContentType.ApplicationJson) end)
			
			if (responseSuccess) then
				
				local decodeSuccess, responseDictionary = pcall(function() return HttpService:JSONDecode(responseBody) end)
				
				if (decodeSuccess) then
					
					ResponseDictionaryCacheStore:SetAsync(responseDictionaryCacheKey, responseDictionary, 60) -- Cache for 60 seconds
					
					return responseDictionary
					
				else
					
					addLog("Error", "Failed to decode ML response: " .. responseBody)
					
				end
				
			end
			
			addLog("Warning", "Sync attempt " .. attempt .. " failed. Retrying in " .. syncRetryDelay .. " seconds.")
			
			task.wait(currentSyncRetryDelay)
			
			currentSyncRetryDelay = currentSyncRetryDelay * 2 -- Exponential backoff
			
		end
		
		addLog("Warning", "Unable to fetch response from " .. addressWithPort .. ".")
		
		return nil
		
	end
	
	local function startSync()
		
		if (isSyncThreadRunning) then error("Already syncing.") end
		
		isSyncThreadRunning = true
		
		task.spawn(function()
			
			while isSyncThreadRunning do
				
				local responseDictionary = fetchResponseDictionary()
				
				if responseDictionary then processResponseDictionary(responseDictionary) end
				
				task.wait(syncTime)
				
			end
			
		end)
		
	end
	
	local function stopSync()
		
		if (not isSyncThreadRunning) then error("Currently not syncing.") end
		
		isSyncThreadRunning = false
		
	end
	
	local function addCommand(commandName, functionToRun)
		
		commandFunctionArray[commandName] = functionToRun
		
	end
	
	local function removeCommand(commandName)
		
		commandFunctionArray[commandName] = nil
		
	end
	
	local function addModel(modelName, Model, modelParameterNames)
		
		modelDataArray[modelName] = {Model, modelParameterNames}
		
	end
	
	local function removeModel(modelName)
		
		modelDataArray[modelName] = nil
		
	end
	
	local function replaceModelParameters(valueDictionary)
		
		local modelName = valueDictionary.modelName
		
		local ModelParameters = valueDictionary.ModelParameters
		
		local modelData = modelDataArray[modelName]
		
		if (not modelData) then addLog("Error", modelName .. " does not exist when calling the \"replaceModelParameters\" command.") return end
		
		if (not ModelParameters) then addLog("Error", modelName .. " model parameters does not exist when calling the \"replaceModelParameters\" command.")  return end
		
		local Model = modelData[1]
		
		if (not Model) then addLog("Error", modelName .. " model does not exist when calling the \"replaceModelParameters\" command.") return end
		
		addLog("Normal", modelName .. " model parameters has been replaced using the \"replaceModelParameters\" command.")
		
		Model:setModelParameters(ModelParameters)

	end
	
	game:BindToClose(function()
		
		isSyncThreadRunning = false
		
	end)
	
	commandFunctionArray["replaceModelParameters"] = replaceModelParameters
	
	return {
		
		addLog = addLog,
		removeLog = removeLog,
		getLogArray = getLogArray,
		clearAllLogs = clearAllLogs,
		
		startSync = startSync,
		stopSync = stopSync,
		
		addCommand = addCommand,
		removeCommand = removeCommand,
		
		addModel = addModel,
		removeModel = removeModel,
		
	}
	
end

return DataPredictNexus
