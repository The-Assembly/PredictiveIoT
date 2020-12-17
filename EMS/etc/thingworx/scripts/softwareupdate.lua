
require "server"
require "softwarejob"
require "utils"

local SERVER_ERROR_CODE = 500
local UPDATE_RATE = 10000

local STATE_CREATED = "created"
local STATE_NOTIFIED = "notified"
local STATE_WAIT_FOR_DOWNLOAD = "waitForDownload"
local STATE_ABORTED = "aborted"
local STATE_START_DOWNLOAD = "startDownload"
local STATE_DOWNLOADING = "downloading"
local STATE_DOWNLOADED = "downloaded"
local STATE_WAIT_FOR_INSTALL = "waitForInstall"
local STATE_INSTALLING = "installing"
local STATE_COMPLETED = "completed"
local STATE_FAILED = "failed"

local job = nil
local download_result = nil
local messageQueue = {}

tw_http.registerCallback("/start", "start")
tw_http.registerCallback("/abort", "abort")
tw_http.registerCallback("/download", "download")
tw_http.registerCallback("/downloaded", "downloaded")
tw_http.registerCallback("/scheduleDownload", "scheduleDownload")
tw_http.registerCallback("/scheduleInstall", "scheduleInstall")

-------------------------------------------------------------------------------
-- Registered HTTP callback handlers
-------------------------------------------------------------------------------

function start(method, path, headers, query, data)
    debugLog("Attempting to start software update for " .. getDataSummary(data))

    if not job then
        -- If there is no current job, start the new one
        job = thingworx.softwarejob.new(data)
        job.state = STATE_CREATED

    elseif job.id ~= data.id then
        -- If the current job id does not match the new job id, check the platform status of the current job
        local code, platformStatus = nil, nil
        code, platformStatus = getJobPlatformStatus(job.id)
        if code ~= 200 then
            return SERVER_ERROR_CODE, "A deployment (" .. job.id .. ") is in progress.  Unable to look up its platform status.  Response:" .. resp
        elseif platformStatus == "aborted" or platformStatus == "failed" or platformStatus == "completed" then
            -- Platform status for the job is a terminal state so start a new job for the new deployment
            warnLog("Platform status for current job is ".. platformStatus .. ". Clearing current job and starting new job for " .. getDataSummary(data))
            serverComplete(job, false)
            job = thingworx.softwarejob.new(data)
            job.state = STATE_CREATED
        else
            return SERVER_ERROR_CODE, "A deployment (id:" .. job.id .. " lsrStatus:" .. job.state .. " platformStatus:" .. platformStatus .. ") is in progress.  Only one deployment at a time is supported."
        end
    else
        -- The current job is being restarted for some reason.  This is likely due to being stuck in downloading which timed out.
        job.state = STATE_CREATED
    end

    return 200
end

function abort(method, path, headers, query, data)
    debugLog("Attempting to abort software update for " .. getDataSummary(data))

    if not job then
        return SERVER_ERROR_CODE, "The campaign to abort does not exist."
    elseif job.id ~= data.id then
        return SERVER_ERROR_CODE, "Abort request rejected because the current campaign job id (" .. job.id .. ") does not match the abort request for job id (" .. data.id .. ")."
    elseif job.state == STATE_INSTALLING then
        return SERVER_ERROR_CODE, "The campaign cannot be aborted while installing." -- Aborting during installation is risky; unforeseen things may happen
    else
        job.state = STATE_ABORTED
    end

    return 200
end

function download(method, path, headers, query, data)
    debugLog("Attempting to download software update for " .. getDataSummary(data))

    if not job then
        return SERVER_ERROR_CODE, "The campaign to download does not exist."
    else
        if job.state == STATE_START_DOWNLOAD then
            serverUpdateState(job, STATE_DOWNLOADING)
        else
            return SERVER_ERROR_CODE, "It is too soon to start the download."
        end
    end

    return 200
