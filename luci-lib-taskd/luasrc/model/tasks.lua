local util  = require "luci.util"
local jsonc = require "luci.jsonc"

local taskd = {}

local function output(data)
    local ret={}
    ret.running=data.running
    if not data.running then
        ret.exit_code=data.exit_code
    end
    ret.command=data["command"] and data["command"][4] or '#'
    if data["data"] then
        ret.start=tonumber(data["data"]["start"])
        if not data.running and data["data"]["stop"] then
            ret.stop=tonumber(data["data"]["stop"])
        end
    end
    return ret
end

taskd.status = function (task_id)
  task_id = task_id or ""
  local data = util.trim(util.exec("/etc/init.d/tasks task_status "..task_id.." 2>/dev/null")) or ""
  if data ~= "" then
    data = jsonc.parse(data)
    if task_id ~= "" and not data.running and data["data"] then
      data["data"]["stop"] = util.trim(util.exec("/etc/init.d/tasks task_stop_at "..task_id.." 2>/dev/null")) or ""
    end
  else
    if task_id == "" then
      data = {}
    else
      data = {running=false, exit_code=255}
    end
  end
  if task_id ~= "" then
    return output(data)
  end
  local ary={}
  for k, v in pairs(data) do
    ary[k] = output(v)
  end
  return ary
end

taskd.docker_map = function(config, task_id, script_path, title, desc)
  require("luci.cbi")
  require("luci.http")
  require("luci.sys")
  local translate = require("luci.i18n").translate
  local m
  m = luci.cbi.Map(config, title, desc)
  m.template = "tasks/docker"
  m.pageaction = false
  m.apply_on_parse = false
  m.script_path = script_path
  m.task_id = task_id
  m.check_task = true
  m.on_after_apply = function(self)
    local cmd
    local action = luci.http.formvalue("cbi.apply") or "null"
    if "upgrade" == action or "install" == action
        or "start" == action or "stop" == action or "restart" == action or "rm" == action then
      cmd = string.format("\"%s\" %s", script_path, action)
    end
    if cmd then
      if luci.sys.call("/etc/init.d/tasks task_add " .. task_id .. " '" .. cmd .. "' >/dev/null 2>&1") ~= 0 then
        m.task_start_failed = true
        m.message = translate("Config saved, but apply failed")
      end
    else
      m.message = translate("Unknown command: ") .. action
    end
    if m.message then
      m.check_task = false
    end
  end
  return m
end

return taskd
