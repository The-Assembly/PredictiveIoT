
require "log"
require "json"
require "tablex"

local base = _G
local os = base.os
local table = base.table
local log = base.log
local json = base.json
local string = base.string
local type = base.type
local tw_utils = base.tw_utils
local tw_dir = base.tw_dir
local tw_mutex = base.tw_mutex
local fmt = base.string.format
local pcall = base.pcall
local assert = base.assert
local pairs = base.pairs
local unpack = base.unpack
local error = base.error
local math = base.math
local tonumber = base.tonumber
local tostring = base.tostring
local io = base.io

base.tw_service = {}
local tw_service = base.tw_service
local tw_script = base.tw_script

--------------------------------------------------------------------------------
-- A collection of utility functions. The functions in this module are
-- automatically added to tw_utils for convenience.
--------------------------------------------------------------------------------
module "thingworx.utils"

-- Path constants used in this script
PATH_PROPS = "Properties"
PATH_SVCS  = "Services"


--------------------------------------------------------------------------------
-- Returns the REST URL path to a given Thing's service.
--
-- @param thing The name of Thing
-- @param service The name of the service
--
-- @return The RESTful path to the service
--
function EMS_SVC_PATH(thing, service)
  return fmt("/Thingworx/Things/%s/Services/%s", thing, service)
end

--------------------------------------------------------------------------------
-- Returns the REST URL path to a given Thing's Events.
--
-- @param thing The name of Thing
-- @param event The name of the event
--
-- @return The RESTful path to the event
--
function EMS_EVENT_PATH(thing, event)
  return fmt("/Thingworx/Things/%s/Events/%s", thing, event)
end

--------------------------------------------------------------------------------
-- Returns the REST URL path to a given Thing's property.
--
-- @param thing The name of Thing
-- @param property The name of the property
--
-- @return The RESTful path to a property
--
function EMS_PROP_PATH(thing, prop)
  return fmt("/Thingworx/Things/%s/Properties/%s", thing, prop)
end

--------------------------------------------------------------------------------
-- Returns the REST URL path to a given Thing's PropertiesVTQ.
--
-- @param thing The name of Thing
--
-- @return The RESTful path to the Thing's PropertiesVTQ
--
function EMS_PROPS_VTQ_PATH(thing, prop)
  return fmt("/Thingworx/Things/%s/PropertiesVTQ/*", thing)
end

--------------------------------------------------------------------------------
-- Returns the REST URL path to a given Thing's event.
--
-- @param thing The name of Thing
-- @param event The name of the event
--
-- @return The RESTful path to an event
--
function EMS_EVENT_PATH(thing, event)
  return fmt("/Thingworx/Things/%s/Events/%s", thing, event)
end

--------------------------------------------------------------------------------
-- Creates a table that can be used as the headers parameter for HTTP calls.
-- By default, the table will contain the following header values:
-- <ul>
--  <li>content-type: application/json</li>
--  <li>host: localhost</li>
-- </ul>
-- A different host and content type can be specified using the first two
-- parameters to this method. Additional headers can be specified in the
-- headers parameter.
--
-- @param host The value to use as the host header. Defaults to 'localhost'.
-- @param contentType The value to use as the content-type header. Defaults
--                    to 'application/json'.
-- @param headers Any additional headers that should be in the final table.
--
-- @return A table of HTTP headers that always includes host and content-type.
--
function REQ_HEADERS(host, contentType, headers)
  local t = headers or {}
  host = host or 'localhost'
  contentType = contentType or 'application/json'
  t['content-type'] = contentType
  t['host'] = host
  return t
end

--------------------------------------------------------------------------------
-- Creates a table that can be used as the headers for HTTP responses.
-- By default, the table will contain the following header values:
-- <ul>
--  <li>content-type: application/json</li>
-- </ul>
-- A different content type can be specified using the first
-- parameter to this method. Additional headers can be specified in the
-- headers parameter.
--
-- @param contentType The value to use as the content-type header. Defaults
--                    to 'application/json'.
-- @param headers Any additional headers that should be in the final table.
--
-- @return A table of HTTP headers that always includes content-type.
--
function RESP_HEADERS(contentType, headers)
  local t = headers or {}
  contentType = contentType or 'application/json'
  t['content-type'] = contentType
  return t