end

function downloaded(method, path, headers, query, data)
    debugLog("Software update downloaded for deployment for " .. getDataSummary(data))

    if not job then
        return SERVER_ERROR_CODE, "The campaign that is marked as downloaded does not exist."
    else
        if job.state == STATE_DOWNLOADING then
            serverUpdateState(job, STATE_DOWNLOADED)
        else
            return SERVER_ERROR_CODE, "The downloaded state is not possible at this time."
        end
    end

    return 200
end

function scheduleDownload(method, path, headers, query, data)
    debugLog("Attempting to schedule download of software update for " .. getDataSummary(data))

    if not job then
        return SERVER_ERROR_CODE, "No campaign.  Create a campaign before attemting to schedule the download."
    else
        local time = tonumber(data.time)
        if not time then
            return SERVER_ERROR_CODE, "Invalid date time specified."
        end
        time = time / 1000
        log.audit(p_data.name, "Campaign [%s] download scheduled for %s", job.name, os.date("%c", time))
        job.downloadTime = time
    end

    return 200
end

function scheduleInstall(method, path, headers, query, data)
    debugLog("Attempting to schedule install of software update for " .. getDataSummary(data))

    if not job then
        return SERVER_ERROR_CODE, "No campaign.  Create a campaign before attemting to schedule the install."
    else
        local time = tonumber(data.time)
        if not time then
            return SERVER_ERROR_CODE, "Invalid date time specified."
        end
        time = time / 1000
        log.audit(p_data.name, "Campaign [%s] install scheduled for %s", job.name, os.date("%c", time))
        job.installTime = time
    end

    return 200
end

-------------------------------------------------------------------------------
-- Local helper functions
-------------------------------------------------------------------------------

function debugLog(message)
    local currentJobSummary = getCurrentJobSummary()
    log.debug(p_data.name, "%s [%s]", message, currentJobSummary)
end

function infoLog(message)
    local currentJobSummary = getCurrentJobSummary()
    log.info(p_data.name, "%s [%s]", message, currentJobSummary)
end

function warnLog(message)
    local currentJobSummary = getCurrentJobSummary()
    log.warn(p_data.name, "%s [%s]", message, currentJobSummary)
end

function errorLog(message)
    local currentJobSummary = getCurrentJobSummary()
    log.error(p_data.name, "%s [%s]", message, currentJobSummary)
end

function getCurrentJobSummary()
    local summary = ""
    if not job then
        summary = "No current job"
    else
        summary = "CURRENT JOB "
        if not job.name then
            summary = summary .. " name:nil"
        else
            summary = summary .. " name:" .. job.name
        end

        if not job.id then
            summary = summary .. " id:nil"
        else
            summary = summary .. " id:" .. job.id
        end

        if not job.state then
            summary = summary .. " state:nil"
        else
            summary = summary .. " state:" .. job.state
        end
    end
    return summary
end

function getDataSummary(data)
    local summary = "[INPUT DATA "
    if not data then
        summary = summary .. "nil"
    else
        if not data.name then
            summary = summary .. " name:nil"
        else
            summary = summary .. " name:" .. data.name
        end

        if not data.id then
            summary = summary .. " id:nil"
        else
            summary = summary .. " id:" .. data.id
        end
    end
    summary = summary .. "]"
    return summary
end

-- !!! CONSIDER REFACTORING THIS FUNCTION.  IT IS EXTREMELY AD HOC.
-- A better solution would be to add a new service to SoftwareManager::GetDeliveryTargetDeploymentStatus(deploymentId)
function getJobPlatformStatus(jobid)
    local thingName = "TW.RSM.SFW.SoftwareManager.DeliveryTarget"
    local serviceName = "GetDataTableEntryByKey"
    local params = {
        key = jobid,
        Timestamp = os.time() * 1000
    }

    local code, resp = nil, nil
    --NOTE: this message does not queue the messages because the process is going to block until this succeeds
    code, resp = thingworx.server.invoke(serviceName, params, thingName)
    if code ~= 200 then
        return code, "error"
    end

    -- Extract the status from the response
    statusField = string.sub(resp, string.find(resp, '\"Status\":\"%a*\"'))
    statusValue = string.sub(statusField, string.find(statusField, '\"%a*\"$'))
    platformStatus = statusValue:gsub('"','')

    return code, platformStatus
