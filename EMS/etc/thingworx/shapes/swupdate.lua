
require "utils"

--------------------------------------------------------------------------------
-- A Shape that allows a Thing to utilize Software Updates
--------------------------------------------------------------------------------
module ("shapes.swupdate", thingworx.shape.extend)

-- -----------------------------------------------------------------------------
-- Attempt to launch software update script. We only want to launch once, so
-- first check to see if it is already running. This is placed into the
-- start function, which the template framework executes as part of the edge
-- thing's startup lifecycle event.
-- -----------------------------------------------------------------------------
function start()
    tw_script.loadScriptFromFile("softwareupdate", "softwareupdate.lua")
end

-- -----------------------------------------------------------------------------
-- Service Definitions
-- -----------------------------------------------------------------------------

--[[
--
-- DON'T EXPOSE THESE SERVICES
--

serviceDefinitions.TriggerUpdateAction(
    input { name="action", baseType="STRING", description="The action for the software update" },
    input { name="params", baseType="JSON", description="Parameters for the software update action" },
    output { baseType="NOTHING", description="" }
)

serviceDefinitions.ScheduleDownload(
    input { name="time", baseType="DATETIME", description="The date and time to start the download.  If the value is less than now, it will start immediately." },
    output { baseType="NOTHING", description="" }
)

serviceDefinitions.ScheduleInstall(
    input { name="time", baseType="DATETIME", description="The date and time to start the install.  If the value is less than now, it will start immediately after the download completes." },
    output { baseType="NOTHING", description="" }
)

serviceDefinitions.Now(
    output { baseType="DATETIME", description="Current date and time" }
)
--]]

--------------------------------------------------------------------------------
-- Notify the Thing that a Software Update is ready to be applied.
--
-- @param me A reference to the current Thing
-- @param headers The headers from the REST request invoking the service
-- @param query The query parameters from the REST request invoking the service
-- @param data Input params
--
-- @return 200
--
services.TriggerUpdateAction = function(me, headers, query, data)
    log.debug(me.name, "Triggering Software Update Action: " .. data.action)

    --
    -- Need to get the value of p_data.sw_update_dir
    --

    -- First, make sure it is configured
    local sw_update_dir  = p_data.sw_update_dir
    if not sw_update_dir then return 503, "The software update directory has not been configured" end
    log.debug(me.name, "StartSoftwareUpdate: sw_update_dir:      %s", sw_update_dir)

    local params = data.params
    params.thing = me.name
    params.sw_update_abs_dir = tw_dir.fixPath(p_data.sw_update_dir)

    log.debug(me.name, "StartSoftwareUpdate: sw_update_abs_dir:  %s", params.sw_update_abs_dir)
    log.debug(me.name, "StartSoftwareUpdate: script: %s", params.script)

    log.debug(me.name, "Call software update action")
    code, result = tw_script.executeCallback("softwareupdate", "POST", data.action, nil, nil, params)

    return code, result
end

services.ScheduleDownload = function(me, headers, query, data)
    log.debug(me.name, "Call schedule download action")
    
    if not data.time then
        return 503, "No date time specified."
    end
    
    code, result = tw_script.executeCallback("softwareupdate", "POST", "scheduleDownload", nil, nil, data)
    return code, result
end

services.ScheduleInstall = function(me, headers, query, data)
    log.debug(me.name, "Call schedule install action")
    
    if not data.time then
        return 503, "No date time specified."
    end
    
    data.time = tonumber(data.time)
    if not data.time then
        return 503, "Invalid date time specified."
    end
    
    code, result = tw_script.executeCallback("softwareupdate", "POST", "scheduleInstall", nil, nil, data)
    return code, result
end

--TODO:  REMOVE
--Only for testing to get an accurate time quickly
services.Now = function(me, headers, query, data)
    return 200, os.time() * 1000
end