end

--------------------------------------------------------------------------------
-- Converts a table of key/value pairs to a string of key=value pairs,
-- separated by a given string.
--
-- @param t The table to be joined into a string.
-- @param sep The string to use as a separator. Defaults to ", ".
--
function toString(t, sep)
  sep = sep or ", "
  local s = table.toString(t)
  return s:gsub("\n", sep)
end

--------------------------------------------------------------------------------
-- Convert a value to a Lua boolean.
--
-- @param b The value to convert.
--
-- @return If b is a boolean, then b will be returned.
--         If b is a string, the false will be returned if b:lower() is equal
--         to 'false'. If b is a number, then false will be returned if it is
--         equal to 0. For other types, false will be returned if b is nil.
--         Otherwise, true will be returned.
--
function toboolean(b)
  if type(b) == 'boolean' then
    return b
  end

  if type(b) == 'string' and b:lower() == 'false' then
    return false
  elseif type(b) == 'number' and b == 0 then
    return false
  elseif not b then
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- Creates a 3 element table representing the given property as a VTQ:
-- <pre>{ value = 100, quality = "GOOD", time = 1234567890112 }</pre>
--
-- @param prop The table representing the property, from the Thing's
--             properties table.
--
-- @return A table representing this property as a VTQ.
--
function toVTQ(prop)
  local t = {}
  local name = prop.name or "value"
  t['value']   = prop.value
  t['time']    = prop.time or os.time() * 1000
  t['quality'] = prop.quality or "UNKNOWN"
  return t
end

--------------------------------------------------------------------------------
-- Creates VTQ table from the property, but represent the value as a Variant:
-- <pre>{ value = {baseType = "NUMBER", value = 100}, quality = "GOOD", time = 1234567890112 }</pre>
--
-- @param prop The table representing the property, from the Thing's
--             properties table.
--
-- @return A table representing this property as a VTQ.
--
function toVariantVTQ(prop)
  local t = {}
  local name = prop.name or "value"
  t['value']   = { baseType = prop.baseType, value = prop.value } -- variant format for JSON
  t['time']    = prop.time or os.time() * 1000
  t['quality'] = prop.quality or "UNKNOWN"
  return t
end

--------------------------------------------------------------------------------
-- Returns the given property as a VTQ encoded into a JSON string.
--
-- @param prop The property to encode.
--
-- @return A JSON string representing the property as a VTQ.
--
function toJsonVTQ(prop)
  local t = toVTQ(prop)
  local success, data = encodeData(t)

  if success then
    return data
  else
    return "Could not encode property"
  end
end

--------------------------------------------------------------------------------
-- Returns the given property as an infotable encoded into a JSON string.
--
-- @param prop The property to encode.
--
-- @return A JSON string representing the property as a infotable.
--
function toJsonInfotable(pt)
  tw_mutex.lock()
  local name = pt.name
  local baseType = pt.baseType
  local dataShape = pt.dataShape
 
  local fieldDefinitions = {}
  fieldDefinitions[name] = { name = name, description = "", baseType = baseType, aspects = {}}
  fieldDefinitions.time  = { name = "time", description = "", baseType = "DATETIME", aspects = {}}
  
  local t = {}
  t.dataShape = { fieldDefinitions = fieldDefinitions }
  t.rows = {}
  
  if baseType == "INFOTABLE" then -- Need to insert dataShape
    t.dataShape.fieldDefinitions[name].aspects.dataShape = dataShape
  end
  
  t.rows[1] = { [name] = pt.value, time = pt.time }
  
  local result = json.encode(t)
  tw_mutex.unlock()
  return result
end

--------------------------------------------------------------------------------
-- Determine if a given string is JSON.
--
-- @param str The string to check
--
-- @return True if the str is decodable, false otherwise.
--
function isJson(str)
  local success, t = pcall(json.decode, str)
  return success and t and type(t) == 'string' -- Success only if decode executed and result is not nil
