
(function(){'use strict';var state=window.ModemDashboardConfig||{};var page=document.querySelector('.modemdash-page');if(!page)
return;var resourceBase=state.resource_base||'';var icons={show:resourceBase+'/view.svg',hide:resourceBase+'/hide.svg',reload:resourceBase+'/reload.svg'};var refreshBadge=document.getElementById('modemdash-refresh');var refreshNowButton=document.getElementById('modemdash-refresh-now');var refreshIcon=document.getElementById('modemdash-refresh-icon');var noticeBar=document.getElementById('modemdash-notice');var summaryRoot=document.getElementById('modemdash-summary');var statusRow=document.getElementById('modemdash-status-row');var carrierRow=document.getElementById('modemdash-carrier-row');var secondarySection=document.getElementById('modemdash-secondary-section');var hardwareSection=document.getElementById('modemdash-hardware-section');var signalCard=document.getElementById('modemdash-signal-card');var carrierCard=document.getElementById('modemdash-carrier-card');var connectionCard=document.getElementById('modemdash-connection-card');var cellsCard=document.getElementById('modemdash-cells-card');var temperatureCard=document.getElementById('modemdash-temperature-card');var connectionRoot=document.getElementById('modemdash-connection-kv');var enableFlightButton=document.getElementById('modemdash-enable-flight');var disableFlightButton=document.getElementById('modemdash-disable-flight');var sensitiveToggle=document.getElementById('modemdash-sensitive-toggle');var sensitiveIcon=document.getElementById('modemdash-sensitive-icon');var signalShell=document.getElementById('modemdash-signal-shell');var signalRoot=document.getElementById('modemdash-signal');var signalDiagnosisPanel=document.getElementById('modemdash-signal-diagnosis-panel');var signalDiagnosisRoot=document.getElementById('modemdash-signal-diagnosis');var carrierRoot=document.getElementById('modemdash-carrier');var caCard=document.getElementById('modemdash-ca-card');var caCurrentRoot=document.getElementById('modemdash-ca-current');var caDlInput=document.getElementById('modemdash-dl-ccs');var caUlInput=document.getElementById('modemdash-ul-ccs');var caApplyButton=document.getElementById('modemdash-apply');var caMessage=document.getElementById('modemdash-ca-message');var currentCellSection=document.getElementById('modemdash-current-cell-section');var currentCellRoot=document.getElementById('modemdash-current-cell');var neighborSection=document.getElementById('modemdash-neighbor-section');var neighborListRoot=document.getElementById('modemdash-neighbor-list');var platformTemperatureRoot=document.getElementById('modemdash-platform-temperature');var sensitiveHidden=window.localStorage.getItem('modem_dashboard_sensitive_hidden')==='1';var previousSignalPercents={};var latestMeta={};var refreshTimer=null;var lastDashboardData=null;var imeiApplyResetTimer=null;var imeiSelect=null;var imeiInput=null;var imeiNameInput=null;var imeiSaveButton=null;var imeiDeleteButton=null;var imeiApplyButton=null;var imeiMessageNode=null;var currentImeiManager={options:[],selected_imei:''};var imeiUiState={draftImei:'',draftName:'',selectedImei:'',dirtyImei:false,dirtyName:false};if(refreshIcon)
refreshIcon.src=icons.reload;function hasValue(value){return value!=null&&value!=='';}
function textValue(value,fallback){return hasValue(value)?String(value):(fallback||'N/A');}
function luhnValidImei(value){var digits=String(value||'');var sum=0;var i;var digit;if(!/^\d{15}$/.test(digits))
return false;for(i=0;i<digits.length;i++){digit=Number(digits.charAt(i));if(i%2===digits.length%2){digit*=2;if(digit>9)
digit-=9;}
sum+=digit;}
return sum%10===0;}
function validateImei(value){var text=String(value||'').trim();if(!text)
return'请输入常用IMEI';if(!/^\d+$/.test(text))
return'IMEI格式错误';if(!/^\d{15}$/.test(text)||!luhnValidImei(text))
return'请输入符合规范的15位IMEI';return'';}
function sanitizeImeiValue(value){return String(value||'').replace(/\D+/g,'').slice(0,15);}
function sanitizeProfileNameValue(value){return Array.from(String(value||'')).filter(function(char){return/^[A-Za-z0-9\u3400-\u9FFF]$/.test(char);}).join('');}
function validateProfileName(value){var text=String(value||'').trim();if(!text)
return'请输入保存名字';if(Array.from(text).length>10)
return'保存名字最多10个汉字或等量字符';if(!Array.from(text).every(function(char){return/^[A-Za-z0-9\u3400-\u9FFF]$/.test(char);}))
return'保存名字仅支持汉字、英文、数字';return'';}
function clearNode(node){if(node)
node.innerHTML='';}
function captureImeiFocusState(){var active=document.activeElement;if(active===imeiInput){return{field:'imei',start:imeiInput.selectionStart,end:imeiInput.selectionEnd};}
if(active===imeiNameInput){return{field:'name',start:imeiNameInput.selectionStart,end:imeiNameInput.selectionEnd};}
if(active===imeiSelect)
return{field:'select'};return null;}
function restoreImeiFocusState(state){var target;var start;var end;if(!state||!state.field)
return;if(state.field==='imei')
target=imeiInput;else if(state.field==='name')
target=imeiNameInput;else if(state.field==='select')
target=imeiSelect;if(!target||typeof target.focus!=='function')
return;try{target.focus();}catch(err){return;}
if((state.field==='imei'||state.field==='name')&&typeof target.setSelectionRange==='function'&&typeof state.start==='number'&&typeof state.end==='number'){start=Math.min(state.start,target.value.length);end=Math.min(state.end,target.value.length);target.setSelectionRange(start,end);}}
function setVisible(node,visible){if(node)
node.style.display=visible?'':'none';}
function isVisible(node){return!!(node&&node.style.display!=='none');}
function metricPercent(value,min,max){var numeric=Number(value);if(isNaN(numeric))
return 0;return Math.max(0,Math.min(100,Math.round(((numeric-min)*100)/(max-min))));}
function parseMetricNumber(value){var numeric;if(!hasValue(value))
return null;numeric=Number(value);return isNaN(numeric)?null:numeric;}
function parseTemperature(value){var numeric=parseFloat(String(value||'').replace('°C',''));return isNaN(numeric)?null:numeric;}
function parseColor(value){var color=String(value||'').trim();var match;if(!color)
return null;if(color.charAt(0)==='#'){if(color.length===4){return{r:parseInt(color.charAt(1)+color.charAt(1),16),g:parseInt(color.charAt(2)+color.charAt(2),16),b:parseInt(color.charAt(3)+color.charAt(3),16)};}
if(color.length===7){return{r:parseInt(color.slice(1,3),16),g:parseInt(color.slice(3,5),16),b:parseInt(color.slice(5,7),16)};}}
match=color.match(/rgba?\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);if(match){return{r:Number(match[1]),g:Number(match[2]),b:Number(match[3])};}
return null;}
function relativeLuminance(rgb){function channel(value){var normalized=value/255;if(normalized<=0.03928)
return normalized/12.92;return Math.pow((normalized+0.055)/1.055,2.4);}
return(0.2126*channel(rgb.r))+(0.7152*channel(rgb.g))+(0.0722*channel(rgb.b));}
function syncColorScheme(){var styles=getComputedStyle(page);var color=parseColor(styles.getPropertyValue('--background-color-high')||styles.backgroundColor||getComputedStyle(document.body).backgroundColor);var scheme='light';if(color&&relativeLuminance(color)<0.32)
scheme='dark';page.setAttribute('data-color-scheme',scheme);}
function appendText(node,text){node.appendChild(document.createTextNode(text));}
function createKvRow(row){var rowNode=document.createElement('div');var labelNode=document.createElement('div');var valueNode=document.createElement('div');rowNode.className='modemdash-kv-row';labelNode.className='modemdash-kv-label';valueNode.className='modemdash-kv-value';labelNode.textContent=row.label;valueNode.appendChild(createValueNode(row.value,row));rowNode.appendChild(labelNode);rowNode.appendChild(valueNode);return rowNode;}
function createEmptyNode(text){var empty=document.createElement('div');empty.className='modemdash-empty';empty.textContent=text||'暂无数据';return empty;}
function createValueNode(value,options){var text=textValue(value);var wrapper=document.createElement('span');var list;var badge;if(options&&options.badge&&text!=='N/A'){if(Array.isArray(value)){list=value.filter(function(item){return item&&hasValue(item.text);});if(!list.length){wrapper.className='modemdash-value-na';wrapper.textContent='N/A';return wrapper;}
wrapper.className='modemdash-status-stack';list.forEach(function(item){var badge=document.createElement('span');badge.className='modemdash-status '+(item.tone||statusClass(item.text));badge.textContent=String(item.text);wrapper.appendChild(badge);});return wrapper;}
wrapper.className='modemdash-status-stack';badge=document.createElement('span');badge.className='modemdash-status '+statusClass(text);badge.textContent=text;wrapper.appendChild(badge);return wrapper;}
if(options&&options.sensitive&&text!=='N/A'){wrapper.className='modemdash-sensitive-value'+(sensitiveHidden?' is-hidden':'');wrapper.textContent=text;return wrapper;}
if(text==='N/A')
wrapper.className='modemdash-value-na';wrapper.textContent=text;return wrapper;}
function statusClass(value){var text=String(value||'').trim();if(!text||text==='N/A'||text==='未知')
return'muted';if(text==='SIM正常'||text==='已连接'||text==='已注册'||text==='在线'||text==='成功'||/^已连接\s+\d+CA$/.test(text)||/^\d+CA$/.test(text))
return'good';if(text==='已注册(漫游中)'||text==='空闲'||text==='警告'||text==='漫游中')
return'warn';if(text==='离线'||text==='未连接'||text==='未注册'||text==='SIM异常'||text==='无SIM'||text==='PIN锁定'||text==='PUK锁定')
return'bad';if(/失败|异常/.test(text))
return'bad';return'muted';}
function freshnessLabel(value){if(value==='live')
return'实时状态';if(value==='cache')
return'最后一次上报数据';return'';}
function temperatureClass(value){var numeric=parseTemperature(value);if(numeric==null||numeric<60)
return'good';if(numeric<75)
return'warn';return'bad';}
function signalGrade(metric,value){var numeric=Number(value);if(isNaN(numeric))
return{label:'N/A',className:'muted'};if(metric==='RSSI'){if(numeric>=-75)return{label:'优',className:'good'};if(numeric>=-85)return{label:'良',className:'good'};if(numeric>=-95)return{label:'中',className:'warn'};return{label:'差',className:'bad'};}
if(metric==='RSRP'){if(numeric>=-80)return{label:'优',className:'good'};if(numeric>=-90)return{label:'良',className:'good'};if(numeric>=-100)return{label:'中',className:'warn'};return{label:'差',className:'bad'};}
if(metric==='RSRQ'){if(numeric>=-10)return{label:'优',className:'good'};if(numeric>=-13)return{label:'良',className:'good'};if(numeric>=-16)return{label:'中',className:'warn'};return{label:'差',className:'bad'};}
if(metric==='SINR'){if(numeric>=20)return{label:'优',className:'good'};if(numeric>=13)return{label:'良',className:'good'};if(numeric>=5)return{label:'中',className:'warn'};return{label:'差',className:'bad'};}
return{label:'N/A',className:'muted'};}
function appendKvRows(root,rows,options){var visibleRows;clearNode(root);visibleRows=(rows||[]).filter(function(row){return row&&hasValue(row.value);});if(!visibleRows.length){if(!(options&&options.empty===false))
root.appendChild(createEmptyNode('暂无数据'));return 0;}
visibleRows.forEach(function(row){root.appendChild(createKvRow(row));});return visibleRows.length;}
function refreshLayoutState(){var statusVisible=isVisible(connectionCard)||isVisible(signalCard);var carrierVisible=isVisible(carrierCard)||isVisible(caCard);setVisible(statusRow,statusVisible);statusRow.classList.toggle('is-single',!(isVisible(connectionCard)&&isVisible(signalCard)));setVisible(carrierRow,carrierVisible);carrierRow.classList.toggle('is-single',!(isVisible(carrierCard)&&isVisible(caCard)));}
function showNotice(text,type){if(!noticeBar)
return;if(!text){noticeBar.className='modemdash-notice';noticeBar.textContent='';setVisible(noticeBar,false);return;}
noticeBar.className='modemdash-notice'+(type?' '+type:'');noticeBar.textContent=text;setVisible(noticeBar,true);}
function renderMeta(meta){latestMeta=meta||{};if(!meta||meta.available===undefined){showNotice('');return;}
if(meta.available===false){showNotice(meta.error||'模组数据不可用',meta.flight_mode?'flight':'error');return;}
if(meta.error){showNotice(meta.error,'warn');return;}
showNotice('');}
function updateRefreshLoop(paused){if(paused){if(refreshTimer!=null){window.clearInterval(refreshTimer);refreshTimer=null;}
if(refreshBadge)
refreshBadge.textContent='飞行模式中 · 已暂停自动刷新';return;}
if(refreshTimer==null)
refreshTimer=window.setInterval(loadData,5000);}
function renderSummary(data){clearNode(summaryRoot);var items=[{label:'模组型号',value:data.device&&data.device.model,sensitive:true},{label:'运营商',value:data.registration&&data.registration.operator},{label:'网络类型',value:data.registration&&data.registration.network_type},{label:'SIM 状态',value:data.registration&&data.registration.sim_status,badge:true},{label:'连接状态',value:connectionStatusBadges(data),badge:true},{label:'当前频段',value:data.carrier&&data.carrier.band},{label:'PCI',value:data.carrier&&data.carrier.pci}].filter(function(item){return hasValue(item.value);});if(!items.length){setVisible(summaryRoot,false);return;}
setVisible(summaryRoot,true);items.forEach(function(item){var itemNode=document.createElement('div');var labelNode=document.createElement('span');var valueNode=document.createElement('div');itemNode.className='modemdash-summary-item';labelNode.className='modemdash-summary-label';valueNode.className='modemdash-summary-value';labelNode.textContent=item.label;valueNode.appendChild(createValueNode(item.value,item));itemNode.appendChild(labelNode);itemNode.appendChild(valueNode);summaryRoot.appendChild(itemNode);});}
function renderSignal(data){clearNode(signalRoot);clearNode(signalDiagnosisRoot);var metrics=[{label:'RSSI',value:data.rssi,suffix:' dBm',min:-110,max:-65},{label:'RSRP',value:data.rsrp,suffix:' dBm',min:-120,max:-80},{label:'RSRQ',value:data.rsrq,suffix:' dB',min:-20,max:-5},{label:'SINR',value:data.sinr,suffix:' dB',min:0,max:25}];metrics.forEach(function(metric){var numericValue=parseMetricNumber(metric.value);var hasMetricValue=numericValue!==null;var grade=hasMetricValue?signalGrade(metric.label,numericValue):{label:'N/A',className:'muted'};var item=document.createElement('div');var label=document.createElement('div');var bar=document.createElement('div');var fill=document.createElement('div');var value=document.createElement('span');var targetPercent=hasMetricValue?metricPercent(numericValue,metric.min,metric.max):100;var previousPercent=previousSignalPercents[metric.label];var freshness=data.freshness&&data.freshness[metric.label.toLowerCase()];item.className='modemdash-signal-item';label.className='modemdash-signal-label';bar.className='modemdash-signal-bar';fill.className='modemdash-signal-bar-fill '+grade.className;value.className='modemdash-signal-bar-text';appendText(label,metric.label);if(freshness){var dot=document.createElement('span');dot.className='modemdash-freshness-dot '+freshness;dot.title=freshnessLabel(freshness);label.appendChild(dot);}
if(typeof previousPercent!=='number')
previousPercent=targetPercent;fill.style.width=previousPercent+'%';value.textContent=hasMetricValue?(textValue(metric.value)+metric.suffix):'N/A';bar.appendChild(fill);bar.appendChild(value);item.appendChild(label);item.appendChild(bar);signalRoot.appendChild(item);previousSignalPercents[metric.label]=targetPercent;window.requestAnimationFrame(function(){fill.style.width=targetPercent+'%';});});[{label:'覆盖',source:parseMetricNumber(data.rsrp)!==null?signalGrade('RSRP',parseMetricNumber(data.rsrp)):{label:'N/A',className:'muted'}},{label:'干扰',source:parseMetricNumber(data.rsrq)!==null?signalGrade('RSRQ',parseMetricNumber(data.rsrq)):{label:'N/A',className:'muted'}},{label:'速率条件',source:parseMetricNumber(data.sinr)!==null?signalGrade('SINR',parseMetricNumber(data.sinr)):{label:'N/A',className:'muted'}}].forEach(function(item){var row=document.createElement('div');var label=document.createElement('span');var tone=document.createElement('span');row.className='modemdash-diagnosis-row';label.textContent=item.label;tone.className='modemdash-tone '+item.source.className;tone.textContent=item.source.label;row.appendChild(label);row.appendChild(tone);signalDiagnosisRoot.appendChild(row);});setVisible(signalDiagnosisPanel,true);signalShell.classList.remove('is-compact');setVisible(signalCard,true);return true;}
function renderCarrier(data){clearNode(carrierRoot);var items=[{label:'载波类型',value:data.carrier_type,freshness:data.freshness&&data.freshness.carrier_type},{label:'频段',value:data.band,freshness:data.freshness&&data.freshness.band},{label:'PCI',value:data.pci,freshness:data.freshness&&data.freshness.pci},{label:'频点编号',value:data.frequency,freshness:data.freshness&&data.freshness.frequency},{label:'下行 BWP',value:data.dl_bwp,freshness:data.freshness&&data.freshness.dl_bwp},{label:'上行 BWP',value:data.ul_bwp,freshness:data.freshness&&data.freshness.ul_bwp},{label:'下行 MIMO',value:data.dl_mimo,freshness:data.freshness&&data.freshness.dl_mimo},{label:'上行 MIMO',value:data.ul_mimo,freshness:data.freshness&&data.freshness.ul_mimo},{label:'下行 BLER',value:data.dl_bler,freshness:data.freshness&&data.freshness.dl_bler},{label:'上行 BLER',value:data.ul_bler,freshness:data.freshness&&data.freshness.ul_bler}].filter(function(item){return hasValue(item.value);});if(!items.length){setVisible(carrierCard,false);return false;}
items.forEach(function(item){var entry=document.createElement('div');var dt=document.createElement('dt');var dd=document.createElement('dd');entry.className='modemdash-def-item';appendText(dt,item.label);dd.textContent=textValue(item.value);if(item.freshness){var dot=document.createElement('span');dot.className='modemdash-freshness-dot '+item.freshness;dot.title=freshnessLabel(item.freshness);dt.appendChild(dot);}
entry.appendChild(dt);entry.appendChild(dd);carrierRoot.appendChild(entry);});setVisible(carrierCard,true);return true;}
function renderTemperatureGrid(data){clearNode(platformTemperatureRoot);var items=[{label:'CPU',value:data.cpu},{label:'连接组合芯片',value:data.connsys},{label:'数字信号处理传感器',value:data.dsp},{label:'5G PA',value:data.nr_pa},{label:'4G PA',value:data.lte_pa},{label:'RF',value:data.rf},{label:'电源管理芯片',value:data.pmic}].filter(function(item){return hasValue(item.value);});if(!items.length){setVisible(hardwareSection,false);setVisible(temperatureCard,false);return false;}
items.forEach(function(item){var node=document.createElement('div');var label=document.createElement('span');var value=document.createElement('span');node.className='modemdash-temperature-item '+temperatureClass(item.value);label.className='modemdash-summary-label modemdash-temperature-label';value.className='modemdash-summary-value';label.textContent=item.label;label.title=item.label;value.textContent=textValue(item.value);node.appendChild(label);node.appendChild(value);platformTemperatureRoot.appendChild(node);});setVisible(temperatureCard,true);setVisible(hardwareSection,true);return true;}
function sortCells(rows){var list=Array.isArray(rows)?rows.slice():[];return list.sort(function(a,b){function rank(row){if(row.current==='主载波')
return 0;if(row.current==='辅载波')
return 1;return 2;}
return rank(a)-rank(b);});}
function imeiOptionsList(manager){var options=manager&&manager.options;var values;if(Array.isArray(options))
return options;if(!options||typeof options!=='object')
return[];values=Object.keys(options).sort(function(a,b){return Number(a)-Number(b);}).map(function(key){return options[key];});return values.filter(function(option){return option&&typeof option==='object';});}
function renderConnection(data){var rows=[{label:'基带版本',value:data.device&&data.device.baseband,sensitive:true},{label:'基带构建时间',value:data.device&&data.device.baseband_time},{label:'IMEI',value:data.device&&data.device.imei,sensitive:true},{label:'IMSI',value:data.device&&data.device.imsi,sensitive:true}];var connectionCount;var feedback=arguments[1];var manager=(data&&data.imei_manager)||{};var options=imeiOptionsList(manager);var selectRow;var selectLabel;var selectValue;var managerWrap;var inputGrid;var imeiField;var nameField;var saveButton;var deleteButton;var applyButton;var focusState=captureImeiFocusState();var selectedImei;clearNode(connectionRoot);selectedImei=imeiUiState.selectedImei||manager.selected_imei||manager.current_imei||'';currentImeiManager={selected_imei:selectedImei,options:options};connectionCount=rows.filter(function(row){return row&&hasValue(row.value);}).length;rows.forEach(function(row){if(hasValue(row.value))
connectionRoot.appendChild(createKvRow(row));});if(!connectionCount&&!latestMeta.flight_mode)
connectionRoot.appendChild(createEmptyNode('暂无基带信息'));selectRow=document.createElement('div');selectLabel=document.createElement('div');selectValue=document.createElement('div');managerWrap=document.createElement('div');inputGrid=document.createElement('div');imeiField=document.createElement('div');nameField=document.createElement('div');imeiSelect=document.createElement('select');imeiInput=document.createElement('input');imeiNameInput=document.createElement('input');saveButton=document.createElement('button');deleteButton=document.createElement('button');applyButton=document.createElement('button');imeiMessageNode=document.createElement('div');selectRow.className='modemdash-kv-row modemdash-imei-select-row';selectLabel.className='modemdash-kv-label';selectValue.className='modemdash-kv-value';selectLabel.textContent='常用 IMEI';imeiSelect.className='cbi-input-text modemdash-input modemdash-imei-select';options.forEach(function(option){var node=document.createElement('option');node.value=option.imei||'';node.textContent=option.label||((option.name||'已保存')+'-'+(option.imei||''));node.selected=(option.imei||'')===selectedImei;imeiSelect.appendChild(node);});if(!imeiSelect.value&&imeiSelect.options.length){imeiSelect.value=selectedImei||imeiSelect.options[0].value;currentImeiManager.selected_imei=imeiSelect.value;imeiUiState.selectedImei=imeiSelect.value;}
selectValue.appendChild(imeiSelect);selectRow.appendChild(selectLabel);selectRow.appendChild(selectValue);connectionRoot.appendChild(selectRow);managerWrap.className='modemdash-imei-manager';inputGrid.className='modemdash-imei-grid';imeiField.className='modemdash-field';nameField.className='modemdash-field';imeiInput.className='cbi-input-text modemdash-input';imeiInput.type='text';imeiInput.inputMode='numeric';imeiInput.placeholder='请输入常用IMEI';imeiInput.maxLength=15;imeiNameInput.className='cbi-input-text modemdash-input';imeiNameInput.type='text';imeiNameInput.placeholder='请输入保存名字';imeiInput.value=imeiUiState.draftImei||'';imeiNameInput.value=imeiUiState.draftName||'';imeiField.appendChild(imeiInput);nameField.appendChild(imeiNameInput);inputGrid.appendChild(imeiField);inputGrid.appendChild(nameField);saveButton.className='cbi-button modemdash-imei-button';saveButton.type='button';saveButton.textContent='保存';imeiSaveButton=saveButton;deleteButton.className='cbi-button modemdash-imei-button modemdash-imei-delete';deleteButton.type='button';deleteButton.textContent='删除';imeiDeleteButton=deleteButton;applyButton.className='cbi-button cbi-button-action important modemdash-imei-button modemdash-imei-apply';applyButton.type='button';applyButton.textContent='保存并应用';imeiApplyButton=applyButton;imeiMessageNode.className='modemdash-message modemdash-imei-message';managerWrap.appendChild(inputGrid);managerWrap.appendChild(saveButton);managerWrap.appendChild(deleteButton);managerWrap.appendChild(applyButton);managerWrap.appendChild(imeiMessageNode);connectionRoot.appendChild(managerWrap);imeiInput.addEventListener('input',function(){imeiInput.value=sanitizeImeiValue(imeiInput.value);imeiUiState.draftImei=imeiInput.value;imeiUiState.dirtyImei=imeiInput.value!=='';});imeiNameInput.addEventListener('input',function(){imeiNameInput.value=sanitizeProfileNameValue(imeiNameInput.value);imeiUiState.draftName=imeiNameInput.value;imeiUiState.dirtyName=imeiNameInput.value!=='';});saveButton.addEventListener('click',saveImeiProfile);deleteButton.addEventListener('click',deleteSelectedImei);applyButton.addEventListener('click',applySelectedImei);imeiSelect.addEventListener('change',function(){currentImeiManager.selected_imei=imeiSelect.value;imeiUiState.selectedImei=imeiSelect.value;updateImeiActionState();});updateImeiActionState();restoreImeiFocusState(focusState);if(feedback&&feedback.text)
showImeiMessage(feedback.text,feedback.type);setVisible(connectionCard,true);}
function showImeiMessage(text,type){if(!imeiMessageNode)
return;imeiMessageNode.textContent=text||'';imeiMessageNode.className='modemdash-message modemdash-imei-message'+(type?' '+type:'');}
function selectedImeiOption(){var selected=imeiSelect?String(imeiSelect.value||'').trim():'';return imeiOptionsList(currentImeiManager).filter(function(option){return(option.imei||'')===selected;})[0]||null;}
function updateImeiActionState(){var selected=selectedImeiOption();if(imeiDeleteButton)
imeiDeleteButton.disabled=!selected;}
function resetApplyImeiButton(){if(!imeiApplyButton)
return;imeiApplyButton.textContent='保存并应用';imeiApplyButton.classList.remove('is-fail');imeiApplyButton.disabled=false;}
function markApplyImeiFailure(){if(!imeiApplyButton)
return;if(imeiApplyResetTimer)
window.clearTimeout(imeiApplyResetTimer);imeiApplyButton.textContent='修改失败！';imeiApplyButton.classList.add('is-fail');imeiApplyButton.disabled=false;imeiApplyResetTimer=window.setTimeout(function(){resetApplyImeiButton();imeiApplyResetTimer=null;},2000);}
function saveImeiProfile(){var imeiValue=imeiInput?imeiInput.value.trim():'';var nameValue=imeiNameInput?imeiNameInput.value.trim():'';var imeiError=validateImei(imeiValue);var nameError=validateProfileName(nameValue);if(imeiError){showImeiMessage(imeiError,'error');return;}
if(nameError){showImeiMessage(nameError,'error');return;}
if(imeiSaveButton)
imeiSaveButton.disabled=true;showImeiMessage('正在保存...','');requestForm(state.save_imei_url,{imei:imeiValue,name:nameValue}).then(function(response){if(!response.ok)
throw new Error(response.error||'保存失败');if(!lastDashboardData)
lastDashboardData={};imeiUiState.draftImei='';imeiUiState.draftName='';imeiUiState.dirtyImei=false;imeiUiState.dirtyName=false;imeiUiState.selectedImei=(response.manager&&response.manager.selected_imei)||imeiValue;lastDashboardData.imei_manager=response.manager||{};renderConnection(lastDashboardData,{text:response.message||'保存成功',type:'success'});}).catch(function(err){showImeiMessage(err&&err.message?err.message:String(err),'error');}).finally(function(){if(imeiSaveButton)
imeiSaveButton.disabled=false;});}
function deleteSelectedImei(){var selected=selectedImeiOption();if(!selected||!selected.imei){showImeiMessage('请先选择一个IMEI','error');return;}
if(imeiDeleteButton)
imeiDeleteButton.disabled=true;showImeiMessage('正在删除...','');requestForm(state.delete_imei_url,{imei:selected.imei}).then(function(response){if(!response.ok)
throw new Error(response.error||'删除失败');if(!lastDashboardData)
lastDashboardData={};imeiUiState.selectedImei=(response.manager&&response.manager.selected_imei)||'';lastDashboardData.imei_manager=response.manager||{};renderConnection(lastDashboardData,{text:response.message||'删除成功',type:'success'});}).catch(function(err){showImeiMessage(err&&err.message?err.message:String(err),'error');}).finally(function(){if(imeiDeleteButton)
imeiDeleteButton.disabled=false;});}
function applySelectedImei(){var imeiValue=imeiSelect?String(imeiSelect.value||'').trim():'';var imeiError=validateImei(imeiValue);if(!imeiValue){showImeiMessage('请先选择或保存一个IMEI','error');return;}
if(imeiError){showImeiMessage(imeiError,'error');return;}
if(imeiApplyResetTimer){window.clearTimeout(imeiApplyResetTimer);imeiApplyResetTimer=null;}
if(imeiApplyButton){imeiApplyButton.disabled=true;imeiApplyButton.textContent='应用中...';imeiApplyButton.classList.remove('is-fail');}
showImeiMessage('正在写入IMEI...','');requestForm(state.apply_imei_url,{imei:imeiValue}).then(function(response){if(!response.ok)
throw new Error(response.error||'IMEI修改失败');resetApplyImeiButton();showImeiMessage('IMEI写入成功','success');window.alert('IMEI已修改成功，下次启动生效的IMEI为：'+imeiValue+'，请重启设备生效，设备更新/复位后修改的IMEI会失效，请提前移除SIM卡');}).catch(function(){showImeiMessage('IMEI修改失败','error');markApplyImeiFailure();});}
function createMiniStat(label,value,extraClass){var stat=document.createElement('div');var labelNode=document.createElement('span');var valueNode=document.createElement('span');stat.className='modemdash-mini-stat'+(extraClass?' '+extraClass:'');labelNode.className='modemdash-mini-label';valueNode.className='modemdash-mini-value';labelNode.textContent=label;valueNode.textContent=textValue(value);stat.appendChild(labelNode);stat.appendChild(valueNode);return stat;}
function createCellCard(titleText,stats,extraClass){var card=document.createElement('div');var title=document.createElement('h4');var grid=document.createElement('div');card.className='modemdash-current-cell'+(extraClass?' '+extraClass:'');title.textContent=titleText;grid.className='modemdash-mini-grid';card.appendChild(title);(stats||[]).forEach(function(item){grid.appendChild(createMiniStat(item.label,item.value,item.extraClass||'soft'));});card.appendChild(grid);return card;}
function renderCells(rows,carrierData){clearNode(currentCellRoot);clearNode(neighborListRoot);var orderedRows=sortCells(rows);var primary=null;var primaryIndex=-1;var secondaryRows;var neighborRows;orderedRows.some(function(row,index){if(row.current==='主载波'){primary=row;primaryIndex=index;return true;}
return false;});if(!primary&&orderedRows.length){primary=orderedRows[0];primaryIndex=0;}
secondaryRows=orderedRows.filter(function(row,index){return index!==primaryIndex&&row.current==='辅载波';});neighborRows=orderedRows.filter(function(row,index){return index!==primaryIndex&&row.current!=='辅载波';});if(primary){currentCellRoot.appendChild(createCellCard('当前主小区',[{label:'PCI',value:primary.pci},{label:'频点编号',value:primary.frequency},{label:'频段',value:carrierData&&carrierData.band}].filter(function(item){return hasValue(item.value);})));}
if(secondaryRows.length){currentCellRoot.appendChild(createCellCard('辅载波',secondaryRows.map(function(row,index){return{label:secondaryRows.length>1?('载波 '+(index+1)):'当前载波',value:'PCI '+textValue(row.pci)+' / 频点 '+textValue(row.frequency),extraClass:'secondary-soft'};}),'secondary-carrier'));}
setVisible(currentCellSection,!!primary||secondaryRows.length>0);setVisible(neighborSection,neighborRows.length>0);if(!primary&&!secondaryRows.length&&!neighborRows.length){setVisible(cellsCard,false);setVisible(secondarySection,false);return false;}
neighborRows.forEach(function(row){var item=document.createElement('div');var main=document.createElement('div');var title=document.createElement('div');var badge=document.createElement('span');item.className='modemdash-neighbor-row neighbor-state';main.className='modemdash-neighbor-main';title.className='modemdash-neighbor-title';badge.className='modemdash-status muted';title.textContent='PCI '+textValue(row.pci)+' / 频点 '+textValue(row.frequency);badge.textContent='邻区';main.appendChild(title);item.appendChild(main);item.appendChild(badge);neighborListRoot.appendChild(item);});setVisible(cellsCard,true);setVisible(secondarySection,true);return true;}
function registrationCaStatus(data){var value=data&&data.registration&&data.registration.ca_status;return hasValue(value)?String(value).trim():'';}
function caCountFromStatus(value){var text=String(value||'').trim();var match;if(!text)
return 0;match=text.match(/^(\d+)CA$/);if(match)
return Number(match[1])||0;if(text.indexOf('+')!==-1)
return text.split('+').filter(function(item){return String(item||'').trim()!=='';}).length;return 0;}
function displayConnectionStatus(data){var connection=data&&data.registration&&data.registration.connection_status;var caStatus=registrationCaStatus(data);var caCount=caCountFromStatus(caStatus);if(!hasValue(connection)||connection==='空闲')
return'未连接';if(connection==='已连接'&&caCount>=2)
return'已连接 '+caCount+'CA';return connection;}
function connectionStatusBadges(data){var text=displayConnectionStatus(data);var match=String(text||'').match(/^(已连接)\s+(\d+CA)$/);if(match){return[{text:match[1],tone:'good'},{text:match[2],tone:'info'}];}
return[{text:text,tone:statusClass(text)}];}
function renderCaCard(data){var visible=!!(data&&data.visible);setVisible(caCard,visible);if(!visible){showCaMessage('','');return false;}
clearNode(caCurrentRoot);caCurrentRoot.appendChild(createMiniStat('下行 CA 上限',data.dl_max_cc,'soft'));caCurrentRoot.appendChild(createMiniStat('上行 CA 上限',data.ul_max_cc,'soft'));if(caDlInput)
caDlInput.placeholder=data.dl_max_cc?('当前值：'+data.dl_max_cc):'例如：4';if(caUlInput)
caUlInput.placeholder=data.ul_max_cc?('当前值：'+data.ul_max_cc):'例如：2';return true;}
function encodeForm(data){var pairs=[];Object.keys(data||{}).forEach(function(key){pairs.push(encodeURIComponent(key)+'='+encodeURIComponent(data[key]==null?'':data[key]));});return pairs.join('&');}
function requestForm(url,data){return fetch(url,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},credentials:'same-origin',body:encodeForm(data)}).then(function(response){if(!response.ok)
throw new Error('HTTP '+response.status);return response.json();});}
function setFlightActionBusy(busy){if(enableFlightButton)
enableFlightButton.disabled=busy;if(disableFlightButton)
disableFlightButton.disabled=busy;}
function showCaMessage(text,type){if(!caMessage)
return;caMessage.textContent=text||'';caMessage.className='modemdash-message'+(type?' '+type:'');}
function sanitizeNumericInput(node){if(!node)
return;node.addEventListener('input',function(){node.value=node.value.replace(/\D+/g,'');});}
function applyCaSettings(){var dlValue=caDlInput?caDlInput.value.trim():'';var ulValue=caUlInput?caUlInput.value.trim():'';if(!dlValue&&!ulValue){showCaMessage('请至少填写一个 CA 载波数','error');return;}
if(dlValue&&!/^\d+$/.test(dlValue)){showCaMessage('下行 CA 载波数只能输入数字','error');return;}
if(ulValue&&!/^\d+$/.test(ulValue)){showCaMessage('上行 CA 载波数只能输入数字','error');return;}
if(caApplyButton)
caApplyButton.disabled=true;showCaMessage('正在写入配置...','');requestForm(state.apply_url,{dl_ccs:dlValue,ul_ccs:ulValue}).then(function(response){if(!response.ok){showCaMessage(response.error||'写入失败','error');return;}
showCaMessage('配置已提交，正在刷新当前状态...','success');if(caDlInput)
caDlInput.value='';if(caUlInput)
caUlInput.value='';return loadData();}).catch(function(err){showCaMessage(String(err),'error');}).finally(function(){if(caApplyButton)
caApplyButton.disabled=false;});}
function setFlightMode(mode){var enable=mode==='4';setFlightActionBusy(true);showNotice(enable?'正在开启飞行模式...':'正在关闭飞行模式...','warn');requestForm(state.cfun_url,{mode:mode}).then(function(response){if(!response.ok)
throw new Error(response.error||'飞行模式切换失败');return loadData();}).catch(function(err){showNotice(err&&err.message?err.message:String(err),'error');}).finally(function(){setFlightActionBusy(false);});}
function updateSensitiveToggle(){if(!sensitiveToggle||!sensitiveIcon)
return;var label=sensitiveHidden?'显示敏感信息':'隐藏敏感信息';sensitiveToggle.setAttribute('aria-label',label);sensitiveToggle.setAttribute('title',label);sensitiveIcon.src=sensitiveHidden?icons.show:icons.hide;}
function render(data){renderMeta(data.meta||{});if(latestMeta.flight_mode){updateRefreshLoop(true);syncColorScheme();return;}
updateRefreshLoop(false);lastDashboardData=data||{};renderSummary(data||{});renderConnection(data||{},null);renderSignal(data.signal||{});renderCarrier(data.carrier||{});renderCaCard(data.ca_config||{});renderCells(Array.isArray(data.cells)?data.cells:[],data.carrier||{});renderTemperatureGrid(data.platform_temperature||{});refreshLayoutState();syncColorScheme();if(refreshBadge){var now=new Date();refreshBadge.textContent='每 5 秒自动刷新 · '+
now.getHours().toString().padStart(2,'0')+':'+
now.getMinutes().toString().padStart(2,'0')+':'+
now.getSeconds().toString().padStart(2,'0');}}
function loadData(){return fetch(state.data_url,{cache:'no-store',credentials:'same-origin'}).then(function(response){if(!response.ok)
throw new Error('HTTP '+response.status);return response.json();}).then(render).catch(function(err){if(refreshBadge)
refreshBadge.textContent='数据刷新失败';showNotice('模组数据刷新失败：'+err.message,'error');console.error('modem-dashboard refresh failed:',err);});}
syncColorScheme();sanitizeNumericInput(caDlInput);sanitizeNumericInput(caUlInput);updateSensitiveToggle();if(caApplyButton)
caApplyButton.addEventListener('click',applyCaSettings);if(enableFlightButton)
enableFlightButton.addEventListener('click',function(){setFlightMode('4');});if(disableFlightButton)
disableFlightButton.addEventListener('click',function(){setFlightMode('1');});if(refreshNowButton)
refreshNowButton.addEventListener('click',loadData);if(sensitiveToggle){sensitiveToggle.addEventListener('click',function(){sensitiveHidden=!sensitiveHidden;window.localStorage.setItem('modem_dashboard_sensitive_hidden',sensitiveHidden?'1':'0');updateSensitiveToggle();loadData();});}
if(window.matchMedia){var media=window.matchMedia('(prefers-color-scheme: dark)');if(media.addEventListener)
media.addEventListener('change',syncColorScheme);else if(media.addListener)
media.addListener(syncColorScheme);}
if(window.MutationObserver){new MutationObserver(syncColorScheme).observe(document.documentElement,{attributes:true,attributeFilter:['class','data-theme','style']});}
loadData();updateRefreshLoop(false);})();
