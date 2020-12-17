
require "json"

--
-- No-op log functions if they aren't needed
--
if p_data.log_level == "FORCE" or
   p_data.log_level == "AUDIT" or
   p_data.log_level == "ERROR" or
   p_data.log_level == "WARN"  or
   p_data.log_level == "INFO"  then
    log.trace = function() end
    log.debug = function() end
end

if p_data.log_level == "DEBUG" then   
    log.trace = function() end
end

--
-- Register callbacks
--
ps_http.registerCallback("/", "handle_request")
ps_http.registerCallback("/registerIdentifier", "register_identifier")

local identifiers = {}

function register_identifier(method, path, headers, query, data)
    log.info(p_data.name, "Registering identifier %s for thing %s", data.identifier, data.thing)
    tw_mutex.lock()
    identifiers[data.identifier] = data.thing
    tw_mutex.unlock()
    return 200
end

-----------------------------------------------------------------------------
-- Functions below handle the dispatching of incoming requests
-----------------------------------------------------------------------------

-- An iterator function that can be used to loop over all scripts
-- and return just those of a given type. The type is matched against
-- the scripts file name (thing.lua, resource.lua).
function entities(ent_type)
  local scripts = ps_script.getScriptList()
  local script = nil

  return function()
    local success, file = false, nil

    -- Return the next script name that has a file name matching the ent_type
    while not success do
      script = next(scripts, script)
      if not script then return nil end
      success, file = pcall(ps_script.getFilename, script)
      success = success and file:match("/" .. ent_type .. ".lua$")
    end

    return script
  end
end

function list_entities(ent_type)
  local list
  for name in entities(ent_type) do
    list = list or {}
    table.insert(list, name)
  end
  return list
end

function handle_root_request(method, path, headers, query, data)
  local ent_type = path[1]
  local e = ent_type:lower():match("(.*).$") -- lowercase and remove last character
  local ents = list_entities(e)
  if ents then
    return 200, json.encode({ [ent_type] = list_entities(e) })
  else
    return 404, "Entity type " .. ent_type .. " not found"
  end
end

function handle_request(method, path, headers, query, data)
  local ent_type = path[1]
  local entity = path[2]
  local characteristic = path[3]
  local target = path[4]
  
  if entity:sub(1,1) == '*' then
    local id = entity
    tw_mutex.lock()
    entity = identifiers[id]
    tw_mutex.unlock()
    log.debug(p_data.name, "Request received for entity with identifier %s. Using thing %s", id, entity)
  end

  log.debug(p_data.name, "Handling request. EntityType: %s, Entity: %s, Characteristic: %s, Target: %s", 
                         ent_type or "none", entity or "none", characteristic or "none", target or "none")

  local code, result, resp_headers = 404, string.format("Path not found: %s", table.concat(path, "/")), {}

  if characteristic or target then
    local p = string.format('%s/%s', characteristic, target or "")
    code, result, resp_headers = tw_script.executeCallback(entity, method, p, headers, query, data)
  elseif entity then
    code, result, resp_headers = tw_script.executeCallback(entity, "POST", "Services/GetMetadata", headers, query, data)
  elseif ent_type then 
    code, result, resp_headers = handle_root_request(method, path, headers, query, data)
  end

  return code, resp_headers, result
end

while p_data.run do
  ps_utils.psleep(1000)
end