end

function timeToString(time)
    os.date("%c", time)
end

function pause()
    tw_utils.psleep(UPDATE_RATE)
end

function sendQueuedMessages()
    local code, resp = nil, nil
    if #messageQueue > 0 then
        local count = 0
        while count < #messageQueue do
            local queueItem = table.remove(messageQueue, 1)
            code, resp = thingworx.server.invoke(queueItem.service, queueItem.params, queueItem.thing)
            if code ~= 200 then
                --put the item back on the queue for the next time this is executed
                table.insert(messageQueue, queueItem)
            end
            count = count + 1
        end
    end
end

function sendServerMessage(service, params, thing)
    local code, resp = nil, nil
    code, resp = thingworx.server.invoke(service, params, thing)
    --if the operation failed, queue it
    if code ~= 200 then
        log.debug(p_data.name, "Could not call service %s.%s, placing it in queue.", thing, service)
        local queueItem = {
            service = service,
            params = params,
            thing = thing,
        }
        table.insert(messageQueue, queueItem)
    end
    --return the values even though they will be ignored by most callers
    return code, resp
end

function serverUpdateState(job, state)
    local code, resp, params = nil, nil, {}
    params = {
        ID = job.id,
        Target = job.thing,
        State = state,
        Timestamp = os.time() * 1000
    }
    --code, resp = thingworx.server.invoke("UpdateState", params, job.updateManager)
    code, resp = sendServerMessage("UpdateState", params, job.updateManager)
    log.audit(p_data.name, "Campaign [%s], Target: [%s], State: [%s]", job.name, job.thing, state)
    job.state = state
    return code, resp
end

function serverComplete(job, success, message, reason)
    local code, resp, params = nil, nil, {}
    params = {
        ID = job.id,
        Target = job.thing,
        Success = success,
        Message = job.error,
        Reason = reason,
        Timestamp = os.time() * 1000
    }
    --code, resp = thingworx.server.invoke("CompleteDeliveryTarget", params, job.updateManager)
    code, resp = sendServerMessage("CompleteDeliveryTarget", params, job.updateManager)
    log.audit(p_data.name, "Complete campaign [%s], Target: [%s], Success: [%s], Message: [%s], State: [%s]", job.name, job.thing, success, job.error, job.state)
end

function serverStartDownload(job)
    --NOTE: this message does not queue the messages because the process is going to block until this succeeds
    local code, resp, params = nil, nil, {}
    params = {
        ID = job.id,
        Target = job.thing
    }
    code, resp = thingworx.server.invoke("StartDownload", params, job.updateManager)
    return code, resp
end