end

--------------------------------------------------------------------------------
-- Encodes the given table into a valid JSON string. In the case of success,
-- it returns true, followed by the encoded string. If encoding fails, it
-- returns false, followed by an error message.
--
-- @param data The Lua table to encode.
--
-- @return True if successful, followed by the encoded string. False on
--         failure, followed by an error message.
--
function encodeData(data)
  local result = "{}" -- Default return if data is nil
  local success = true
  if data and base.type(data) ~= 'table' then
    success = false
    result = "Data must be a table"
    log.warn(_NAME, "Attempting to encode a non-table into a JSON string")
  elseif data and base.next(data) then
    -- There is data, and it is not an empty table. json.encode transforms
    -- empty tables to [], which Thingworx doesn't like.
    success, result = base.pcall(json.encode, data)
    if not success then
      result = "Could not encode lua table into JSON string"
      log.warn(_NAME, "Could not encode lua table into JSON string")
    end
  end
  return success, result
end

--------------------------------------------------------------------------------
-- Takes a path or URL, removes everything before the '?' character, and then
-- parses the remaining string into a table of query parameter.
--
-- @param path The path to be parsed.
--
-- @return The
function parseQueryParams(path)

  local queryTable = {}
  local queryString = ""

  if string.find(path, "?") then
    queryString = string.sub(path, string.find(path, "?") + 1)
    -- Remove the queryString from path
    path = string.sub(path, 1, string.find(path, "?") - 1)
    -- Create our queryString table
  end

  local tempTable = {}
  local queryTable = {}

  -- Separate by the '&' delimeter
  local x = 1
  for w in string.gmatch(queryString, "[^&]+") do
    tempTable[x] = w
    x = x + 1
  end

  -- Get the key/value pairs
  for _,v in pairs(tempTable) do
    queryTable[string.sub(v, 1, string.find(v,"=") - 1)] = string.sub(v, string.find(v,"=") + 1)
  end

  return path, queryTable
end

--------------------------------------------------------------------------------
-- Inspects a property and determines if its current value differs from its
-- previous value according to the following data change rules:
--
-- <ol>
--  <li>If the property's pushType is ALWAYS return true</li>
--  <li>If the property's pushType is NEVER return false</li>
--  <li>If the property's pushType is VALUE then return true if the property
--      is a NUMBER and its change exceeds its configured threshold, or return
--      true if it is not a NUMBER and its current and previous values are
--      different.</li>
-- </ol>
--
-- @param pt The full property table of the property to be inspected.
--
-- @return True if the property has changed. False otherwise.
--
function evaluateChange(pt)
  if pt.pushType == "ALWAYS" then return true  end
  if pt.pushType == "NEVER"  then return false end

  if pt.pushType == "VALUE" then

    -- This will be set if the property's definition was just updated from the
    -- server, or if the property's value was just set via setProperty.
    if pt.forcePush then return true end

    if pt.baseType == "STRING"   or
       pt.baseType == "BOOLEAN"  or
       pt.baseType == "DATETIME" or
       pt.baseType == "IMAGE"    or
       pt.baseType == "JSON"     or
       pt.baseType == "XML"      or
       pt.baseType == "INFOTABLE" then
       if pt.value ~= pt.prev.value then
         return true
       end
    elseif pt.baseType == "NUMBER" or pt.baseType == "INTEGER" then
       local delta = math.abs((tonumber(pt.value) or 0) - (tonumber(pt.prev.value) or 0))
       if delta > tonumber(pt.pushThreshold) then
         log.trace("utils::evaluateChange", "Property %s change of %d exceeds pushThreshold of %d", pt.name, delta, pt.pushThreshold)
         return true
       end
    elseif pt.baseType == "LOCATION" then
       -- Make sure the location's value
       if type (pt.value)      ~= 'table' then pt.value      = { latitude = 0, longitude = 0, elevation = 0 } end
       if type (pt.prev.value) ~= 'table' then pt.prev.value = { latitude = 0, longitude = 0, elevation = 0 } end

       -- Now compare each component of the location, checking for a change
       if pt.value.latitude  ~= pt.prev.value.latitude  or
          pt.value.longitude ~= pt.prev.value.longitude or
          pt.value.elevation ~= pt.prev.value.elevation then
          return true
       end
    end
  end

  return false
