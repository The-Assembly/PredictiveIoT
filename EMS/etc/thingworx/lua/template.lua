
require "core"
require "utils"
require "server"
require "handler"
require "shape"
require "types.datashape"

-- Include some shapes by default
require "thingworx.shapes.metadata"
require "thingworx.shapes.propsubscribe"

local base = _G
local os = base.os
local math = base.math
local table = base.table
local string = base.string
local log = require "log"
local stringx = require "stringx"
local tablex = require "tablex"
local json = require "json"
local ps_utils = base.ps_utils
local ps_script = base.ps_script
local ps_http = base.ps_http
local ps_rap = base.ps_rap
local ps_dir = base.ps_dir
local ps_mutex = base.ps_mutex
local tw_utils = base.ps_utils
local tw_mutex = base.tw_mutex
local tw_datashape = base.tw_datashape
local tw_infotable = base.tw_infotable
local print = base.print
local assert = base.assert
local ipairs = base.ipairs
local pairs = base.pairs
local str = base.tostring
local fmt = base.string.format
local pcall = base.pcall
local setfenv = base.setfenv
local setmetatable = base.setmetatable
local tonumber = base.tonumber
local type = base.type
local require = base.require
local p_data = p_data
local thingworx = thingworx

--------------------------------------------------------------------------------
-- A template is the core building block for Things in the script resource.
-- Each template contains a table of properties, services, and tasks that
-- define its functionlity. Multiple Things can then be created from a template
-- and hosted in a single script resource.
--
-- This is the base module for creating Thing Templates.
--------------------------------------------------------------------------------
module "thingworx.template"

-- Setup some defaults on config properties
p_data.scanRate           = tonumber(p_data.scanRate) or tonumber(p_data.updateRate) or 60000
p_data.taskRate           = tonumber(p_data.taskRate) or 15000
p_data.scanRateResolution = tonumber(p_data.scanRateResolution) or 500
p_data.keepAliveRate      = tonumber(p_data.keepAliveRate) or 60000
p_data.requestTimeout     = tonumber(p_data.requestTimeout) or 15000
p_data.registerRate       = tonumber(p_data.registerRate) or 43200000 -- 12 hours
p_data.maxConcurrentPropertyUpdates = tonumber(p_data.maxConcurrentPropertyUpdates) or 100
p_data.defaultPushType    = p_data.defaultPushType or "VALUE"

-- Value in p_data is a string, so transform it here to boolean
p_data.register = tw_utils.toboolean(p_data.register or true)
p_data.getPropertySubscriptionsOnReconnect = tw_utils.toboolean(p_data.getPropertySubscriptionsOnReconnect or false)
p_data.useShapes = tw_utils.toboolean(p_data.useShapes or true)

-- Ensure that the scanRate is greater than the scanRateResolution
assert(p_data.scanRate > p_data.scanRateResolution, 
       fmt("Global scanRate must be greater than scanRateResolution. Current values: scanRate: %d, scanRateResolution: %d", 
           p_data.scanRate, p_data.scanRateResolution)) 

-- Ensure that the taskRate is greater than the scanRateResolution
assert(p_data.taskRate > p_data.scanRateResolution, 
       fmt("Global taskRate must be greater than scanRateResolution. Current values: taskRate: %d, scanRateResolution: %d", 
           p_data.taskRate, p_data.scanRateResolution)) 

log.info(p_data.name, "-- Configuration -------------------------------")
log.info(p_data.name, "scanRate: %s", p_data.scanRate)
log.info(p_data.name, "scanRateResolution: %s", p_data.scanRateResolution)
log.info(p_data.name, "taskRate: %s", p_data.taskRate)
log.info(p_data.name, "keepAliveRate: %s", p_data.keepAliveRate)
log.info(p_data.name, "requestTimeout: %s", p_data.requestTimeout)
log.info(p_data.name, "registerRate: %s", p_data.registerRate)
log.info(p_data.name, "register: %s", p_data.register)
log.info(p_data.name, "getPropertySubscriptionOnReconnect: %s", p_data.getPropertySubscriptionsOnReconnect)
log.info(p_data.name, "maxConcurrentPropertyUpdates: %s", p_data.maxConcurrentPropertyUpdates)
log.info(p_data.name, "defaultPushType: %s", p_data.defaultPushType)
log.info(p_data.name, "useShapes: %s", p_data.useShapes)
log.info(p_data.name, "identifier: %s", p_data.identifier or "Not Specififed")
log.info(p_data.name, "------------------------------------------------")

