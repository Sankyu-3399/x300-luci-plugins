module("luci.model.modem_dashboard",package.seeall)
local o=require"luci.i18n"
local r=require"luci.jsonc"
local l=require"luci.sys"
local h=require"luci.util"
local a=require"nixio.fs"
local n="/usr/share/modem-dashboard/mccmnc.dat"
local i="/usr/share/x300_status/mccmnc.dat"
local q="/tmp/modem_dashboard_carrier_cache.json"
local s="/tmp/modem_dashboard_ca_cache.json"
local k="/tmp/modem_dashboard_signal_cache.json"
local v="/etc/modem-dashboard"
local u=v.."/imei_profiles.json"
local m={
["0"]="2G",
["1"]="2G",
["2"]="3G",
["3"]="2G",
["4"]="3G",
["5"]="3G",
["6"]="3G",
["7"]="LTE",
["8"]="LTE",
["9"]="LTE",
["10"]="LTE",
["11"]="NR 5G",
["12"]="NSA 5G"
}
local z={
["0"]="5MHz",
["1"]="10MHz",
["2"]="15MHz",
["3"]="20MHz",
["4"]="25MHz",
["5"]="30MHz",
["6"]="40MHz",
["7"]="50MHz",
["8"]="60MHz",
["9"]="80MHz",
["10"]="90MHz",
["11"]="100MHz",
["255"]="N/A"
}
local _={
["46000"]={zh="中国移动",en="China Mobile"},
["46002"]={zh="中国移动",en="China Mobile"},
["46004"]={zh="中国移动",en="China Mobile"},
["46007"]={zh="中国移动",en="China Mobile"},
["46008"]={zh="中国移动",en="China Mobile"},
["46001"]={zh="中国联通",en="China Unicom"},
["46006"]={zh="中国联通",en="China Unicom"},
["46009"]={zh="中国联通",en="China Unicom"},
["46010"]={zh="中国联通",en="China Unicom"},
["46003"]={zh="中国电信",en="China Telecom"},
["46011"]={zh="中国电信",en="China Telecom"},
["46012"]={zh="中国电信",en="China Telecom"}
}
local t
local function e(e)
return tostring(e or""):gsub("^%s+",""):gsub("%s+$","")
end
local function p(t)
if t==nil then
return false
end
if type(t)=="number"then
return true
end
return e(t)~=""
end
local function f(e)
return h.shellquote(e)
end
local function x()
return tostring((o.context or{}).lang or o.default or"en"):lower()
end
local function b()
if t~=nil then
return t or nil
end
local e=e(l.exec("command -v mipc_wan_cli 2>/dev/null"))
t=(e~="")and e or false
return t or nil
end
local function j()
if a.access(n)then
return n
end
if a.access(i)then
return i
end
return nil
end
local function h(t)
if not a.access(t)then
return{}
end
local t=a.readfile(t)
if not t or e(t)==""then
return{}
end
local t,e=pcall(r.parse,t)
if t and type(e)=="table"then
return e
end
return{}
end
local function d(t,e)
local o,e=pcall(r.stringify,e or{})
if o and e and e~=""then
a.writefile(t,e)
end
end
local function E(e)
if a.access(e)then
return true
end
if a.mkdirr then
return a.mkdirr(e)
end
return l.call("mkdir -p "..f(e))==0
end
local function y(o)
local t=1
return function()
local a
local e
if t>#o then
return nil
end
a=o:byte(t)
e=1
if a>=240 then
e=4
elseif a>=224 then
e=3
elseif a>=192 then
e=2
end
local a=o:sub(t,t+e-1)
t=t+e
return a
end
end
local function w(e)
local t,e=tostring(e or""):gsub("[^\128-\193]","")
return e
end
local function c(e)
local e,t,a,o=e:byte(1,4)
if not e then
return nil
end
if e<128 then
return e
elseif e<224 and t then
return((e%32)*64)+(t%64)
elseif e<240 and t and a then
return((e%16)*4096)+((t%64)*64)+(a%64)
elseif t and a and o then
return((e%8)*262144)+((t%64)*4096)+((a%64)*64)+(o%64)
end
return nil
end
local function n(e)
local t=0
local o=#e
for a=1,o do
local e=tonumber(e:sub(a,a))
if not e then
return false
end
if a%2~=o%2 then
e=e*2
if e>9 then
e=e-9
end
end
t=t+e
end
return t%10==0
end
local function i(t)
t=e(t)
if t==""then
return false,"请输入常用IMEI"
end
if not t:match("^%d+$")then
return false,"IMEI格式错误"
end
if#t~=15 or not n(t)then
return false,"请输入符合规范的15位IMEI"
end
return true
end
local function g(t)
t=e(t)
if t==""then
return false,"请输入保存名字"
end
if w(t)>10 then
return false,"保存名字最多10个汉字或等量字符"
end
for e in y(t)do
local e=c(e)
if not e then
return false,"保存名字仅支持汉字、英文、数字"
end
if not(
(e>=48 and e<=57)or
(e>=65 and e<=90)or
(e>=97 and e<=122)or
(e>=13312 and e<=19903)or
(e>=19968 and e<=40959)or
(e>=63744 and e<=64255)
)then
return false,"保存名字仅支持汉字、英文、数字"
end
end
return true
end
local function P(t)
return"已保存"..tostring(t or""):sub(-4)
end
local function W(h)
local o=h
local t={}
local a={}
if type(o)~="table"then
o={}
end
if type(o.profiles)=="table"then
o=o.profiles
end
for n,s in ipairs(o or{})do
local o=e((s or{}).imei)
local n=e((s or{}).name)
local h=((s or{}).locked==true)
local s=select(1,i(o))
if s and o~=""and not a[o]and n~="原始IMEI"and not h then
if not select(1,g(n))then
n=P(o)
end
t[#t+1]={
name=n,
imei=o
}
a[o]=true
end
end
return{
profiles=t
}
end
local function o()
if not a.access(u)then
return{
profiles={}
}
end
local t=a.readfile(u)
if not t or e(t)==""then
return{
profiles={}
}
end
local t,e=pcall(r.parse,t)
if not t or type(e)~="table"then
return{
profiles={}
}
end
return e
end
local function y(o)
local t,e
if not E(v)then
return false
end
t,e=pcall(r.stringify,W(o))
if not t or not e or e==""then
return false
end
return a.writefile(u,e)
end
local function w()
return W(o())
end
local function r(a,t)
local o=w()
local t={}
a=e(a)
for a,e in ipairs(o.profiles or{})do
t[#t+1]={
name=e.name,
imei=e.imei,
label=string.format("%s-%s",e.name,e.imei),
locked=false
}
end
if a==""and t[1]then
a=t[1].imei or""
end
return{
current_imei="",
selected_imei=a,
options=t
}
end
local function c(t,a,e)
local o={}
local i={}
local n={}
for s,e in ipairs(e or{})do
local t=t and t[e]
local a=a and a[e]
if p(t)then
o[e]=t
i[e]="live"
n[e]=t
elseif p(a)then
o[e]=a
i[e]="cache"
n[e]=a
else
o[e]=t or a or""
end
end
return o,i,n
end
local function u(o)
local t={}
local a=false
for o in tostring(o or""):gmatch("[^\n]+")do
local e=e(o:gsub("\r",""))
if e=="AT response:"then
a=true
elseif a then
if e=="OK"or e=="ERROR"or e:match("^%[exit code%]")then
break
elseif e~=""then
t[#t+1]=e
end
end
end
return t
end
local function n(a)
local t=b()
if not t then
return false,"mipc_wan_cli not found",{}
end
local t=l.exec(string.format(
"%s --at_cmd %s 2>&1",
f(t),
f(a)
))or""
local e=t:match("\nOK%s*$")~=nil or e(t):match("OK$")~=nil
return e,t,u(t)
end
local function a(e)
local t,t,e=n(e)
return e
end
local function u(t)
local e={}
for t in pairs(t)do
e[#e+1]=tonumber(t)or t
end
table.sort(e,function(e,t)
return tonumber(e)<tonumber(t)
end)
local t={}
for a,e in ipairs(e)do
t[#t+1]=tostring(e)
end
return t
end
local function v(e)
local e=_[tostring(e or"")]
if not e then
return nil
end
if x():match("^zh")then
return e.zh
end
return e.en
end
local function f(t)
local a=j()
local o=""
if not t or t==""or not a then
return""
end
o=e(l.exec(string.format(
"awk -F';' '$1==%q { print $3; exit }' %q 2>/dev/null",
t,a
))or"")
return o
end
local function p(e)
local t=v(e)or f(e)
if t~=""then
return t
end
return e or""
end
local function f(n)
local a,o={},{}
local t,i=1,false
while t<=#n do
local e=n:sub(t,t)
if e=='"'then
if i and n:sub(t+1,t+1)=='"'then
o[#o+1]='"'
t=t+1
else
i=not i
end
elseif e==","and not i then
a[#a+1]=table.concat(o)
o={}
else
o[#o+1]=e
end
t=t+1
end
a[#a+1]=table.concat(o)
for t,o in ipairs(a)do
a[t]=e(o)
end
return a
end
local function l(t)
t=e(t)
if t==""then
return""
end
return z[t]or(t.."MHz")
end
local function D(t)
return e(t[1]or"")
end
local function R(t)
local a=e((t[1]or""):gsub("^%+CGMR:%s*",""))
local t,o=a:match("^(.-),%s*([0-9][0-9][0-9][0-9]/%d%d/%d%d%s+%d%d:%d%d)$")
return{
version=e(t~=""and t or a),
build_time=e(o)
}
end
local function v(t)
for a,t in ipairs(t or{})do
local e=e(t):match("^([0-9]+)$")
if e then
return e
end
end
return""
end
local function H(t)
local e=e(t[1]or"")
local e=e:match("^%+CPIN:%s*(.+)$")or e
if e=="READY"then
return"SIM正常"
end
if e~=""then
return"SIM异常"
end
return""
end
local function N(t)
local e=e(t[1]or"")
return e:match("^%+CFUN:%s*(%d+)")or""
end
local function S(t)
local e=e(t[1]or"")
local e,t=e:match('^%+COPS:%s*%d+,%d+,"([0-9]+)",(%d+)')
return{
operator=e and p(e)or"",
network_type=t and(m[t]or"")or""
}
end
local function U(t)
local e=e(t[1]or"")
local e=e:match("^%+C5GREG:%s*%d+,([0-9]+)")
if e=="1"then
return"已注册"
elseif e=="5"then
return"已注册(漫游中)"
elseif e=="0"or e=="2"or e=="3"or e=="4"then
return"未注册"
elseif e then
return"异常"
end
return""
end
local function L(t)
local e=e(t[1]or"")
local e=e:match("^%+CSCON:%s*%d+,([0-9]+)")
if e=="0"then
return"空闲"
elseif e=="1"then
return"已连接"
elseif e then
return"异常"
end
return""
end
local function I(t)
local e=e(t[1]or"")
local e=tonumber(e:match("^%+CSQ:%s*(%d+),"))
if e and e>=0 and e<=31 then
return-113+(2*e)
end
return nil
end
local function T(t)
local t=e(t[1]or"")
local e={}
for t in t:gmatch("(%d+)")do
e[#e+1]=tonumber(t)
end
if#e<9 then
return{}
end
local t={}
local o=e[7]
local a=e[8]
local e=e[9]
if o and o~=255 then
t.rsrp=o-142
end
if a and a~=255 then
t.rsrq=(a/2)-40
end
if e and e~=255 then
t.sinr=e-59
end
return t
end
local function A(a)
local t={
network_type="",
band="",
pci="",
frequency="",
ca_status="",
carrier_type="",
carrier_bandwidth="",
dl_bwp="",
ul_bwp="",
dl_mimo="",
ul_mimo="",
dl_bler="",
ul_bler="",
carriers={}
}
local n={}
local h={}
local s={}
local i
for a,o in ipairs(a or{})do
local a=o:match("^%+EDMFAPP:%s*6,4,(%d+),")
if a and m[a]then
i=m[a]
end
if o:match('^%+EDMFAPP:%s*6,4,"')then
local a=f(o:gsub("^%+EDMFAPP:%s*",""))
if#a>=8 then
local d=a[3]
local r=a[4]
local i=a[5]
local o=a[6]
local u=l(a[7])
local m=l(a[7])
local c=l(a[8])
local l=e(a[9]or"")
local e=e(a[10]or"")
t.carriers[#t.carriers+1]={
label=d,
band=r,
pci=i,
frequency=o,
bandwidth=u,
dl_bwp=m,
ul_bwp=c,
dl_mimo=l,
ul_mimo=e
}
n[r]=true
h[i]=true
s[o]=true
end
elseif o:match("^%+EDMFAPP:%s*6,12,")then
local a,o=o:match("^%+EDMFAPP:%s*6,12,(%d+),([%-%d]+)")
if a and o then
local e=e(o)=="255"and"N/A"or(e(o).."%")
if a=="0"then
t.dl_bler=e
elseif a=="1"then
t.ul_bler=e
end
end
end
end
if i then
t.network_type=i
elseif t.carriers[1]then
t.network_type=t.carriers[1].label
end
local e={}
for o,a in ipairs(u(n))do
local t=(t.network_type=="NR 5G")and"n"or""
e[#e+1]=t..a
end
t.band=table.concat(e,"+")
t.pci=table.concat(u(h)," / ")
t.frequency=table.concat(u(s)," / ")
if t.carriers[1]then
local e=t.carriers[1]
t.carrier_type=e.label or""
t.carrier_bandwidth=e.bandwidth or""
t.dl_bwp=e.dl_bwp or""
t.ul_bwp=e.ul_bwp or""
t.dl_mimo=e.dl_mimo or""
t.ul_mimo=e.ul_mimo or""
end
if#t.carriers>1 then
local a={}
for o,e in ipairs(t.carriers)do
if e.band and e.band~=""then
local t=(e.label or""):match("^NR")and"n"or""
a[#a+1]=t..e.band
end
end
t.ca_status=table.concat(a,"+")
else
t.ca_status=""
end
return t
end
local function p(t)
for a,t in ipairs(t or{})do
local e=e(t):match("^%+ESBP:%s*([%-%d]+)$")
if e then
return e
end
end
return""
end
local function o(e)
e=tonumber(e)
if not e or e<=-127 then
return nil
end
return e
end
local function t(e)
e=o(e)
if not e then
return""
end
return string.format("%.1f°C",e)
end
local function l(e)
local a=0
local t=0
for i,e in ipairs(e or{})do
e=o(e)
if e then
a=a+e
t=t+1
end
end
if t==0 then
return""
end
return string.format("%.1f°C",a/t)
end
local function o(t)
local a={}
for o,t in ipairs(t or{})do
local t,e=e(t):match('^%+QTEMP:%s*"([^"]+)",%s*"([^"]+)"')
local e=tonumber(e)
if t and e then
a[t]=e
end
end
return a
end
local function C(e)
local e=o(e)
return{
cpu=l({
e.cpu_little0,
e.cpu_little1,
e.cpu_little2,
e.cpu_little3
}),
connsys=t(e.connsys),
dsp=l({
e.md0,
e.md1,
e.md2,
e.md3
}),
nr_pa=t(e.nrpa_ntc),
lte_pa=t(e.ltepa_ntc),
rf=t(e.rf_ntc),
pmic=t(e.pmic6361_temp)
}
end
local function O(t,n)
local t=e(t[1]or"")
local a=t:match("^%+ECELL:%s*(.+)$")
local t={}
if not a then
return t
end
local a=f(a)
local s=tonumber(a[1])or 0
local o=15
local i=2
for h=1,s do
local i=i+((h-1)*o)
local s=e(a[i+1]or"")
local o=e(a[i+5]or"")
local e=e(a[i+14]or"")
if s~=""or o~=""or e~=""then
local a=""
if n and n.carriers then
for i,t in ipairs(n.carriers)do
if t.pci==o and t.frequency==e then
a=(i==1)and"主载波"or"辅载波"
break
end
end
end
t[#t+1]={
index=h,
cell_id=s,
pci=o,
frequency=e,
current=a
}
end
end
return t
end
local function E()
local x=a("AT+CGMM")
local u=a("AT+CGMR")
local f=a("AT+CGSN")
local _=a("AT+CIMI")
local z=a("AT+CPIN?")
local i=a("AT+COPS?")
local j=a("AT+C5GREG?")
local b=a("AT+CSCON?")
local n=a("AT+CSQ")
local e=a("AT+CESQ")
local t=a("AT+EDMFAPP=6,4")
local o=a("AT+EDMFAPP=6,12")
local y=a("AT+ECELL")
local l=a("AT+QTEMP")
local w=a('AT+ESBP=8,"SBP_NR_CA_MAX_CC_NUM"')
local g=a('AT+ESBP=8,"SBP_NR_CA_MAX_UL_CC_NUM"')
local u=R(u)
local m=S(i)
local i=T(e)
local a=C(l)
local l=v(f)
local e={}
for a,t in ipairs(t)do
e[#e+1]=t
end
for a,t in ipairs(o)do
e[#e+1]=t
end
local o=A(e)
local f=o.network_type~=""and o.network_type or(m.network_type or"")
local e=h(q)
local E=h(s)
local T=h(k)
local e,t,A=c(o,e,{
"carrier_type",
"band",
"pci",
"frequency",
"carrier_bandwidth",
"dl_bwp",
"ul_bwp",
"dl_mimo",
"ul_mimo",
"dl_bler",
"ul_bler",
"ca_status"
})
local h,w,p=c({
dl_max_cc=p(w),
ul_max_cc=p(g)
},E,{
"dl_max_cc",
"ul_max_cc"
})
local i,n,c=c({
rssi=I(n),
rsrp=i.rsrp,
rsrq=i.rsrq,
sinr=i.sinr
},T,{
"rssi",
"rsrp",
"rsrq",
"sinr"
})
d(q,A)
d(s,p)
d(k,c)
return{
meta={
available=true
},
device={
model=D(x),
baseband=u.version or"",
baseband_time=u.build_time or"",
imei=l,
imsi=v(_)
},
imei_manager=r(l,l),
platform_temperature={
cpu=a.cpu or"",
connsys=a.connsys or"",
dsp=a.dsp or"",
nr_pa=a.nr_pa or"",
lte_pa=a.lte_pa or"",
rf=a.rf or"",
pmic=a.pmic or""
},
registration={
sim_status=H(z),
operator=m.operator or"",
network_type=f,
band=e.band or"",
pci=e.pci or"",
ca_status=e.ca_status or"",
registration_5g=U(j),
connection_status=L(b)
},
signal={
rssi=i.rssi,
rsrp=i.rsrp,
rsrq=i.rsrq,
sinr=i.sinr,
freshness={
rssi=n.rssi,
rsrp=n.rsrp,
rsrq=n.rsrq,
sinr=n.sinr
}
},
carrier={
carrier_type=e.carrier_type or"",
band=e.band or"",
pci=e.pci or"",
frequency=e.frequency or"",
bandwidth=e.carrier_bandwidth or"",
dl_bwp=e.dl_bwp or"",
ul_bwp=e.ul_bwp or"",
dl_mimo=e.dl_mimo or"",
ul_mimo=e.ul_mimo or"",
dl_bler=e.dl_bler or"",
ul_bler=e.ul_bler or"",
freshness={
carrier_type=t.carrier_type,
band=t.band,
pci=t.pci,
frequency=t.frequency,
bandwidth=t.carrier_bandwidth,
dl_bwp=t.dl_bwp,
ul_bwp=t.ul_bwp,
dl_mimo=t.dl_mimo,
ul_mimo=t.ul_mimo,
dl_bler=t.dl_bler,
ul_bler=t.ul_bler
}
},
ca_config={
visible=f=="NR 5G",
dl_max_cc=h.dl_max_cc or"",
ul_max_cc=h.ul_max_cc or"",
freshness={
dl_max_cc=w.dl_max_cc,
ul_max_cc=w.ul_max_cc
}
},
cells=O(y,o),
timestamp=os.time()
}
end
local function l()
return{
meta={
available=false,
flight_mode=true,
error="模组处于飞行模式，暂时无法获取数据"
},
device={},
platform_temperature={},
registration={},
signal={
freshness={}
},
carrier={
freshness={}
},
imei_manager=r("",""),
ca_config={
visible=false
},
timestamp=os.time()
}
end
function save_imei(a,t)
local d,h=i(t)
local n,s=g(a)
local o
local i=false
if not d then
return{
ok=false,
error=h
}
end
if not n then
return{
ok=false,
error=s
}
end
o=w("")
a=e(a)
t=e(t)
for o,e in ipairs(o.profiles or{})do
if e.imei==t then
e.name=a
i=true
break
end
end
if not i then
o.profiles[#o.profiles+1]={
name=a,
imei=t
}
end
if not y(o)then
return{
ok=false,
error="本地保存失败"
}
end
return{
ok=true,
message=i and"已存在并更新"or"保存成功",
manager=r(t,"")
}
end
function delete_imei(t)
local a=w("")
local o={}
local i=false
t=e(t)
if t==""then
return{
ok=false,
error="请先选择一个IMEI"
}
end
for a,e in ipairs(a.profiles or{})do
if e.imei==t then
i=true
else
o[#o+1]=e
end
end
if not i then
return{
ok=false,
error="未找到可删除的IMEI"
}
end
a.profiles=o
if not y(a)then
return{
ok=false,
error="删除失败"
}
end
return{
ok=true,
message="删除成功",
manager=r("","")
}
end
function apply_imei(o)
local h,s=i(o)
local i,t
local a
if not h then
return{
ok=false,
error=s
}
end
if not available()then
return{
ok=false,
error="系统中未找到 mipc_wan_cli"
}
end
i,t=n(string.format('AT+EGMR=1,7,"%s"',e(o)))
a=i and tostring(t or""):match("AT response:")~=nil and(
tostring(t or""):match("\nOK%s*$")~=nil or e(t):match("OK$")
)
return{
ok=a,
imei=e(o),
error=a and nil or"IMEI修改失败"
}
end
function available()
return b()~=nil
end
function fetch()
if not available()then
return{
meta={
available=false,
error="系统中未找到 mipc_wan_cli，无法读取模组数据"
}
}
end
if N(a("AT+CFUN?"))=="4"then
return l()
end
return E()
end
function apply_ca(t,a)
local t=e(t)
local e=e(a)
local a={}
local i=h(s)
local o=true
if not available()then
return{
ok=false,
error="系统中未找到 mipc_wan_cli"
}
end
if t==""and e==""then
return{
ok=false,
error="请至少填写一个 CA 载波数"
}
end
if t~=""and not t:match("^%d+$")then
return{
ok=false,
error="下行 CA 载波数只能输入数字"
}
end
if e~=""and not e:match("^%d+$")then
return{
ok=false,
error="上行 CA 载波数只能输入数字"
}
end
if t~=""then
local e=n(string.format('AT+ESBP=6,"SBP_NR_CA_MAX_CC_NUM",%s',t))
a[#a+1]={
label="下行",
value=t,
ok=e
}
o=o and e
if e then
i.dl_max_cc=t
end
end
if e~=""then
local t=n(string.format('AT+ESBP=6,"SBP_NR_CA_MAX_UL_CC_NUM",%s',e))
a[#a+1]={
label="上行",
value=e,
ok=t
}
o=o and t
if t then
i.ul_max_cc=e
end
end
d(s,i)
return{
ok=o and#a>0,
error=o and nil or"部分配置写入失败",
results=a
}
end
function set_cfun(t)
t=e(t)
if not available()then
return{
ok=false,
error="系统中未找到 mipc_wan_cli"
}
end
if t~="1"and t~="4"then
return{
ok=false,
error="仅支持切换到 CFUN=1 或 CFUN=4"
}
end
local e=n("AT+CFUN="..t)
return{
ok=e,
mode=t,
error=e and nil or((t=="4")and"开启飞行模式失败"or"关闭飞行模式失败")
}
end