end

--------------------------------------------------------------------------------
-- Enclose the given function within a critical section created using the
-- executing script's global tw_mutex object. If the function fails during
-- the execution, scopelock will ensure that the mutex is freed. This helps
-- to prevent a rogue unlocked mutex that would result in deadlock.
--
function scopelock(func, ...)

  local result

  tw_mutex.lock()
  result = { pcall(func, ...) }
  tw_mutex.unlock()

  if result[1] == true then
    return unpack(result, 2)
  end

  error(result[2])
end

--------------------------------------------------------------------------------
-- Determine if the host system is a Windows OS.
--
-- @return True is the host system is a Windows OS.
--
function isWindows()
  return tw_utils.host_os() == "win32"
end

-- -----------------------------------------------------------------------
-- Add the above functions to the tw_utils library
-- -----------------------------------------------------------------------

if tw_utils then
  log.debug("utils", "Adding utils functions to tw_utils")
  for k,v in base.pairs(_M) do
    tw_utils[k] = v
  end
end

-- -----------------------------------------------------------------------
-- Add some utility functions to the directory library
-- -----------------------------------------------------------------------

tw_dir.move = function(src, dest)
  if not src or not dest then return nil end
  local cmd
  if isWindows() then
    cmd = fmt('move /Y "%s" "%s"', tw_dir.fixPath(src), tw_dir.fixPath(dest))
  else
    cmd = fmt("mv %s %s", tw_dir.fixPath(src), tw_dir.fixPath(dest))
  end
  log.debug("move", "Executing: %s", cmd)
  return os.execute(cmd)
end

tw_dir.copy = function(src, dest)
  if not src or not dest then return nil end
  local cmd
  if isWindows() then
    cmd = fmt('copy /Y "%s" "%s"', tw_dir.fixPath(src), tw_dir.fixPath(dest))
  else
    cmd = fmt("cp %s %s", tw_dir.fixPath(src), tw_dir.fixPath(dest))
  end
  log.debug("copy", "Executing: %s", cmd)
  return os.execute(cmd)
end

tw_dir.size = function(file)
  local success, ft = pcall(tw_dir.getFileInfo, file)
  if success then
    return ft.size
  end
  return nil
end

tw_dir.mkdir = function(dir)
  if not dir then return nil end
  local cmd
  if isWindows() then
    cmd = fmt("mkdir %s", tw_dir.fixPath(dir))
  else
    cmd = fmt("mkdir -p %s", tw_dir.fixPath(dir))
  end
  log.debug("mkdir", "Executing: %s", cmd)
  return os.execute(cmd)
end

tw_dir.remove = function(file)
  if not file then return nil end
  if not tw_dir.exists(file) then return 0 end
  local cmd
  if isWindows() then
    cmd = fmt('del "%s"', tw_dir.fixPath(file))
  else
    if tw_dir.isDir(file) then
      cmd = "rm -r"
    else
      cmd = "rm"
    end
    cmd = fmt("%s %s", cmd, tw_dir.fixPath(file))
  end
  log.debug("remove", "Executing: %s", cmd)
  return os.execute(cmd)
end

tw_dir.exists = function(file)
  return (tw_dir.getFileInfo(file) ~= nil)
end

tw_dir.isDir = function(dir)
  if not dir then return false end
  local result = tw_dir.getFileInfo(dir)
  return result and result.isDir
end

tw_dir.isFile = function(file)
  if not file then return false end
  local result = tw_dir.getFileInfo(file)
  return result and result.isFile
end

tw_dir.waitForFile = function(file, timeout)
  local stop = tw_utils.currentTime() + timeout-- time in ms
  while tw_utils.currentTime() < stop and not tw_dir.exists(file) do
    tw_utils.psleep(100)
  end
  return tw_dir.exists(file)