--------------------------------------------------------------------------------
-- Converts a standard Lua module into a template. This method should be used
-- during the module initialization of any new template:
-- <pre>module ("template.newtemplate", thingworx.template.extend)</pre>
--
-- This will place the core Lua libraries, core Lua functions, all ThingWorx
-- libraries, and common utlities into the new template's scope.
--
-- It also adds the following variables into the template's scope:
-- <ul>
--  <li>me: A reference to this template.</li>
--  <li>p_data: The table of configuration data linked to the Thing. This table
--              can be populated with settings via the script resource's config
--              file, or directly within a shape or template.</li>
--  <li>name: The name of the current Thing.</li>
--  <li>services: An empty table that can be populated with services specific to
--                the new template.</li>
--  <li>properties: An empty table that can be populated with properties specific to
--                  the new template.</li>
--  <li>tasks: An empty table that can be populated with tasks specific to
--             the new template.</li>
-- </ul>
--
-- @param m The module to be extended into a Template.
--
function extend(m)
  -- Here we can add any variables we want into the modules scope
  m.me = m
  m.base = base
  m.p_data = p_data
  m.name = p_data.name
  m.log = log
  m.json = json
  m.thingworx = thingworx
  m.server, m.tw_server = thingworx.server, thingworx.server
  m.dataShapes = base.dataShapes
  m.DataShape = base.DataShape -- table of defined data shapes
  m.stringUtils = stringUtils

  if p_data.identifier then
    m.identifier = '*' .. p_data.identifier
  end

  -- Add all the ps_* libs to the local scope of the new shape.
  -- Also alias them to tw_*.
  m.ps_rap, m.tw_rap, m.tw_ems = ps_rap, ps_rap, ps_rap
  m.ps_dir, m.tw_dir = ps_dir, ps_dir
  m.ps_script, m.tw_script = ps_script, ps_script
  m.ps_utils, m.tw_utils = ps_utils, ps_utils
  m.ps_mutex, m.tw_mutex = ps_mutex, ps_mutex
  m.ps_http, m.tw_http = ps_http, ps_http
  m.tw_datashape = tw_datashape
  m.tw_infotable = tw_infotable 

  -- Add all the core lua libs to the template's local scope
  m.coroutine = base.coroutine
  m.debug = base.debug
  m.file = base.file
  m.io = base.io
  m.math = base.math
  m.os = base.os
  m.package = base.package
  m.string = base.string
  m.table = base.table
  m.keepAliveRate = base.keepAliveRate
  m.requestTimeout = base.requestTimeout
  m.registerRate = base.registerRate

  -- Put the core lua functions into the template's local scope
  m.assert, m.collectgarbage, m.dofile, m.error, m.getfenv, m.getmetatable,
  m.ipairs, m.load, m.loadfile, m.loadstring, m.module, m.next, m.pairs,
  m.pcall, m.print, m.rawequal, m.rawget, m.rawset, m.require, m.select,
  m.setfenv, m.setmetatable, m.tonumber, m.tostring, m.type, m.unpack, m.xpcall =
  base.assert, base.collectgarbage, base.dofile, base.error, base.getfenv,
  base.getmetatable, base.ipairs, base.load, base.loadfile, base.loadstring,
  base.module, base.next, base.pairs, base.pcall, base.print, base.rawequal,
  base.rawget, base.rawset, base.require, base.select, base.setfenv,
  base.setmetatable, base.tonumber, base.tostring, base.type, base.unpack, base.xpcall

  -- Create these tables so template authors don't have to
  m.services = {}
  m.properties = {}
  m.tasks = {}

  -- Check for shapes that have been required and add their fields to the new template
  for name,t in pairs(base.package.loaded) do
    if name:find("shapes%.") == 1 then
      log.info(_NAME, "Adding shape '%s' to template '%s'", name, _NAME)
      for k,v in pairs(t.properties) do m.properties[k] = m.properties[k] or v end
      for k,v in pairs(t.services) do m.services[k] = m.services[k] or v end
      for k,v in pairs(t.tasks) do m.tasks[k] = m.tasks[k] or v end
    end
  end

  m.p_data.properties = m.properties
  setmetatable(m, {__index = _M})

  --The following section maps the metadata shape functions to the table passed in to the
  --extend method so that they will be available to any extended template
  m.input = base.shapes.metadata.input
  m.output = base.shapes.metadata.output
  m.description = base.shapes.metadata.description
  m.private = base.shapes.metadata.private
  --The following function in the metadata.lua initializes the serviceDefinitions and definedServiceDefinitions
  --to be used be derived templates service and property metadata
  m.serviceDefinitions, m.definedServiceDefinitions = base.shapes.metadata.init(m)