function installSoftwareUpdate(job)

    local error = nil
    --NOTE: Getting the first step will also unzip the package and load the script
    --      When there is an error, the step_func will contain the error string
    local get_step_ok, step_name, step_func = pcall(job.next_step, job)
    log.info(p_data.name, "Retrieved step information; step_name: %s; step_func: %s", step_name, step_func)

    if type(step_func) == 'string' then
        if string.match(step_func, 'Downloaded file .*.zip not found') ~= nil then
            -- str now contains the indices of the start and end of 'not found' or nil if the phrase was not 
            -- found in the error message statement. So if any indices were found, regardless of their value, we know
            -- to abort instead of attempting to install because the download did not complete properly
            serverUpdateState(job, STATE_ABORTED)
            error = string.format("Error on installing step. Reason: File Not Found; Message: %s", step_func)
        elseif string.match(step_func, 'Downloaded update script file .*.lua not found') ~= nil then
            -- In this case, we could not find the lua file. This means that we didn't get here before the file finished
            -- downloading, but rather the package had an error. Here, we want to fail. Setting the error will cause a fail
            -- code to be sent to SCM on the Platform
            error = string.format("Error on installing step. Reason: File Not Found; Message: %s", step_func)
        end
    else
        log.info(p_data.name, "Lua script file was found, attempting to execute lua functions...")

        if step_name then
            while step_name do
                local execute_step_ok, step_result, step_result_err_msg = pcall(step_func, job)
                if not execute_step_ok then
                    error = string.format("Failed to execute step '%s'", step_name)
                    break
                elseif not step_result then
                    error = string.format("Step '%s' failed.  Reason:  %s", step_name, step_result_err_msg)
                    break
                end
                --NOTE:  Won't get here if there is an error because of the breaks above
                serverUpdateState(job, step_name)
                --get the next step
                get_step_ok, step_name, step_func = pcall(job.next_step, job)
                if not step_name and step_func then
                    error = string.format("Error executing script.  Reason:  %s", step_func)
                    break
                end
            end
        else
            error = string.format("Error executing script.  Reason:  %s", step_func)
        end
    end

    return error
end

function waitForDownload()
    local shouldPause = true
    if job.downloadTime then
        local now = os.time() * 1000
        if now > job.downloadTime then
            local code, resp = serverStartDownload(job)
            if code == 200 then
                job.state = STATE_START_DOWNLOAD
                shouldPause = false
            end
        end
    end
    if shouldPause then
        pause()
    end
end

function waitForInstall()
    local shouldPause = true
    if job.installTime then
        local now = os.time() * 1000
        if now > job.installTime then
            serverUpdateState(job, STATE_INSTALLING)
            shouldPause = false
        end
    end
    if shouldPause then
        pause()
    end
end

-------------------------------------------------------------------------------
-- main campaign execution loop (only exit when the script resource exits)
-------------------------------------------------------------------------------
while p_data.run do

    --see if there are any messages in the queue, if so send them
    if #messageQueue > 0 then
        sendQueuedMessages()
    end

    -- don't execute the logic if there is no campaign/job
    if job then
        if job.state == STATE_CREATED then
            serverUpdateState(job, STATE_NOTIFIED)
        elseif job.state == STATE_NOTIFIED then
            job.state = STATE_WAIT_FOR_DOWNLOAD
        elseif job.state == STATE_START_DOWNLOAD then
            --do nothing, informed the server that it should download
            --download function will take care of transitiong to STATE_DOWNLOADING
            tw_utils.psleep(100)
        elseif job.state == STATE_DOWNLOADING then
            --do nothing, just wait for the package to be downloaded
            --downloaded function will take care of transitioning to STATE_DOWNLOADED
            tw_utils.psleep(100)
        elseif job.state == STATE_WAIT_FOR_DOWNLOAD then
            waitForDownload()
        elseif job.state == STATE_DOWNLOADED then
            job.state = STATE_WAIT_FOR_INSTALL
        elseif job.state == STATE_WAIT_FOR_INSTALL then
            waitForInstall()
        elseif job.state == STATE_INSTALLING then
            local error = installSoftwareUpdate(job)
            if not error then
                serverComplete(job, true)
                job = nil
            elseif job.state == STATE_ABORTED then
                job.error = error
                serverComplete(job, false, nil, "aborted")
                job = nil
            else
                job.error = error
                serverComplete(job, false)
                job = nil
            end
        elseif job.state == STATE_FAILED then
            serverComplete(job, false)
            job = nil
        elseif job.state == STATE_ABORTED then
            serverComplete(job, false, nil, "aborted")
            job = nil
        end
    else
        --wait for a job
        pause()
    end
end

log.info(p_data.name, "Script %s is exiting", p_data.name)
