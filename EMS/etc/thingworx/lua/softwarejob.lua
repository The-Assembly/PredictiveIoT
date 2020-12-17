
require "utils"
require "server"

local fmt = string.format

module("thingworx.softwarejob", package.seeall)

local function unpack_zip(job)
    -- Only unpack it once
    if job.unpacked then return true end

    log.debug(p_data.name, "Unzipping software update package: %s", job.zip_file)

    if not tw_dir.exists(job.zip_abs_path) then
        return nil, fmt("Downloaded file %s not found", job.zip_file)
    end

    tw_dir.decompress(job.zip_abs_path, job.zip_dir)
    job.unpacked = true
    return true
end

local function load_script(job)
    log.debug(p_data.name, "Loading software update script: %s", job.script)
    -- Only load it once
    if job.script_loaded then 
        return true 
    end

    local unpacked, msg = unpack_zip(job)
    if not unpacked then
        return nil, msg
    end

    local script = tw_dir.fixPath(job.zip_dir .. "/" .. job.script)
    if not tw_dir.exists(script) then
        return nil, fmt("Downloaded update script file %s not found", script)
    end

    local f, msg = assert(loadfile(script))
    setfenv(f, job.steps)
    f()

    job.script_loaded = true
    job.step_count = #job.steps.steps
    return true
end

function new(t)
    assert(t.id, "The 'id' parameter is required")
    assert(t.name, "The 'name' parameter is required")
    assert(t.thing, "The 'thing' parameter is required")
    assert(t.repository, "The 'repository' parameter is required")
    assert(t.path, "The 'path' parameter is required")
    assert(t.script, "The 'script' parameter is required")
    assert(t.updateManager, "The 'updateManager' parameter is required")

    log.info(p_data.name, "Creating new Sofware Update Job. id: %s, name: %s", t.id, t.name)

    --
    -- Initialize the job with the parameters passed in
    --
    local obj = {}
    for k,v in pairs(t) do
      obj[k] = v
    end

    --
    -- Check some of the input params
    --

    -- Extract just the file name. If there is no leading slash then the zip_file will be nil, 
    -- in that case, just use the entire string
    obj.zip_file = t.path:match("^.*/(.-)$") 
    if not obj.zip_file then
        obj.zip_file = t.path
    end

    if t.downloadTime then
        obj.downloadTime = tonumber(t.downloadTime)
        assert(obj.downloadTime, "The 'downloadTime' parameter is not correct")
    end
    if t.installTime then
        obj.installTime = tonumber(t.installTime)
        assert(obj.installTime, "The 'installTime' parameter is not correct")
    end
    
    --obj.id = t.id,
    obj.name = t.name
    obj.state = nil
    --obj.downloadTime = downloadTime
    --obj.installTime = installTime
    --obj.thing = t.thing
    --obj.repository = t.repository
    --obj.path = t.path
    --obj.script = t.script
    --obj.updateManager = t.updateManager
    --obj.sw_update_dir = t.sw_update_dir
    obj.zip_dir = tw_dir.fixPath(t.sw_update_abs_dir)
    --obj.zip_file = zip_file
    obj.zip_abs_path = tw_dir.fixPath(t.sw_update_abs_dir .. "/" .. obj.zip_file)
    obj.current_step = 1
    obj.unpacked = false
    obj.script_loaded = false
    obj.steps = {}
    obj.error = ""

    log.debug(p_data.name, "softwarejob: %s", table.toString(obj))

    setmetatable(obj.steps, {__index = obj})

    return setmetatable(obj, {__index = _M})
end

function next_step(self)
    if not self.script_loaded then
        local success, msg = load_script(self)
        if not success then
            log.error(p_data.name, msg)
            return nil, msg
        end
    end

    local step_name, step_func
    if self.current_step <= #self.steps.steps then
        step_name = self.steps.steps[self.current_step]
        step_func = self.steps[step_name]
        self.current_step = self.current_step + 1
    else
        step_name, step_func = nil, nil
    end

    log.debug(p_data.name, "Returning next step: %s", step_name)
    return step_name, step_func
end