end

-- -----------------------------------------------------------------------------
-- Create a new Thing based on this template. This method performs the following
-- tasks:
-- <ol>
--  <li>Sets up the services, properties, and tasks tables for the Thing</li>
--  <li>Ensures that the main Thingworx script is running</li>
--  <li>Registers the new Thing with the Thingworx script</li>
--  <li>Put the new Thing into the global scope so it can be accessed
--      by the core handlers</li>
-- </ol>
--
-- @param me The template module's table.
-- @param params Any parameters that should be in the global scope of the
--               new Thing. Typically, the Thing's p_data is used.
--
-- @return A new Thing that has been registered with the main ThingWorx script.
--
function new(me, params)
  assert(params.name, "A name parameter is required.")
  log.info(_NAME, "Creating new %s named '%s'", me._NAME, params.name)
  me.properties = me.properties or {}
  me.services = me.services or {}
  me.tasks = me.tasks or {}
  me.lifecycle = { start = {}, stop = {} }

  -- Initialize properties. First set reasonable defaults where needed. Then
  -- go check for handlers. Add any handler's 'open' and 'close' functions 
  -- as lifecycle listeners.
  log.info(me.name, "-- Initializing properties ---------------------")
  for k,pt in pairs(me.properties) do
    pt.name = k
    pt.baseType = pt.baseType or pt.basetype
    pt.basetype = pt.baseType -- Just in case someone uses it with the lowercase 't' in a handler
    pt.time = pt.time  or os.time() * 1000
    pt.quality = pt.quality or "UNKNOWN"
    pt.scanRate = pt.scanRate or p_data.scanRate
    pt.updateTime = os.time() * 1000
    if not pt.handler then pt.quality = "GOOD" end
    pt.dataChangeType = pt.dataChangeType or "VALUE"
    pt.dataChangeThreshold = pt.dataChangeThreshold or pt.threshold or 0
    pt.pushType = pt.pushType or pt.dataChangeType or p_data.defaultPushType
    pt.pushThreshold = tonumber(pt.pushThreshold or pt.threshold or 0) 

    -- Cache time default is based on pushType unless set in template
    if not pt.cacheTime then
      if pt.pushType == "NEVER" then
        pt.cacheTime = -1
      else
        pt.cacheTime = 0
      end
    end

    -- Initialize value
    if pt.value == nil then -- Check for nil, not just false!
      if pt.baseType == "LOCATION" then
        pt.value = { latitude = 0, longitude = 0, elevation = 0 }
      elseif pt.baseType == "STRING" or pt.baseType == "XML" then
        pt.value = ""
      elseif pt.baseType == "INFOTABLE" then
        if p_data.useShapes then
          local ds = base.DataShape[pt.dataShape]:clone()
          local it = tw_infotable.createInfoTable(ds)
          pt.value = it:toTable()
        else
          pt.value = { fieldDefinitions = {}, rows = {} }
        end
      else
        pt.value = 0
      end
    end

    pt.init = table.fullCopy(pt)
    pt.prev = { value = pt.value, time = pt.time, quality = pt.quality }

    -- The property's scanRate can't be less than the global scanRateResolution. If
    -- it is then just exit right now.
    assert(pt.scanRate > p_data.scanRateResolution, 
           fmt("Property %s scanRate of %d is less than global scanRateResolution of %d", 
               pt.name, pt.scanRate, p_data.scanRateResolution))

    -- Add lifecycle listeners based on the actual name of the property's handler, not
    -- just the name of the handler given in the property definition. For example, some
    -- properties may specify a handler name, but the name of the actual handler loaded 
    -- coud be 'script'.
    if pt.handler then
      handler = me:openHandler(pt.handler)
      me:addLifecycleListener("start", handler._NAME .. "_open",  handler.open)
      me:addLifecycleListener("stop",  handler._NAME .. "_close", handler.close)
    end

    log.info(me.name, "Initialized property %s [baseType: %s, pushType: %s, handler: %s, value: %s]", k, pt.baseType, pt.pushType, pt.handler, pt.value)
  end
  log.info(me.name, "------------------------------------------------")

  -- Attempt to launch Thingworx script.
  -- Only want to launch Thingworx script once, so check to see if it is already running.
  local scripts = ps_script.getScriptList()
  if not scripts['Thingworx'] then
    log.info(_NAME, "Starting Thingworx script.")
    pcall(ps_script.addScript('Thingworx', 'thingworx.lua'))
  end

  -- Now wait until it is up and running
  while ps_script.getStatus('Thingworx') ~= 'Running' do
    log.debug(_NAME, "Waiting for Thingworx script to initialize: %s", ps_script.getStatus('Thingworx'))
    ps_utils.psleep(1000)
  end

  -- If this thing is using an identifier, then we need to register it with the Thingworx 
  -- script so it can route URLs with identifiers to the correct thing.
  if p_data.identifier then
      local params = {identifier = '*' .. p_data.identifier, thing = me.name}
      local code = 0
      while code ~= 200 do
          code = ps_script.executeCallback('Thingworx', 'POST', 'registerIdentifier', nil, nil, params)
          ps_utils.psleep(1000)
      end
      log.info(p_data.name, "Identifier %s registered with main Thingworx script for for Thing %s", '*' .. p_data.identifier, me.name)
  end

  -- Go through all the shapes that have been required and add their 'start' and
  -- 'stop' functions as lifecycle listeners.
  for name,t in pairs(base.package.loaded) do
    if name:find("shapes%.") == 1 then
      me:addLifecycleListener("start", name .. "_start", t.start)
      me:addLifecycleListener("stop",  name .. "_stop",  t.stop)
    end
  end

  -- Give it 2 more seconds to finish starting
  ps_utils.psleep(2000)

  -- Create a new table that is backed by the template that called new.
  -- Then set the base.thing to this new object. The base.thing variable allows
  -- the core handler from thingworx.core to access this new object.
  base.thing = setmetatable(params or {}, {__index = me})
  return base.thing
