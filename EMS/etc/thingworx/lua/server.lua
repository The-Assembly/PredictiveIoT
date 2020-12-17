
require "log"
require "json"
require "utils"
require "types.datashape"

local base = _G
local log = base.log
local json = base.json
local table = base.table
local fmt = base.string.format
local print = base.print
local pairs = base.pairs
local ipairs = base.ipairs
local tonumber = base.tonumber
local p_data = base.p_data
local tw_ems = base.tw_ems
local tw_utils = base.tw_utils
local tw_mutex = base.tw_mutex
local tw_infotable = base.tw_infotable
local os = base.os
local DataShape = base.DataShape

local REQ_HEADERS = tw_utils.REQ_HEADERS()

--
-- Define this DataShape here. It is used to push properties to the server
--
-- Not currently used. InfoTables for UpdateSubscribedPropertyValues are
-- created manually in setProperties function.close
--[[
dataShapes.NamedVTQ(
  { name="name",    baseType="STRING" },
  { name="value",   baseType="VARIANT" },
  { name="time",    baseType="DATETIME" },
  { name="quality", baseType="STRING" }
)

dataShapes.PropertyUpdate(
  { name="values", baseType="INFOTABLE", aspects={dataShape="NamedVTQ"} }
)
--]]

--------------------------------------------------------------------------------
-- An API to access properties, services, and event dispatching on the
-- ThingWorx server. This functionality is accessed by making the appropriate
-- calls to the script resource's associated remote application proxy.
--------------------------------------------------------------------------------

module "thingworx.server"

--
-- Indicates if the script resource was able to connect to the EMS on
-- its last request.
--
available = false

--
-- Indicates if the EMS was connected as of the script resource's last request.
--
online = false

local function setAvailable(b)
  if b ~= available and b then
    log.info(p_data.name, "MicroServer is now available.")
  elseif b ~= available then
    log.warn(p_data.name, "Cannot connect to MicroServer. Setting to unavailable.")
  end
  available = b
end

local function setOnline(b)
  if b ~= online and b then
    log.info(p_data.name, "MicroServer is online.")
  elseif b ~= online then
    log.warn(p_data.name, "MicroServer is not online")
  end
  online = b
end

local function offlineCheck(code, resp)
  log.trace(_NAME, "Results - code: %d, resp: %s", code, resp)

  if code == 200 then
    setAvailable(true)
    setOnline(true)
  else
    log.info(p_data.name, "Error occured while accessing EMS. Checking isConnected.")
    local resp, code = tw_ems.get("/Thingworx/Things/LocalEms/Properties/isConnected")
    local s, jdata = base.pcall(json.decode, resp)
    local isConn = false

    if s and jdata and jdata.rows and jdata.rows[1] then
      -- Response was JSON. Check to see if it indicated that the EMS is online
      isConn = (jdata.rows[1].result == true) or (jdata.rows[1].isConnected == true)
    end

    setOnline(isConn)

    if code == 200 then
      setAvailable(true)
    elseif code == 503 then
      -- If there was a JSON response then the EMS was at least running,
      -- otherwise, it is probably unavailable.
      setAvailable(isConn)
    else
      setAvailable(true)
    end

    log.info(p_data.name, "EMS is available: %s, online: %s", available, online)
  end

  return code, resp
end

-- Return the name of the thing executing the current script. This will 
-- return the identifier of the thing or the name of the script, which 
-- is the thing name.
local function getThingName() 
  if p_data.identifier then
    return '*' .. p_data.identifier 
  end
  return p_data.name
end

--------------------------------------------------------------------------------
-- Make a HTTP Get request against a path on the EMS.
--
-- @param path The path of the request.
--
-- @return Status code, followed by a response.
--
function get(path)
  local resp, code = tw_ems.get(path)
  return offlineCheck(code, resp)
end

--------------------------------------------------------------------------------
-- Make a HTTP Put request against a path on the EMS.
--
-- @param path The path of the request.
-- @param data Request data.
-- @param headers Request headers.
--
-- @return Status code, followed by a response.
--
function put(path, data, headers)
  local resp, code = tw_ems.put(path, data, headers)
  return offlineCheck(code, resp)
end

--------------------------------------------------------------------------------
-- Make a HTTP Post request against a path on the EMS.
--
-- @param path The path of the request.
-- @param data Request data.
-- @param headers Request headers.
--
-- @return Status code, followed by a response.
--
function post(path, data, headers)
  local resp, code = tw_ems.post(path, data, headers)
  return offlineCheck(code, resp)
end

--------------------------------------------------------------------------------
-- Make a HTTP Delete request against a path on the EMS.
--
-- @param path The path of the request.
--
-- @return Status code, followed by a response.
--
function delete(path)
  local resp, code = tw_ems.delete(path)
  return offlineCheck(code, resp)
end