end

tw_dir.dwell = function(name, wait, info)
  log.trace("dwell", "Checking %s for change", name)
  wait = wait or 25
  local changed = 1
  local info = info or tw_dir.getFileInfo(name)
  while info and changed == 1 do
      tw_utils.psleep(wait)
      log.trace("dwell", "Checking %s for change: %s",
                name, tw_utils.toString(info))
      info, changed = tw_dir.fileChanged(name, info)
  end

  if info then
      log.trace("dwell", "Dwell complete. File has stopped changing: %s", name)
  else
      log.trace("dwell", "Dwell complete. File not found: %s", name)
  end

  return info
end

tw_dir.chmod = function(file, perm)
  if isWindows() then return true end
  if not file or not perm then return nil end

  local cmd = fmt("chmod %s %u", perm, file)
  log.debug("chmod", "Executing: %s", cmd)
  return os.execute(cmd)
end

-- -----------------------------------------------------------------------
-- Some utility functions for services
-- -----------------------------------------------------------------------

tw_service.start = function(name, waitTime)
	local result = false

	waitTime = waitTime or 0
	log.debug("tw_service.start", "Start Service: %s", name)
	if isWindows() then
		os.execute("sc start "..name)
		if waitTime > 0 then
			result = tw_service.waitForState(name, "RUNNING", waitTime)
		else
			result = true
		end
	end

	return result
end

tw_service.stop = function(name, waitTime)
	local result = false

	waitTime = waitTime or 0
	log.debug("tw_service.stop", "Stop Service: %s", name)
	if isWindows() then
		os.execute("sc stop "..name)
		if waitTime > 0 then
			result = tw_service.waitForState(name, "STOPPED", waitTime)
		else
			result = true
		end
	end

	return result
end

tw_service.waitForState = function (name, state, waitTime)
	waitTime = waitTime or 60

	local finished = false
	local timeWaited = 0
	local result = false

	if isWindows() then
		while not finished do
			finished = true
			for line in io.popen("sc query "..name):lines() do
				if string.find(line, "STATE", 1, true) then
					if not string.find(line, state, 1, true) then
						finished = false
						log.debug("tw_service.waitForState", "Waiting for Service [%s] to enter the [%s] state.", name, state)
					else
						result = true
					end
				end
			end

			--only perform timeout logic if the state has not been found
			if not finished then
				tw_utils.psleep(5000)
				--if waitTime <= 0 then wait indefinately
				if waitTime > 0 then
					timeWaited = timeWaited + 5
					if timeWaited >= waitTime then
						result = false
						finished = true
					end
				end
			end
		end
	end

	return result
end

-- -----------------------------------------------------------------------
-- Add some utility functions to the script library
-- -----------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Load a script file.
--
-- @param name The name of the script
-- @param fileName The file name of the script
-- @param timeout The maximum amount of time (in seconds) to wait
--                for the script to start (default = 0, wait indefinately)
--
-- @result true for success, false for failure
--
tw_script.loadScriptFromFile = function (name, fileName, timeout)
	assert(name, "The 'name' parameter is required")
	assert(fileName, "The 'fileName' parameter is required")
	local timeout = timeout or 0
	local result = true

	local addScriptSuccess = true
    local scripts = tw_script.getScriptList()
	if not scripts[name] then
		log.info(name, "Starting %s script.", name)
		result = pcall(tw_script.addScript(name, fileName))
	end

	-- Now wait until it is up and running (only do this if the script is loaded and addscript did not fail)
	if result then
		local elapsedTime = 0
		while tw_script.getStatus(name) ~= "Running" do
			log.debug(name, "Waiting for %s script to initialize: %s", name, tw_script.getStatus(name))
			tw_utils.psleep(1000)
			if timeout > 0 then
				elapsedTime = elapesedTime +1
				if elapsedTime > timeout then
					log.warn(name, "Script %s failed to start", name)
					result = false
					break
				end
			end
		end
	end

	return result
end