end

-- -----------------------------------------------------------------------------
-- Attempt to open a handler. If a handler with the given name is not found, 
-- then the generic script handler will be returned.
--
-- @param handler_name The name of the handler to open
--
-- @return Two values: 
--          * The handler, which is a Lua module. If the handler is not found, the
--            script handler will be returned. 
--          * If the handler was not found, then the handler name is returned. It
--            should be treated as the name of a running script. Otherwise, the
--            second return value is nil.
--
function openHandler(me, handler_name)
  local success, handler = pcall(require, "handlers." .. handler_name)
  local script = nil

  -- If the handler is successfully loaded, then we return it.
  -- If it is not found, then we treat the handler as the name of a running script.
  -- In this case we use the script handler, but pass the script name as a
  -- 5th parameter to let the write function know how to handle it.
  if success then
    log.trace(me.name, "Found handler %s", handler_name)
  else
    log.trace(me.name, "Using script handler.", handler_name)
    handler = require("handlers.script")
    script = handler_name
  end

  return handler, script
end

function getProperty(me, prop, headers, query)
  local success = false
  local code = 500
  local msg  = "Could not get property " .. prop
  local pt = me.properties[prop]
	
  -- Set the previous values to the current values
  if pt.baseType == "LOCATION" then
    -- Careful not to just copy a table reference for locations
    pt.prev = {
      time = pt.time,
      quality = pt.quality,
      value = {
        latitude = pt.value.latitude or 0,
        longitude = pt.value.longitude or 0,
        elevation = pt.value.elevation or 0
      }
    }
  else
    pt.prev = { value = pt.value, time = pt.time, quality = pt.quality }
  end

  -- Load the handler and call read
  local handler_name = pt.handler or "inmemory"
  local handler, script_name = me:openHandler(handler_name)
  success, code, msg = pcall(handler.read, me, pt, headers, query, script_name)

  if not success then
    -- code is now an error message
    log.error(me.name, "Error occured in handler %s.read. property: %s, msg: %s", handler_name, prop, code)
    return 500, code
  end

  -- Quick check for booleans. Some handlers may return a boolean as a string or number. This
  -- Converts numbers and string to Lua boolean type.
  if pt.basetype == "BOOLEAN" then
    pt.value = tw_utils.toboolean(pt.value)
  end

  log.trace(me.name, "Read property: %s", prop)

  if code == 200 then
    return code, tw_utils.toJsonInfotable(pt)
  else
    log.warn(me.name, "Error while getting property %s. msg: %s", prop, msg)
    return code, msg
  end
