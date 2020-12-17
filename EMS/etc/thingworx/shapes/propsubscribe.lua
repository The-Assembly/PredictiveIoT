--------------------------------------------------------------------------------
-- A Shape that allows a Thing to synchronize its Properties' pushType
-- attributes with the settings found on the server.
--------------------------------------------------------------------------------
module ("shapes.propsubscribe", thingworx.shape.extend)

--------------------------------------------------------------------------------
-- @class table
-- @name properties
-- @description The properties associated with this shape.
-- @field upToDate A boolean indicating if the Thing's properties are synced.
--                 This is defaulted to true because the main loop will force
--                 it to false when it registered for the first time.
--
properties.upToDate = { baseType="BOOLEAN", pushType="NEVER", value=true, private=true }

--
-- Note: upToDate is initialized to true because the first 
--       GetPropertySubscriptions call will be performed automatically after 
--       the first successful registration. After that, 
--       me.initialPropertySubscriptionsAcquired will be set to true and further
--       registrations will not trigger a GetPropertySubscriptions unless
--       getPropertySubscriptionsOnReconnect is set.
--

-- -----------------------------------------------------------------------------
-- Service Definitions
-- -----------------------------------------------------------------------------

serviceDefinitions.NotifyPropertyUpdate(
  output { baseType="NOTHING", description="" },
  private { true }
)

serviceDefinitions.GetPropertySubscriptions(
  output { baseType="INFOTABLE", description="", aspects={dataShape="EMPTY"} },
  private { true }
)

--------------------------------------------------------------------------------
-- Sets the upToDate Property to false, this forcing a read of the Thing's
-- property settings from the server.
--
-- @param me A reference to the current Thing
-- @param headers The headers from the REST request invoking the service
-- @param query The query parameters from the REST request invoking the service
-- @param data Empty table
--
-- @return 200
--
services.NotifyPropertyUpdate = function(me, headers, query, data)
  log.info(me.name, "Received notification that property bindings have been updated on server.")
  me:setProperty("upToDate", nil, nil, {value = false})
  return 200
end

--------------------------------------------------------------------------------
-- Requests the latest property subscription info from the server.
--
-- @param me A reference to the current Thing
--
-- @return Status code, followed by property info, or an error message.
--
services.GetPropertySubscriptions = function(me)

  local code, result = server.invoke("GetPropertySubscriptions", {})

  if code == 200 then
    me:setProperty("upToDate", nil, nil, {value = true})
    me.initialPropertySubscriptionsAcquired = true
	
	if result == "" then result = "{}" end
    local data = json.decode(result)
    local count = 0

    -- Set all property pushTypes to NEVER. If a property is to be 
    -- pushed it will be found in the list and will be set below.
    for _,pt in pairs(me.properties) do
      pt.pushType = "NEVER"
    end

    if (data.rows == nil) then data.rows = {} end

    for _,row in pairs(data.rows) do
      if row.pushType == "ON" or row.pushType == "OFF" then
        row.pushType = "VALUE"
      end

      log.debug(me.name, "Updating property definition. property: %s. pushType: %s, threshold: %s",
                         row.edgeName, row.pushType, row.pushThreshold or 0)

      local pt = me.properties[row.edgeName]

      if pt then
        pt.pushType = row.pushType or "NEVER"
        pt.pushThreshold = row.pushThreshold or 0
        pt.updateTime = os.time() * 1000 -- Set updateTime so prop will get pushed on next scan iteration
        if pt.pushType == "VALUE" then pt.forcePush = true end
        count = count + 1
      else
        log.warn(me.name, "Property %s was not found in local property map", row.edgeName)
      end
    end

    log.info(me.name, "GetPropertySubscriptions called. %d properties updated.", count)

    return code, data

  else
    result = string.format("Attempting to GetPropertySubscriptions from server failed. code: %s, result: %s", code, result)
    log.info(me.name, result)
    me:setProperty("upToDate", nil, nil, {value = false})
  end

   log.trace("GetPropertySubscriptions","Code: %s Msg %s", code, result)
  return code, result
end

--------------------------------------------------------------------------------
-- A task that attempts to read the Thing's Property settings from the server
-- every time it is executed and the upToDate property is false. This Task will
-- set upToDate to true upon a successful Property map read.
--
-- @param me A reference to the current Thing
--
tasks.UpdatePropertyMap = function(me)
  log.trace(me.name, "Checking properties.upToDate: %s", tostring(me.properties.upToDate.value))
  me:getProperty("upToDate")
  if not me.properties.upToDate.value or me.properties.upToDate.value == 0 then
    me.services.GetPropertySubscriptions(me)
  end
end
