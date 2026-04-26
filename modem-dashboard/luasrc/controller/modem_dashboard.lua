module("luci.controller.modem_dashboard",package.seeall)
local o=require"luci.dispatcher"
local e=require"luci.http"
local i=require"luci.template"
local a=require"luci.model.modem_dashboard"
local function t(t)
e.prepare_content("application/json")
e.write_json(t)
end
function index()
entry({"admin","status","modem-dashboard"},call("action_index"),_("模组详情"),65).dependent=true
entry({"admin","status","modem-dashboard","data"},call("action_data")).leaf=true
entry({"admin","status","modem-dashboard","apply_ca"},call("action_apply_ca")).leaf=true
entry({"admin","status","modem-dashboard","set_cfun"},call("action_set_cfun")).leaf=true
entry({"admin","status","modem-dashboard","save_imei"},call("action_save_imei")).leaf=true
entry({"admin","status","modem-dashboard","apply_imei"},call("action_apply_imei")).leaf=true
entry({"admin","status","modem-dashboard","delete_imei"},call("action_delete_imei")).leaf=true
end
function action_index()
i.render("modem_dashboard/index",{
data_url=o.build_url("admin","status","modem-dashboard","data"),
apply_url=o.build_url("admin","status","modem-dashboard","apply_ca"),
cfun_url=o.build_url("admin","status","modem-dashboard","set_cfun"),
save_imei_url=o.build_url("admin","status","modem-dashboard","save_imei"),
apply_imei_url=o.build_url("admin","status","modem-dashboard","apply_imei"),
delete_imei_url=o.build_url("admin","status","modem-dashboard","delete_imei")
})
end
function action_data()
local a,e=pcall(a.fetch)
if not a or type(e)~="table"then
return t({
meta={
available=false,
error="模组数据读取失败"
}
})
end
t(e)
end
function action_apply_ca()
local e=a.apply_ca(
e.formvalue("dl_ccs"),
e.formvalue("ul_ccs")
)
t(e)
end
function action_set_cfun()
t(a.set_cfun(e.formvalue("mode")))
end
function action_save_imei()
t(a.save_imei(
e.formvalue("name"),
e.formvalue("imei")
))
end
function action_apply_imei()
t(a.apply_imei(e.formvalue("imei")))
end
function action_delete_imei()
t(a.delete_imei(e.formvalue("imei")))
end