end

function setProperty(me, prop, headers, query, data)
  local success = false
  local code = 500
  local msg  = "Could not set property " .. prop

  log.trace(me.name, "Attempting to set property %s", prop)
  
  -- Check to see if the property exist
  local pt = me.properties[prop]
  local value
  
  if data and data.rows and data.rows[1] then
    value = data.rows[1][prop]
  end
  if not value then --and data then
	value = data[prop] or data.value
  end

  -- Boolean can be a little tricky...
  if pt.baseType == "BOOLEAN" then
    value = tw_utils.toboolean(value)
  end
 
  if pt.baseType == "INFOTABLE" and value and value.rows then
    -- If we are using shapes then check the property's shape and
    -- validate the input. Otherwise just use what is passed in.
    if p_data.useShapes then
      tw_mutex.lock()
      local ds = base.DataShape[pt.dataShape]:clone()
      local it = tw_infotable.createInfoTable(ds)
      for i,row in ipairs(value.rows) do
        local s, msg = it:addRow(row)
        if not s then 
          tw_mutex.unlock()
          return 400, msg
        end
      end
      tw_mutex.unlock()
      value = it:toTable()
    end
  end

  -- If we have a valid value, then stick it in the data table so it is
  -- passed to handler.write in a consistent way.
  if value == nil then
    log.warn(me.name, "Request to set property " .. prop .. " did not contain valid data")
    return 400, "Request to set property " .. prop .. " did not contain valid data"
  else
    data.value = value
    data[prop] = value
  end

  -- Load the handler and call write
  local handler_name = pt.handler or "inmemory"
  local handler, script_name = me:openHandler(handler_name)

  success, code, msg = pcall(handler.write, me, pt, headers, query, data, script_name)

  if not success then
    -- code is now an error message
    log.error(me.name, "Error occured in handler %s.write. property: %s, msg: %s", handler_name, prop, code)
    return 500, code
  end

  if code == 200 then
    -- Update the property's updateTime to now. This will cause the next iteration of the
    -- main scan loop to retreive the new property value and push it.
    pt.updateTime = os.time() * 1000
    -- Force a property push of Number properties
    if pt.pushType == "VALUE" then pt.forcePush = true end
    log.debug(me.name, "Wrote property: %s Updated updateTime to %u", prop, pt.updateTime)
  else
    log.warn(me.name, "Could not write property: %s, code: %s, msg: %s", prop, code, msg)
  end

  log.trace("setProperty","Code: %s Msg %s", code, msg)

  return code, msg
end

function getProperties(me, headers, query)
  log.info(me.name, "Default getProperties handler.")
  return 200, json.encode(me.properties)
end

function setProperties(me, headers, query, data)
  log.info(me.name, "Default setProperties handler.")
  return 500, "Not Implemented"
end

function getServices(me, headers, query)
  log.info(me.name, "Default getServices handler.")
  local t = {}
  for k,_ in pairs(me.services) do
    table.insert(t, k)
  end
  return 200, json.encode(t)
