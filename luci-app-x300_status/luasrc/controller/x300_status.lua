module("luci.controller.x300_status", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local fs = require "nixio.fs"
local i18n = require "luci.i18n"

local IMEI_CACHE = "/tmp/x300_status_imei"
local COPS_RAW = "/tmp/x300_status_cops"
local CSQ_RAW = "/tmp/x300_status_csq"
local CESQ_RAW = "/tmp/x300_status_cesq"
local EDMFAPP_RAW = "/tmp/x300_status_edmfapp"
local RATE_CACHE = "/tmp/x300_status_rate_cache"
local MCCMNC_DB = "/usr/share/x300_status/mccmnc.dat"

local ACT_MAP = {
	["0"] = "2G",
	["1"] = "2G",
	["2"] = "3G",
	["3"] = "2G",
	["4"] = "3G",
	["5"] = "3G",
	["6"] = "3G",
	["7"] = "LTE",
	["8"] = "LTE",
	["9"] = "LTE",
	["10"] = "LTE",
	["11"] = "NR 5G",
	["12"] = "NSA 5G"
}

local CHINA_OPERATOR_NAMES = {
	["46000"] = { zh = "中国移动", en = "China Mobile" },
	["46002"] = { zh = "中国移动", en = "China Mobile" },
	["46004"] = { zh = "中国移动", en = "China Mobile" },
	["46007"] = { zh = "中国移动", en = "China Mobile" },
	["46008"] = { zh = "中国移动", en = "China Mobile" },
	["46001"] = { zh = "中国联通", en = "China Unicom" },
	["46006"] = { zh = "中国联通", en = "China Unicom" },
	["46009"] = { zh = "中国联通", en = "China Unicom" },
	["46010"] = { zh = "中国联通", en = "China Unicom" },
	["46003"] = { zh = "中国电信", en = "China Telecom" },
	["46011"] = { zh = "中国电信", en = "China Telecom" },
	["46012"] = { zh = "中国电信", en = "China Telecom" }
}

local function nrarfcn_to_mhz(nrarfcn)
	local value = tonumber(nrarfcn)

	if not value then
		return nil
	end

	if value >= 0 and value <= 599999 then
		return value * 0.005
	elseif value >= 600000 and value <= 2016666 then
		return 3000 + ((value - 600000) * 0.015)
	elseif value >= 2016667 and value <= 3279165 then
		return 24250.08 + ((value - 2016667) * 0.06)
	end

	return nil
end

local function khz_to_mhz(value)
	value = tonumber(value)

	if not value then
		return nil
	end

	return value / 1000
end

local function kbps_to_mbps(value)
	value = tonumber(value)

	if not value then
		return nil
	end

	return value / 1000
end

local function format_decimal(value)
	if value == nil then
		return ""
	end

	if math.abs(value - math.floor(value)) < 0.001 then
		return string.format("%d", value)
	end

	return string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function sorted_numeric_strings(map)
	local values = {}

	for key in pairs(map) do
		values[#values + 1] = tonumber(key) or key
	end

	table.sort(values, function(a, b)
		return tonumber(a) < tonumber(b)
	end)

	local formatted = {}

	for _, value in ipairs(values) do
		formatted[#formatted + 1] = tostring(value)
	end

	return formatted
end

local function trim(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function current_lang()
	return tostring((i18n.context or {}).lang or i18n.default or "en"):lower()
end

local function localized_china_operator(plmn)
	local entry = CHINA_OPERATOR_NAMES[tostring(plmn or "")]

	if not entry then
		return nil
	end

	if current_lang():match("^zh") then
		return entry.zh
	end

	return entry.en
end

local function append_if_missing(list, value)
	value = trim(value)

	if value == "" then
		return
	end

	for _, existing in ipairs(list) do
		if existing == value then
			return
		end
	end

	list[#list + 1] = value
end

local function write_json(data)
	http.prepare_content("application/json")
	http.write_json(data)
end

local function read_file(path)
	if fs.access(path) then
		return fs.readfile(path) or ""
	end

	return ""
end

local function write_file(path, content)
	local fp = io.open(path, "w")

	if not fp then
		return false
	end

	fp:write(content or "")
	fp:close()
	return true
end

local function lookup_operator(plmn)
	local name

	if not plmn or plmn == "" then
		return ""
	end

	name = localized_china_operator(plmn)
	if name and name ~= "" then
		return name
	end

	if fs.access(MCCMNC_DB) then
		name = trim(sys.exec(string.format(
			"awk -F';' '$1==%q { print $3; exit }' %q 2>/dev/null",
			plmn, MCCMNC_DB
		)) or "")
	end

	return name ~= "" and name or plmn
end

local function read_kv_file(path)
	local data = {}

	for line in tostring(read_file(path)):gmatch("[^\n]+") do
		local key, value = line:match("^([%w_]+)=(.*)$")

		if key then
			data[key] = trim(value)
		end
	end

	return data
end

local function write_kv_file(path, data)
	local lines = {}

	for _, key in ipairs({ "iface", "rx", "tx", "ts" }) do
		if data[key] ~= nil then
			lines[#lines + 1] = key .. "=" .. tostring(data[key])
		end
	end

	return write_file(path, table.concat(lines, "\n") .. "\n")
end

local function parse_imei(output)
	local saw_response = false

	for line in tostring(output):gmatch("[^\n]+") do
		line = trim(line:gsub("\r", ""))

		if line == "AT response:" then
			saw_response = true
		elseif saw_response and line:match("^[0-9]+$") and #line >= 14 and #line <= 17 then
			return line
		end
	end

	return ""
end

local function fetch_imei_direct()
	local output = sys.exec("mipc_wan_cli --at_cmd AT+CGSN 2>/dev/null") or ""
	local imei = parse_imei(output)

	if imei ~= "" then
		write_file(IMEI_CACHE, imei .. "\n")
	end

	return imei
end

local function active_ccmni_iface()
	return trim(sys.exec(
		[[PATH=/usr/sbin:/usr/bin:/sbin:/bin ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^ccmni[0-9]+$/ && $3 ~ /UP/ { print $2; exit }']]
	) or "")
end

local function read_iface_counter(iface, name)
	if iface == "" then
		return nil
	end

	return tonumber(trim(read_file(string.format("/sys/class/net/%s/statistics/%s", iface, name))))
end

local function sample_time()
	local uptime = trim(read_file("/proc/uptime"))
	local seconds = tonumber(uptime:match("^([0-9]+%.?[0-9]*)"))

	if seconds and seconds > 0 then
		return seconds
	end

	return tonumber(os.time()) or 0
end

local function format_transfer_rate(bytes_per_sec)
	local value = tonumber(bytes_per_sec) or 0

	if value < 1024 then
		return "0KB/s"
	end

	value = value / 1024
	if value < 1024 then
		return string.format("%dKB/s", math.floor(value + 0.5))
	end

	value = value / 1024
	if value < 1024 then
		return string.format("%.1fMB/s", value):gsub("%.0MB/s$", "MB/s")
	end

	value = value / 1024
	return string.format("%.1fGB/s", value):gsub("%.0GB/s$", "GB/s")
end

local function sample_transfer_rate()
	local iface = active_ccmni_iface()
	local cache = read_kv_file(RATE_CACHE)
	local now = sample_time()
	local zero_rate = "DL 0KB/s / UL 0KB/s"

	if iface == "" then
		write_kv_file(RATE_CACHE, { ts = now })
		return zero_rate
	end

	local rx = read_iface_counter(iface, "rx_bytes")
	local tx = read_iface_counter(iface, "tx_bytes")

	if not rx or not tx then
		return zero_rate
	end

	local prev_rx = tonumber(cache.rx)
	local prev_tx = tonumber(cache.tx)
	local prev_ts = tonumber(cache.ts)
	local rate = zero_rate

	if cache.iface == iface and prev_rx and prev_tx and prev_ts and now > prev_ts then
		local delta = now - prev_ts
		local dl = math.max(0, math.floor((rx - prev_rx) / delta))
		local ul = math.max(0, math.floor((tx - prev_tx) / delta))

		rate = "DL " .. format_transfer_rate(dl) .. " / UL " .. format_transfer_rate(ul)
	end

	write_kv_file(RATE_CACHE, {
		iface = iface,
		rx = rx,
		tx = tx,
		ts = now
	})

	return rate
end

local function parse_cops(output)
	for line in tostring(output):gmatch("[^\n]+") do
		line = trim(line:gsub("\r", ""))

		local plmn, act = line:match('^%+COPS:%s*%d+,%d+,"([0-9]+)",(%d+)')
		if plmn and act then
			return {
				operator = lookup_operator(plmn),
				network_type = ACT_MAP[act] or ""
			}
		end
	end

	return {}
end

local function parse_csq(output)
	for line in tostring(output):gmatch("[^\n]+") do
		line = trim(line:gsub("\r", ""))

		local rssi = tonumber(line:match('^%+CSQ:%s*(%d+),'))
		if rssi and rssi >= 0 and rssi <= 31 then
			return {
				rssi = -113 + (2 * rssi)
			}
		end
	end

	return {}
end

local function parse_cesq(output)
	for line in tostring(output):gmatch("[^\n]+") do
		line = trim(line:gsub("\r", ""))

		if line:match("^%+CESQ:") then
			local values = {}

			for value in line:gmatch("(%d+)") do
				values[#values + 1] = tonumber(value)
			end

			if #values >= 9 then
				local rsrp_raw = values[7]
				local rsrq_raw = values[8]
				local sinr_raw = values[9]
				local result = {}

				if rsrp_raw and rsrp_raw ~= 255 then
					result.rsrp = rsrp_raw - 142
				end

				if rsrq_raw and rsrq_raw ~= 255 then
					result.rsrq = (rsrq_raw / 2) - 40
				end

				if sinr_raw and sinr_raw ~= 255 then
					result.sinr = sinr_raw - 59
				end

				return result
			end
		end
	end

	return {}
end

local function parse_edmfapp(output)
	local result = {
		network_type = "",
		band = "",
		pci = "",
		nrarfcn = "",
		center_freq = "",
		ca_status = ""
	}
	local carriers = {}
	local ordered_bands = {}
	local ordered_pci = {}
	local ordered_nrarfcn = {}
	local center_freqs = {}
	local summary_act

	for line in tostring(output):gmatch("[^\n]+") do
		line = trim(line:gsub("\r", ""))

		local act = line:match("^%+EDMFAPP:%s*6,4,(%d+),")
		if act and ACT_MAP[act] then
			summary_act = ACT_MAP[act]
		end

		local fields = nil
		if line:match('^%+EDMFAPP:%s*6,4,"') then
			fields = {}
			for field in line:gmatch('([^,]+)') do
				fields[#fields + 1] = trim(field:gsub('^"', ""):gsub('"$', ""))
			end
		end

		if fields and #fields >= 8 then
			local carrier = fields[3]
			local band = fields[4]
			local pci = fields[5]
			local nrarfcn = fields[6]
			local prefix = carrier and carrier:match("^NR") and "n" or ""
			carriers[#carriers + 1] = {
				label = carrier,
				band = band
			}
			append_if_missing(ordered_bands, prefix .. band)
			append_if_missing(ordered_pci, pci)
			append_if_missing(ordered_nrarfcn, nrarfcn)

			local center = nrarfcn_to_mhz(nrarfcn)
			if center then
				center_freqs[#center_freqs + 1] = format_decimal(center)
			end

		end
	end

	if summary_act and #carriers > 1 then
		result.network_type = summary_act .. " (CA)"
	elseif summary_act then
		result.network_type = summary_act
	elseif carriers[1] then
		result.network_type = carriers[1].label
	end

	result.band = table.concat(ordered_bands, " / ")
	result.pci = table.concat(ordered_pci, " / ")
	result.nrarfcn = table.concat(ordered_nrarfcn, " / ")
	result.center_freq = #center_freqs > 0 and table.concat(center_freqs, " / ") .. " MHz" or ""
	if #carriers > 1 then
		local band_chain = {}

		for _, carrier in ipairs(carriers) do
			if carrier.band and carrier.band ~= "" then
				local prefix = carrier.label and carrier.label:match("^NR") and "n" or ""
				band_chain[#band_chain + 1] = prefix .. carrier.band
			end
		end

		result.ca_status = table.concat(band_chain, "+")
	else
		result.ca_status = ""
	end

	return result
end

local function fetch_cell_status()
	local iface = active_ccmni_iface()

	sys.call(string.format(
		"sh -c 'rm -f %q %q %q %q; mipc_wan_cli --at_cmd AT+COPS? > %q 2>&1; mipc_wan_cli --at_cmd AT+CSQ > %q 2>&1; mipc_wan_cli --at_cmd AT+CESQ > %q 2>&1; mipc_wan_cli --at_cmd AT+EDMFAPP=6,4 > %q 2>&1'",
		COPS_RAW, CSQ_RAW, CESQ_RAW, EDMFAPP_RAW, COPS_RAW, CSQ_RAW, CESQ_RAW, EDMFAPP_RAW
	))

	local data = {}

	for key, value in pairs(parse_cops(read_file(COPS_RAW))) do
		data[key] = value
	end

	for key, value in pairs(parse_csq(read_file(CSQ_RAW))) do
		data[key] = value
	end

	for key, value in pairs(parse_cesq(read_file(CESQ_RAW))) do
		data[key] = value
	end

	for key, value in pairs(parse_edmfapp(read_file(EDMFAPP_RAW))) do
		if value ~= "" then
			data[key] = value
		end
	end

	local ok_rate, rate = pcall(sample_transfer_rate)
	data.transfer_rate = ok_rate and rate or "DL 0KB/s / UL 0KB/s"
	data.ifname = iface

	return data
end

function index()
	entry({"admin", "status", "x300_status", "imei"}, call("action_imei")).leaf = true
	entry({"admin", "status", "x300_status", "cell"}, call("action_cell")).leaf = true
end

function action_imei()
	local imei = trim(read_file(IMEI_CACHE))
	local data = {}

	if imei == "" then
		imei = fetch_imei_direct()
	end

	if imei ~= "" then
		data.imei = imei
	end

	write_json(data)
end

function action_cell()
	local ok, cell = pcall(fetch_cell_status)
	local data = {}

	if not ok or type(cell) ~= "table" then
		return write_json(data)
	end

	if cell.operator and cell.operator ~= "" then
		data.operator = cell.operator
	end

	if cell.network_type and cell.network_type ~= "" then
		data.network_type = cell.network_type
	end

	if cell.band and cell.band ~= "" then
		data.band = cell.band
	end

	if cell.pci and cell.pci ~= "" then
		data.pci = cell.pci
	end

	if cell.nrarfcn and cell.nrarfcn ~= "" then
		data.nrarfcn = cell.nrarfcn
	end

	if cell.center_freq and cell.center_freq ~= "" then
		data.center_freq = cell.center_freq
	end

	if cell.ca_status and cell.ca_status ~= "" then
		data.ca_status = cell.ca_status
	end

	if cell.transfer_rate and cell.transfer_rate ~= "" then
		data.transfer_rate = cell.transfer_rate
	end

	if cell.ifname and cell.ifname ~= "" then
		data.ifname = cell.ifname
	end

	if cell.rssi then
		data.rssi = cell.rssi
	end

	if cell.rsrp then
		data.rsrp = cell.rsrp
	end

	if cell.rsrq then
		data.rsrq = cell.rsrq
	end

	if cell.sinr then
		data.sinr = cell.sinr
	end

	write_json(data)
end
