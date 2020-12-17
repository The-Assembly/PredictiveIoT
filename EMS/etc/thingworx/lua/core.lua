-- ---------------------------------------------------------------------------
-- ThingWorx Property and Service interface script
-- (c)2011 ThingWorx
--
-- $Id$
-- ---------------------------------------------------------------------------

require "log"
require "stringx"
require "tablex"
require "json"
require "utils"

local fmt = string.format

local function result_to_infotable(service, content)

    -- Convert the response to a VTQ for processing by the server.
    local resp
    local infotable = { dataShape = { fieldDefinitions = { result = {name = "result", description = "", baseType = "NOTHING", aspects = { persist = false }}}}}
    local err = "Could not convert service result into base type of %s"

    -- Determine the baseType of the result for the service that was called
    if thing.definedServiceDefinitions[service] then
      infotable.dataShape.fieldDefinitions.result.baseType = thing.definedServiceDefinitions[service].output.baseType or "NOTHING"
	  infotable.rows = {[1] = { result = "" }}
    end
	local baseType = infotable.dataShape.fieldDefinitions.result.baseType
    log.trace(thing.name, "Converting service response with baseType of %s to Infotable", baseType)
    -- Now, figure out what the service returned so we can encode it correctly
	log.debug(thing.name, "Converting to Basetype %s", baseType)
    if baseType == 'NUMBER' or 
       baseType == 'INTEGER' or
       baseType == 'DATETIME' then
      resp = tonumber(content)
    elseif baseType == 'BOOLEAN' then
      resp = tw_utils.toboolean(content)
    elseif baseType == 'LOCATION' or 
	       baseType == 'QUERY' or
           baseType == 'JSON' then
      if type(content) == 'table' then
        resp = content
      elseif type(content) == 'string' and tw_utils.isJson(content) then
        -- This case is for backward compatbility, pre 4.0
        log.warn(thing.name, "Attempting to return %s as a STRING. Converting to a table", baseType)
        resp = json.decode(content) -- Convert to a table
      else
        err = "Services with a base type of %s must return a table"
      end
    elseif baseType == 'IMAGE' then
      resp, err = tw_utils.base64_encode(content)
	elseif  baseType == 'INFOTABLE' then
	  if type(content) == 'string' then
	    -- assume it has already been json encoded
	    return true, content
	  elseif type(content) == 'table' then
	    -- assume it is a InfoTable table and we can call toJson
	    log.debug(thing.name, "Returning infotable %s", json.encode(content))
	    return true, json.encode(content)
	  elseif type(content) == 'userdata' then
	    -- this is a InfoTable object
	    return true, json.encode(content:toTable())
	  end
    elseif baseType == 'NOTHING' then
      resp = ""
    else 
      -- All other base types treated as strings
      if tw_utils.isJson(content) then
        resp = json.decode(content) -- Convert to a table
      else
        resp = tostring(content)
      end
    end

    if resp ~= nil then -- must check for ~= nil here. Just false won't work!
	  if baseType == 'NOTHING' then
	    return true
	  end
      infotable.rows[1].result = resp
	  log.debug(thing.name, "Returning infotable %s", json.encode(infotable))
	  return true, json.encode(infotable)
    else
      return nil, fmt(err, baseType)
    end
end

-- ------------------------------------------------------------------
-- This script places the following http callbacks into the global
-- scope. This is required so that the script resource can find
-- them at runtime. The base template class should require this
-- file in order to insure consistent handling of requests.
-- This file should not be used directly.
-- ------------------------------------------------------------------

function dispatch_properties(method, prop, headers, query, data)

  log.trace(thing.name, "Attempting to dispatch property request. method: %s, prop: %s", method, prop) --, tw_utils.toString(data))

  -- Handle GET of all properties
  if not prop then 
    if method == "GET" then
      log.debug(thing.name, "Dispatch properties GET. thing: %s", thing.name)
      return thing:getProperties(headers, query)
    else
      return 405, "The method " .. method .. " is not supported"
    end
  end

  -- Make sure the requested property is defined in the Thing
  local pt = thing.properties[prop]

  if not pt then return 404, "Property '" .. prop .. "' not found" end

  -- GET or PUT one or more property values
  if method == "GET" then
    log.debug(thing.name, "Dispatch prop GET. thing: %s, prop: %s", thing.name, prop)
    return thing:getProperty(prop, headers, query)
  elseif method == "PUT" then
    if not is_json(headers, data) then return 400, "Property update requires JSON data" end
    local jdata = json.decode(data.content)
    log.debug(thing.name, "Dispatch property PUT. thing: %s, property: %s", thing.name, prop)
    if prop == "*" then
      return thing:setProperties(headers, query, jdata)
    else
      return thing:setProperty(prop, headers, query, jdata)
    end
  end

  return 405, "Method not allowed"
end

function dispatch_services(method, service, headers, query, data)
  if method == "POST" then

    -- Validation of POST
    if not service then return 404, "A service name must be specified" end
    local svc = thing.services[service]
						  
    if not svc then return 404, "Service '" .. service .. "' not found" end

    if data then data.content = data.content or '{"null":0}' end
    if not is_json(headers, data) then return 400, "Service invocation requires JSON data" end

    -- Decode the json into a table and lookup the actual service function
    local jdata = json.decode(data.content)
	if jdata and jdata.rows then
		jdata = jdata.rows[1]
	end
    log.debug(thing.name, "Dispatch service POST.")
    local success, code, content, headers = pcall(svc, thing, headers, query, jdata)
    headers = headers or tw_utils.RESP_HEADERS()
    log.trace(thing.name, "Service returned: code: %s, content: %s", code, content)

    if success then 
      if code == 200 then
        success, vtq = result_to_infotable(service, content)
        if success then
          return code, headers, vtq
        else
          return 500, vtq
        end
      else
        return code, headers, content
      end
    else
      return 500, code -- code ends up being a message in this case
    end

  elseif method == "GET" and not service then
    -- Return a list of available services
    return thing:getServices(headers, query)
  end

  return 405, "Method not allowed"
end

function is_json(headers, data)
  local content_type = headers['content-type'] or headers['Content-Type'] or headers['Content-type'] or ""
  return content_type:find("application/json") and data and data.content
end

--
-- Callback for all requests to this destination. Routes calls to the
-- appropriate thing.
--
function core_handler(method, path, headers, query, data)
  -- Grab the path parts
  local req_type = path[1] -- characteristic: 'Properties' or 'Services''
  local req_targ = path[2] -- name of the Property or Service

  -- The 'thing' variable is set in the base template when new things are instantiated
  if not thing then return 404, "Entity '" .. p_data.name .. "' not found" end

  log.debug(thing.name, "Handling request for /%s/%s", req_type or "", req_targ or "")

  -- Begin routing to appropriate thing handler
  local code, hdrs, content

  if not req_type then
    code = 200
    content = "Return Thing JSON here"
  elseif req_type == thingworx.utils.PATH_PROPS then
    code, content = dispatch_properties(method, req_targ, headers, query, data)
    hdrs = thingworx.utils.RESP_HEADERS() -- Properties are always returned as JSON
  elseif req_type == thingworx.utils.PATH_SVCS then
    code, hdrs, content = dispatch_services(method, req_targ, headers, query, data)
  else
    code = 404
    content = "Not found"
  end

  return code, hdrs, content

end