end

function registerEdgeThing(me)
  -- Track if we're currently registered
  me.registered = me.registered or false 

  if not p_data.register then 
    if not me.registered then
      log.info(me.name, "EMS registration is disabled for " .. me.name)
    end
    me.registered = true
    return 200, "EMS registration is disabled for " .. me.name
  end

  log.trace(me.name, "Calling registerEdgeThing. currently registered: %s", me.registered)

  data = {}

  if p_data.identifier then
    data.name = '*' .. p_data.identifier
  else
    data.name = me.p_data.name
  end
  
  data.host = me.p_data.script_resource_host
  data.port = me.p_data.script_resource_port
  proto = "http"

  if data.host == "0.0.0.0" then
    data.host = "127.0.0.1"
  end

  if(me.p_data.script_resource_ssl) then
    if(me.p_data.script_resource_ssl:lower() == "true") then
      proto = "https"
    end
  end

  data.proto = proto
  data.path = "/scripts/Thingworx"
  data.keepalive = p_data.keepAliveRate
  data.timeout = p_data.requestTimeout
  data.user = me.p_data.script_resource_userid
  data.password = me.p_data.script_resource_password

  local wasAvailable, wasOnline = thingworx.server.available, thingworx.server.online

  local code, result = thingworx.server.invokeLocalEms("AddEdgeThing", data)

  if code == 200 then
    if not me.registered then
      log.info(me.name, "Successfully registered %s with MicroServer.", me.p_data.name)
      log.trace(me.name, " Previous state - available: %s, online: %s", wasAvailable, wasOnline)
      -- If the previous AddEdgeThing call failed, then we may need to get our Property Subscriptions
      -- again. Only do this if flag is set.
      if p_data.getPropertySubscriptionsOnReconnect and not wasAvailable and wasOnline then
        me.services.GetPropertySubscriptions(me)
      end
      if not me.initialPropertySubscriptionsAcquired then
        me.services.GetPropertySubscriptions(me)
      end
    end

    -- If a registration attempt failed for some reason, then recent property changes may not have
    -- been pushed to the server. Set forcePush on any VALUE pushed properties in order to force
    -- a push of the latest value on the next scan iteration.
    if not me.registered then
      tw_mutex.lock()
      for name,pt in pairs(me.properties) do
        if pt.pushType == "VALUE" then pt.forcePush = true end
      end
      tw_mutex.unlock()
    end
    
    -- Now we can set our registered flag
    me.registered = true
   
  else
    if me.registered then
      log.warn(me.name, "Could not register with the MicroServer. code: %d, msg: %s", code, result)
    end
    me.registered = false
  end 

  return code, result
end

function deregisterEdgeThing(me)

  local data = { name = me.p_data.name }

  if p_data.identifier then
    data.name = '*' .. p_data.identifier
  end

  return thingworx.server.invokeLocalEms("RemoveEdgeThing", data)
end

function addLifecycleListener(me, event, label, func)
  me.lifecycle[event][label] = func
end

