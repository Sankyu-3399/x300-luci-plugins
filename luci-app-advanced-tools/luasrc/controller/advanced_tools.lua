module("luci.controller.advanced_tools", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local util = require "luci.util"
local dispatcher = require "luci.dispatcher"
local uci = require("luci.model.uci").cursor()

local AT_CONFIG = "advanced_tools"

local fullwidth_map = {
	["　"] = " ", ["！"] = "!", ["＂"] = "\"", ["＃"] = "#", ["＄"] = "$",
	["％"] = "%", ["＆"] = "&", ["＇"] = "'", ["（"] = "(", ["）"] = ")",
	["＊"] = "*", ["＋"] = "+", ["，"] = ",", ["－"] = "-", ["．"] = ".",
	["／"] = "/", ["０"] = "0", ["１"] = "1", ["２"] = "2", ["３"] = "3",
	["４"] = "4", ["５"] = "5", ["６"] = "6", ["７"] = "7", ["８"] = "8",
	["９"] = "9", ["："] = ":", ["；"] = ";", ["＜"] = "<", ["＝"] = "=",
	["＞"] = ">", ["？"] = "?", ["＠"] = "@", ["Ａ"] = "A", ["Ｂ"] = "B",
	["Ｃ"] = "C", ["Ｄ"] = "D", ["Ｅ"] = "E", ["Ｆ"] = "F", ["Ｇ"] = "G",
	["Ｈ"] = "H", ["Ｉ"] = "I", ["Ｊ"] = "J", ["Ｋ"] = "K", ["Ｌ"] = "L",
	["Ｍ"] = "M", ["Ｎ"] = "N", ["Ｏ"] = "O", ["Ｐ"] = "P", ["Ｑ"] = "Q",
	["Ｒ"] = "R", ["Ｓ"] = "S", ["Ｔ"] = "T", ["Ｕ"] = "U", ["Ｖ"] = "V",
	["Ｗ"] = "W", ["Ｘ"] = "X", ["Ｙ"] = "Y", ["Ｚ"] = "Z", ["［"] = "[",
	["＼"] = "\\", ["］"] = "]", ["＾"] = "^", ["＿"] = "_", ["｀"] = "`",
	["ａ"] = "a", ["ｂ"] = "b", ["ｃ"] = "c", ["ｄ"] = "d", ["ｅ"] = "e",
	["ｆ"] = "f", ["ｇ"] = "g", ["ｈ"] = "h", ["ｉ"] = "i", ["ｊ"] = "j",
	["ｋ"] = "k", ["ｌ"] = "l", ["ｍ"] = "m", ["ｎ"] = "n", ["ｏ"] = "o",
	["ｐ"] = "p", ["ｑ"] = "q", ["ｒ"] = "r", ["ｓ"] = "s", ["ｔ"] = "t",
	["ｕ"] = "u", ["ｖ"] = "v", ["ｗ"] = "w", ["ｘ"] = "x", ["ｙ"] = "y",
	["ｚ"] = "z", ["｛"] = "{", ["｜"] = "|", ["｝"] = "}", ["～"] = "~",
	["“"] = "\"", ["”"] = "\"", ["‘"] = "'", ["’"] = "'", ["【"] = "[",
	["】"] = "]", ["《"] = "<", ["》"] = ">"
}

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shellquote(value)
	return util.shellquote(value)
end

local function write_json(data)
	http.prepare_content("application/json")
	http.write_json(data)
end

local function exec_with_status(command)
	local marker = "__X300TOOLS_CMD_RC__="
	local output = sys.exec(string.format(
		'%s 2>&1; rc=$?; printf "\\n%s%%s" "$rc"',
		command,
		marker
	)) or ""
	local rc = tonumber(output:match("\n" .. marker .. "(%d+)$") or output:match(marker .. "(%d+)$") or "1")

	output = trim(output:gsub("\n?" .. marker .. "%d+$", ""))

	return rc, output
end

local function normalize_punctuation(command)
	for src, dst in pairs(fullwidth_map) do
		command = command:gsub(src, dst)
	end

	command = command:gsub("。", ".")
	command = command:gsub("、", ",")
	command = command:gsub("，", ",")
	command = command:gsub("：", ":")
	command = command:gsub("；", ";")

	return command
end

local function normalize_command(command)
	command = tostring(command or "")
	command = normalize_punctuation(command)
	command = command:gsub("\r", " "):gsub("\n", " "):gsub("%s+", " ")
	command = command:gsub("^%s+", ""):gsub("%s+$", "")
	command = command:gsub("^mipc_wan_cli%s+%-%-at_cmd%s+", "")
	command = command:gsub("^at", "AT")

	if command:match("^%+") then
		command = "AT" .. command
	end

	return command
end

local function binary_path()
	local path = trim(sys.exec("command -v mipc_wan_cli 2>/dev/null"))
	return path ~= "" and path or nil
end

local function split_lines(text)
	local lines = {}

	for line in tostring(text or ""):gmatch("[^\r\n]+") do
		lines[#lines + 1] = trim(line)
	end

	return lines
end

local function normalize_temperature_value(value)
	local numeric = tonumber(value)

	if not numeric or numeric <= -127 then
		return nil
	end

	return numeric
end

local function format_temperature(value)
	local numeric = normalize_temperature_value(value)

	if not numeric then
		return ""
	end

	return string.format("%.1f°C", numeric)
end

local function average_temperature(values)
	local total = 0
	local count = 0

	for _, value in ipairs(values or {}) do
		local numeric = normalize_temperature_value(value)

		if numeric then
			total = total + numeric
			count = count + 1
		end
	end

	if count == 0 then
		return ""
	end

	return string.format("%.1f°C", total / count)
end

local function parse_qtemp(lines)
	local sensors = {}

	for _, line in ipairs(lines or {}) do
		local name, value = line:match('^%+QTEMP:%s*"([^"]+)",%s*"([^"]+)"')
		local numeric = normalize_temperature_value(value)

		if name and numeric then
			sensors[name] = numeric
		end
	end

	return sensors
end

local function platform_temperature_data()
	local binary = binary_path()
	local rc, output, sensors

	if not binary then
		return {}
	end

	rc, output = exec_with_status(string.format(
		"%s --at_cmd %s",
		shellquote(binary),
		shellquote("AT+QTEMP")
	))

	if rc ~= 0 then
		return {}
	end

	sensors = parse_qtemp(split_lines(output))

	return {
		cpu = average_temperature({
			sensors.cpu_little0,
			sensors.cpu_little1,
			sensors.cpu_little2,
			sensors.cpu_little3
		}),
		connsys = format_temperature(sensors.connsys),
		dsp = average_temperature({
			sensors.md0,
			sensors.md1,
			sensors.md2,
			sensors.md3
		}),
		nr_pa = format_temperature(sensors.nrpa_ntc),
		lte_pa = format_temperature(sensors.ltepa_ntc),
		rf = format_temperature(sensors.rf_ntc),
		pmic = format_temperature(sensors.pmic6361_temp)
	}
end

local function command_list()
	local commands = {}

	uci:foreach(AT_CONFIG, "command", function(section)
		if section.enabled ~= "0" and section.command and #section.command > 0 then
			commands[#commands + 1] = {
				id = section[".name"],
				name = section.name or normalize_command(section.command),
				command = normalize_command(section.command),
				description = section.description or ""
			}
		end
	end)

	return commands
end

function index()
	local page = entry({"admin", "system", "advanced-tools"}, firstchild(), _("高级工具"), 88)
	page.dependent = false

	entry({"admin", "system", "advanced-tools", "at"}, call("action_at"), _("AT工具箱"), 10)
	entry({"admin", "system", "advanced-tools", "download-test"}, call("action_download_test"), _("下载测试"), 20)
	entry({"admin", "system", "advanced-tools", "at", "list"}, call("action_at_list")).leaf = true
	entry({"admin", "system", "advanced-tools", "at", "run"}, call("action_at_run")).leaf = true
	entry({"admin", "system", "advanced-tools", "at", "save"}, call("action_at_save")).leaf = true
	entry({"admin", "system", "advanced-tools", "at", "delete"}, call("action_at_delete")).leaf = true
	entry({"admin", "system", "advanced-tools", "temperature"}, call("action_temperature")).leaf = true
end

function action_at()
	luci.template.render("advanced_tools/at", {
		commands = command_list(),
		binary = binary_path(),
		temp_url = dispatcher.build_url("admin", "system", "advanced-tools", "temperature"),
		list_url = dispatcher.build_url("admin", "system", "advanced-tools", "at", "list"),
		run_url = dispatcher.build_url("admin", "system", "advanced-tools", "at", "run"),
		save_url = dispatcher.build_url("admin", "system", "advanced-tools", "at", "save"),
		delete_url = dispatcher.build_url("admin", "system", "advanced-tools", "at", "delete")
	})
end

function action_download_test()
	luci.template.render("advanced_tools/download_test", {
		temp_url = dispatcher.build_url("admin", "system", "advanced-tools", "temperature")
	})
end

function action_at_list()
	write_json({
		available = binary_path() ~= nil,
		commands = command_list()
	})
end

function action_temperature()
	write_json({
		available = binary_path() ~= nil,
		platform_temperature = platform_temperature_data()
	})
end

function action_at_run()
	local command = normalize_command(http.formvalue("command"))
	local binary = binary_path()
	local exit_code, output

	if command == "" then
		write_json({ ok = false, error = "请输入 AT 指令" })
		return
	end

	if not binary then
		write_json({ ok = false, error = "系统中未找到 mipc_wan_cli" })
		return
	end

	exit_code, output = exec_with_status(string.format(
		"%s --at_cmd %s",
		shellquote(binary),
		shellquote(command)
	))

	write_json({
		ok = (exit_code == 0),
		command = command,
		full_command = "mipc_wan_cli --at_cmd " .. command,
		output = output,
		exit_code = exit_code
	})
end

function action_at_save()
	local name = trim(http.formvalue("name") or "")
	local command = normalize_command(http.formvalue("command"))
	local description = trim(http.formvalue("description") or "")
	local sid

	if command == "" then
		write_json({ ok = false, error = "请输入要保存的 AT 指令" })
		return
	end

	if name == "" then
		name = command
	end

	sid = uci:add(AT_CONFIG, "command")
	uci:set(AT_CONFIG, sid, "name", name)
	uci:set(AT_CONFIG, sid, "command", command)
	uci:set(AT_CONFIG, sid, "description", description)
	uci:set(AT_CONFIG, sid, "enabled", "1")
	uci:commit(AT_CONFIG)

	write_json({ ok = true, id = sid })
end

function action_at_delete()
	local sid = http.formvalue("id")

	if not sid or sid == "" then
		write_json({ ok = false, error = "缺少指令 ID" })
		return
	end

	uci:delete(AT_CONFIG, sid)
	uci:commit(AT_CONFIG)

	write_json({ ok = true })
end