--------------------------------------------------------------------------------
-- Calls a service on a given Thing.
--
-- @param service The name of the service to call.
-- @param data A Lua table containing the input parameters to the service. If
--             the service doesn not have any input parameters this parameter
--             may be nil.
-- @param thing The name of the Thing to execute the service on. If this
--              parameter is nil then the name of the calling Thing will be
--              used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this string will be a JSON object and can be
--                  passed to json.decode() in order to create a Lua table.</li>
--      </ul>
--
function invoke(service, data, thing)
  if not service then
    log.warn(_NAME, "Could not invoke service if no service name is provided")
    return 404, "Invoking a service with no service name is not possible"
  end

  local thingname = thing or getThingName()
  local path = tw_utils.EMS_SVC_PATH(thingname, service)
  local encode_success = false
  local postdata

  encode_success, postdata = tw_utils.encodeData(data)

  if not encode_success then return 400, "Could not encode JSON data" end

  log.debug(_NAME, "Invoking %s on server. content: %s", path, postdata)
  return post(path, postdata, REQ_HEADERS)
end

--------------------------------------------------------------------------------
-- Gets a property from a Thing.
--
-- @param property The name of the property to retreive. This must be the name
--                 of the property at the server.
-- @param thing The name of the Thing to execute the property request on. If
--              this parameter is nil then the name of the calling Thing will
--              be used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                    of success this string will be a JSON object containing
--                    the property value and can be passed to json.decode()
--                    in order to create a Lua table.
--      </ul>
--
function getProperty(property, thing)
  if not property then
    log.warn(_NAME, "Could not get property if no property name is provided")
    return 404, "Getting a property with no property name is not possible"
  end

  local thingname = thing or getThingName()
  local path = tw_utils.EMS_PROP_PATH(thingname, property)

  log.debug(_NAME, "Getting %s from server.", path)
  return get(path)
end

--------------------------------------------------------------------------------
-- Sets a property on a Thing. If a property name and a data table is provided,
-- then this function will route the property set directly to the indicated
-- thing and <strong>not</strong> use the Channel infrastructure. In most cases
-- it is preferable to supply a property table as the first parameter and allow
-- the framework to use the Channel infrastructure.
--
-- @param property The name of the property to set. This must be the name
--                 of the property at the server. - OR -
--                 The property table representing the property. If a table is
--                 used then the data and thing parameters will be ignored.
-- @param data A Lua table containing the new property value. The key in the table
--             should be the name of the property, or the string 'value'. The
-- @param thing The name of the Thing to execute property set on. If this
--              parameter is nil then the name of the calling Thing will be
--              used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this can be ignored.</li>
--      </ul>
--
function setProperty(property, data, thing)
  if not property then
    log.warn(_NAME, "Could not set property. No property name is provided")
    return 404, "Setting a property with no property name is not possible"
  end

  -- If a full property table was passed in then we handle it differently
  if base.type(property) == "table" then
    log.trace(_NAME, "Calling setProperty with table param.")
    return _setProperty(property, thing)
  end

  local thingname = thing or getThingName()
  local encode_success, postdata = tw_utils.encodeData(data)
  local path = tw_utils.EMS_PROP_PATH(thingname, property)

  if not encode_success then
    log.warn(_NAME, "Could not set property %s on server. Could not encode JSON data", path)
    return 400, "Could not encode JSON data"
  end

  log.debug(_NAME, "Setting property %s on server. content: %s", path, postdata)
  local code, resp = put(path, postdata, REQ_HEADERS)

  if code ~= 200 then
    log.warn(_NAME, "Could not set property %s on server. code: %d, resp: %s", path, code, resp)
  end

  return code, resp
end