function start(me)
	log.info(me.name, "-- Starting script --------------------------")

	log.info(me.name, "Registering core callback handler")
	ps_http.registerCallback("/", "core_handler")

	log.info(me.name, "Starting main loop")
	local lastTaskUpdate = 0
    local lastCheckEmsCall = 0
	local lastRegisterCall = 0

  -- Call all 'start' lifecycle listeners
  log.info(me.name, "Calling lifecycle start listeners.")
  for name,func in pairs(me.lifecycle.start) do 
    log.debug(me.name, "Executing lifecycle start event: %s", name)
    local success, msg = pcall(func) 
    if not success then 
      log.error(me.name, "Could not execute lifecycle start listener '%s'. msg: %s", name, msg)
    end
  end

  while me.p_data.run do -- Main Loop of thing.lua script
    
    local now = os.time() * 1000

    -- Retreive each of the properties and determine if it has changes beyond its
    -- pushThreshold. If so, push the value to the server.
    local propertiesToRead  = {}
    local propertiesToWrite = {}
    
    tw_mutex.lock()
    for k,v in pairs(me.properties) do
      table.insert(propertiesToRead, k)
    end
    tw_mutex.unlock()
    
    for index = 1, #propertiesToRead do
      local pn = propertiesToRead[index]
      local pt = me.properties[pn]

      -- Get the current time and compare it to the next time this property should
      -- be checked for change (updateTime).
      now = os.time() * 1000

      if now > pt.updateTime then
        if pt.pushType == "ALWAYS" or pt.pushType == "VALUE" then
            local code, message = me:getProperty(pn)
            if code == 200 then
                if tw_utils.evaluateChange(pt) then
                    table.insert(propertiesToWrite, pt)
                    pt.forcePush = nil
                end
            else
                log.error(me.name, "Error getting property %s from sensor. msg: %s", pn, message)
            end
        end
        -- Set the updateTime. This indicates the next time an attempt
        -- should be made to read the property. It is used to determine the 
        -- next time that the framework should attempt to push the property
        -- and is different than the property's 'time' attribute.
        pt.updateTime = now + pt.scanRate

        -- Call our Rules evaluation
        if (type(me.tasks.EvaluateRules) == "function") then me.tasks.EvaluateRules(me, name) end
      end
    end
		
    -- Push all the properties, if we are currently registered with the EMS.
    if #propertiesToWrite > 0 and me.registered then
      thingworx.server.setProperties(propertiesToWrite)
    end
    
    -- as long as we think we're registered, we need to check to see if the EMS knows about us. 
    -- If it doesn't, then force registration attempts.
    now = os.time() * 1000
   
    if me.registered and now > lastCheckEmsCall + p_data.keepAliveRate then
      log.trace(me.name, "Checking connection to EMS.")
      local thingName = me.name
      if p_data.identifier then thingName = '*' .. p_data.identifier end
      local code, result = thingworx.server.invokeLocalEms("HasEdgeThing", { name = thingName })
      lastCheckEmsCall = now
      if not thingworx.server.available then
        log.warn(me.name, "EMS is not available. Begin attempting to re-register.")
        lastRegisterCall = 0 -- Force registration attempt
      end
      if code == 200 and result then
        local it = json.decode(result)
        if it.rows[1].result == false then
          log.warn(me.name, "Not currently registered with EMS. Begin attempting to re-register.")
          lastRegisterCall = 0 -- Force registration attempt
        end
      end
    end

    -- Register with the EMS. This is done after the property scan on purpose. On the first
    -- iteration of the main loop, we want to register and call GetPropertySubscriptions
    -- before attempting to push any properties. Since me.registered won't be set until after
    -- the first attempt at registering, calling this after the property scan will prevent
    -- a property push.
    now = os.time() * 1000

    if now > lastRegisterCall + p_data.registerRate then
      local code = me:registerEdgeThing()
      if code == 200 then
        lastRegisterCall = now
      else
        -- Try again in 5 seconds
        lastRegisterCall = now - p_data.registerRate + 5000
      end
    end

    -- Check the taskRate and execute all tasks if taskRate milliseconds have expired.
    now = os.time() * 1000

    if now > lastTaskUpdate + p_data.taskRate then
        -- Go through each of the configured tasks. If they evaluate to true, then
        -- send their results to the server.
        for name,f in pairs(me.tasks) do
            log.trace(me.name, "Executing task %s", name)
            local fire, msg = f(me)
        end
        lastTaskUpdate = now
    end
	
    tw_utils.psleep(p_data.scanRateResolution)

  end -- Main Loop

  -- Call all 'stop' lifecycle listeners
  log.info(me.name, "Calling lifecycle stop listeners.")
  for name,func in pairs(me.lifecycle.stop) do 
    local success, msg = pcall(func) 
    if not success then 
     log.error(me.name, "Could not execute lifecycle stop listener '%s'. msg: %s", name, msg)
    end
  end

  -- Un-register with the EMS
  local deregister_code, deregister_result = deregisterEdgeThing(me)
  if deregister_code ~= 200 then
    log.warn(me.name, "Could not deregister with the EMS")
  end

	log.info(me.name, "-- Exiting script ---------------------------")
end
