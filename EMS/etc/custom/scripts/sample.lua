-------------------------------------------------------------------------------
-- This is a sample Lua script showing how to register Lua functions with the
-- HTTP interface of the script resource. The tw_http.registerCallback 
-- function can be used to map a URL path to any Lua function with the proper
-- signature. By doing this, you can write Lua code that integrates with the
-- host system and exposes data through the script resources REST interface.
-------------------------------------------------------------------------------

require "json"
require "utils"
require "tablex"

local fmt = string.format
local string_value = "Hello World"
local xml_value = "<info><size>100</size><mass>50</mass></info>"

local resp_headers = {
    text = { ["content-type"] = "text/plain" },
    xml  = { ["content-type"] = "text/xml" },
    json = { ["content-type"] = "application/json" },
}

--
-- Functions to return JSON VTQ objects containing values
-- of different types. These 'properties' can be accessed
-- from an edge template property through the use of the
-- script handler.
--

function property_number(method, path, headers, query, data)
  if method ~= "GET" then return 405, "Only GET is allowed" end

  local resp = json.encode({
    value   = 100,
    time    = os.time() * 1000,
    quality = "GOOD"
  })

  return 200, resp
end

--
-- Only the string property supports writes. It stores its
-- value in the global string_value variable.
--

function property_string(method, path, headers, query, data)
  local resp = nil
  if method == "GET" then 
    resp = json.encode({
      value   = string_value,
      time    = os.time() * 1000,
      quality = "GOOD"
    })
  elseif method == "PUT" then
    local content = json.decode(data.content)
    log.debug("sample", "Setting property_string to %s", content.value)
    string_value = content.value
  else
    return 405, "Only GET is allowed"
  end

  return 200, resp
end

function property_boolean(method, path, headers, query, data)
  if method ~= "GET" then return 405, "Only GET is allowed" end

  local resp = json.encode({
    value   = true,
    time    = os.time() * 1000,
    quality = "GOOD"
  })

  return 200, resp
end

function property_datetime(method, path, headers, query, data)
  if method ~= "GET" then return 405, "Only GET is allowed" end

  local resp = json.encode({
    value   = (os.time() * 1000) + 7200000, -- 2 hours from now
    time    = os.time() * 1000,
    quality = "GOOD"
  })

  return 200, resp
end

function property_location(method, path, headers, query, data)
  if method ~= "GET" then return 405, "Only GET is allowed" end

  local resp = json.encode({
    value   = { latitude = 43.9, longitude = 77.36, elevation = 163 },
    time    = os.time() * 1000,
    quality = "GOOD"
  })

  return 200, resp
end

function property_xml(method, path, headers, query, data)
  if method == "PUT" then 
    xml_value = data.content
    return 200
  elseif method == "GET" then 
    return 200, xml_value
  end
  
  return 405, method .. " not supported"
end

--
-- Services to generate content of different types.
--

function generate_json(method, path, headers, query, data)
  if method ~= "POST" then return 405, "Only POST is allowed" end

  local params = json.decode(data.content)
  local resp = json.encode({
                  size = params.size,
                  mass = params.mass
               })

  return 200, resp_headers.json, resp
end

function generate_xml(method, path, headers, query, data)
  if method ~= "POST" then return 405, "Only POST is allowed" end

  local resp = data.content 
  return 200, resp_headers.xml, resp
end

function generate_text(method, path, headers, query, data)
  if method == "DELETE" then return 405, "DELETE is not allowed" end
  if method == "PUT" then return 200 end

  local params

  if method == "GET" then
    params = { size = 200, mass = 500 }
  else 
    params = json.decode(data.content)
  end

  local resp = fmt("size = %s, mass = %s", params.size, params.mass) 

  return 200, resp_headers.text, resp
end

--
-- Here we register specific functions to act as handlers for 
-- a given path.  Once registered, these functions can be executed
-- by accessing the script resource's REST interface using the
-- following pattern:
--
--  /scripts/<script_name>/<registered_path>
--

log.info(p_data.name, "Registering HTTP callbacks")

tw_http.registerCallback("/property/number",   "property_number")
tw_http.registerCallback("/property/string",   "property_string")
tw_http.registerCallback("/property/boolean",  "property_boolean")
tw_http.registerCallback("/property/datetime", "property_datetime")
tw_http.registerCallback("/property/location", "property_location")
tw_http.registerCallback("/property/xml",      "property_xml")

tw_http.registerCallback("/generate/json", "generate_json")
tw_http.registerCallback("/generate/xml",  "generate_xml")
tw_http.registerCallback("/generate/text", "generate_text")

--
-- This is the main loop of the script. It can be used to execute
-- functionality on a regular basis, or can be used as a thread to
-- execute requests that are submitted via a registered callback.
--
-- The script resource signals the end of the script by setting
-- p_data.run to false, so we must check it periodically.
--

log.info(p_data.name, "Beginning main loop")

while p_data.run do
  tw_utils.psleep(1000)
end

log.info(p_data.name, "Exiting")