--------------------------------------------------------------------------------
-- Sets serveral properties on a Thing.
--
-- @param properties A table containing the properties to set
-- @param thing The name of the EdgeThing that is sending the property update.
--              If this parameter is nil then the name of the calling Thing
--              will be used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                    of success this can be ignored.</li>
--      </ul>
--
function setProperties(properties, thing)
  if not properties then
    log.warn(_NAME, "Could not set properties.  No properties were provided.")
    return 404, "Setting properties with no properties supplied is not possible"
  end

  local chunks = {}
  local chunk = {}
  local count = 0
  local max_count = tonumber(p_data.maxConcurrentPropertyUpdates) or 100

  tw_mutex.lock()
  for _,prop in pairs(properties) do
    if count == max_count then
      log.debug(_NAME, "Created batch of %d properties to be pushed to the server.", #chunk)
      table.insert(chunks, chunk)
      chunk = {}
      count = 0
    end

    local vtq = tw_utils.toVariantVTQ(prop)
    vtq.name = prop.name
    table.insert(chunk, vtq)

    log.trace(_NAME, "Adding property to list: %s", vtq.name)

    count = count + 1
  end

  log.debug(_NAME, "Created batch of %d properties to be pushed to the server (last batch of group).", #chunk)
  table.insert(chunks, chunk)
  local code, resp = 200, "No properties pushed"
  local batchcount = 1

  for i,propValues in ipairs(chunks) do

    --local it = tw_infotable.createInfoTable(DataShape.PropertyUpdate:clone())
    local it = {
        rows = {},
        dataShape = {
            fieldDefinitions = {
                values = {
                    name = "values",
                    baseType = "INFOTABLE",
                    aspects = {}
                }
            }
        }
    }
	
    --local vtqIt = tw_infotable.createInfoTable(DataShape.NamedVTQ:clone())
    local vtqIt = {
        rows = {},
        dataShape = {
            fieldDefinitions = {
                name = { name = "name", baseType = "STRING", aspects = {} },
                time = { name = "time", baseType = "DATETIME", aspects = {} },
                quality = { name = "quality", baseType = "STRING", aspects = {} },
                value = { name = "value", baseType = "VARIANT", aspects = {} }, 
            }
        }
    }
    for _,vtq in ipairs(propValues) do
      table.insert(vtqIt.rows, vtq)
      --vtqIt:addRow(vtq)
    end

    --it:addRow({ values = vtqIt})
    table.insert(it.rows, { values = vtqIt }) --:toTable() })

    --local encode_success, postdata = tw_utils.encodeData(params)
    local path = tw_utils.EMS_SVC_PATH(thing or getThingName(), "UpdateSubscribedPropertyValues")

    --if not encode_success then
    --  log.warn(_NAME, "Could not set properties for thing %s", thing or p_data.name)
    --  return 400, "Could not encode JSON data"
    --end

    --local postdata = json.encode(it:toTable())
    local postdata = json.encode(it)
    tw_mutex.unlock()

    log.trace(_NAME, "Setting properties on server. batch: %d, path: %s, content: \n%s", batchcount, path, postdata)
    batchcount = batchcount + 1

    code, resp = post(path, postdata, REQ_HEADERS)

    if code ~= 200 then
      log.warn(_NAME, "Could not set properties on server. code: %d, resp: %s", code, resp)
      break
    else
      log.debug(_NAME, "%s pushed %d properties to server", getThingName(), #propValues)
    end
  end

  return code, resp
end

-- -----------------------------------------------------------------------------
-- Private helper function that sets a property on a Thing using a property
-- table as its parameter. Developers should use the standard setProperty
-- method, which forwards calls to this method based on the type of the
-- provided input param.
--
-- @param property The property table
-- @param thing The name of the Thing to execute property set on. If this
--              parameter is nil then the name of the calling Thing will be
--              used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this can be ignored.</li>
--      </ul>
--
-- @see setProperty
--
function _setProperty(property, thing)
  if not property then
    log.warn(_NAME, "Could not set property. No property table was provided")
    return 404, "Setting a property with no property table is not possible"
  end

  return setProperties({property}, thing)
end

--------------------------------------------------------------------------------
-- Fires an event on the server. The event is routed through the Channel, so
-- that the correct Thing on the server triggers the event.
--
-- @param event The name of the event to fire.
-- @param data A Lua table containing the event data.
-- @param thingName The name of the Thing to fire the event on behalf of. If this
--                  parameter is nil then the name of the calling Thing will be
--                  used (this name is pulled from p_data.name).
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this can be ignored.
--      </ul>
--
function fireEvent(event, data, thingName)
  if not event then
    log.warn(_NAME, "Could not fire event if no event name is provided")
    return 404, "Firing an event with no event name is not possible"
  end

  local path = tw_utils.EMS_EVENT_PATH(thingName or getThingName(), event)
  local encode_success, postdata = tw_utils.encodeData(data)
  
  log.debug(_NAME, "Invoking %s on server. content: %s", path, postdata)
  return post(path, postdata, REQ_HEADERS)
end

--------------------------------------------------------------------------------
-- Calls a Channel service on the server via the EMS.
--
-- @param service The name of the service to call.
-- @param data A Lua table containing the input parameters to the service. If
--             the service doesn not have any input parameters this parameter
--             may be nil.
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this string will be a JSON object and can be
--                  passed to json.decode() in order to create a Lua table.
--      </ul>
--
--
function invokeChannel(service, data)
  return invoke(service, data, "me")
end

--------------------------------------------------------------------------------
-- Calls a local service on the EMS.
--
-- @param service The name of the service to call.
-- @param data A Lua table containing the input parameters to the service. If
--             the service doesn not have any input parameters this parameter
--             may be nil.
--
-- @return The following two values:
--      <ul>
--        <li>code: The HTTP status code from the service call</li>
--        <li>resp: A string containing the response data. In the case
--                  of success this string will be a JSON object and can be
--                  passed to json.decode() in order to create a Lua table.
--      </ul>
--
function invokeLocalEms(service, data)
  return invoke(service, data, "LocalEms")
end
