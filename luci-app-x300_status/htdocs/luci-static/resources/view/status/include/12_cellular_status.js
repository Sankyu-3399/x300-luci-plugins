'use strict';
'require baseclass';
'require request';
'require rpc';

var callLuciRealtimeStats = rpc.declare({
	object: 'luci',
	method: 'getRealtimeStats',
	params: [ 'mode', 'device' ],
	expect: { result: [] }
});

function clamp(value, min, max) {
	return Math.max(min, Math.min(max, value));
}

function metricPercent(value, min, max) {
	return Math.floor(((clamp(value, min, max) - min) * 100) / (max - min));
}

function formatNumber(value, suffix) {
	if (value == null)
		return null;

	if (Math.abs(value % 1) < 0.001)
		return '%d%s'.format(value, suffix);

	return '%.1f%s'.format(value, suffix);
}

function progressbar(value, percent) {
	return E('div', {
		'style': 'position:relative;min-width:170px;width:100%;'
	}, [
		E('div', {
			'class': 'cbi-progressbar',
			'title': '',
			'style': 'margin:0;height:1.35rem;'
		}, [
			E('div', { 'style': 'width:%.2f%%'.format(percent) })
		]),
		E('span', {
			'style': 'position:absolute;inset:0;display:flex;align-items:center;justify-content:center;padding:0 .6rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:clamp(.76rem,2vw,.92rem);line-height:1.35rem;font-variant-numeric:tabular-nums;pointer-events:none;'
		}, [ value ])
	]);
}

function transferRateView(value) {
	var text = String(value || ''),
	    match = text.match(/^DL\s+(.+?)\s*\/\s*UL\s+(.+)$/),
	    dl = match ? match[1] : '0KB/s',
	    ul = match ? match[2] : '0KB/s';

	function ratePart(label, amount) {
		return E('span', {
			'style': 'display:inline-flex;align-items:center;gap:.4rem;white-space:nowrap;'
		}, [
			E('span', {
				'style': 'font-weight:600;opacity:.78;'
			}, [ label ]),
			E('span', {}, [ amount ])
		]);
	}

	return E('div', {
		'style': 'display:flex;flex-wrap:wrap;align-items:center;column-gap:1.2rem;row-gap:.2rem;font-variant-numeric:tabular-nums;line-height:1.35;'
	}, [
		ratePart('DL', dl),
		ratePart('UL', ul)
	]);
}

function formatTransferValue(bytesPerSecond) {
	var value = Math.max(0, +bytesPerSecond || 0);

	if (value < 1024)
		return '0KB/s';

	value = value / 1024;
	if (value < 1024)
		return '%dKB/s'.format(Math.round(value));

	value = value / 1024;
	if (value < 1024)
		return ('%.1fMB/s'.format(value)).replace(/\.0MB\/s$/, 'MB/s');

	value = value / 1024;
	return ('%.1fGB/s'.format(value)).replace(/\.0GB\/s$/, 'GB/s');
}

function applyRealtimeTransferRate(data, stats) {
	var rows = Array.isArray(stats) ? stats : [],
	    last = null,
	    prev = null;

	for (var i = rows.length - 1; i >= 0; i--) {
		if (Array.isArray(rows[i]) && rows[i].length >= 4) {
			if (!last)
				last = rows[i];
			else {
				prev = rows[i];
				break;
			}
		}
	}

	if (!last || !prev || last[0] <= prev[0]) {
		data.transfer_rate = 'DL 0KB/s / UL 0KB/s';
		return data;
	}

	var delta = last[0] - prev[0],
	    dl = Math.max(0, (last[1] - prev[1]) / delta),
	    ul = Math.max(0, (last[3] - prev[3]) / delta);

	data.transfer_rate = 'DL %s / UL %s'.format(
		formatTransferValue(dl),
		formatTransferValue(ul)
	);

	return data;
}

return baseclass.extend({
	title: '蜂窝状态',

	load: function() {
		return L.resolveDefault(request.get(L.url('admin/status/x300_status/cell'), {
			cache: false
		}), null).then(function(response) {
			if (!response || !response.ok)
				return {};

			return response.json();
		}).then(function(data) {
			if (!data || !data.ifname) {
				data = data || {};
				data.transfer_rate = data.transfer_rate || 'DL 0KB/s / UL 0KB/s';
				return data;
			}

			return L.resolveDefault(callLuciRealtimeStats('interface', data.ifname), []).then(function(stats) {
				return applyRealtimeTransferRate(data, stats);
			}).catch(function() {
				data.transfer_rate = data.transfer_rate || 'DL 0KB/s / UL 0KB/s';
				return data;
			});
		}).catch(function() {
			return {};
		});
	},

	render: function(data) {
		if (!data || (!data.operator && !data.network_type && !data.band && !data.pci && !data.nrarfcn && !data.center_freq && !data.ca_status && !data.transfer_rate && data.rssi == null && data.rsrp == null && data.rsrq == null && data.sinr == null))
			return null;

		var rows = [];

		if (data.operator)
			rows.push([ '运营商', data.operator ]);

		if (data.network_type)
			rows.push([ '网络注册类型', data.network_type ]);

		if (data.band)
			rows.push([ '频段', data.band ]);

		if (data.ca_status)
			rows.push([ '载波聚合', data.ca_status ]);

		if (data.transfer_rate)
			rows.push([ '传输速率', transferRateView(data.transfer_rate) ]);

		if (data.pci)
			rows.push([ 'PCI', data.pci ]);

		if (data.nrarfcn)
			rows.push([ 'NRARFCN', data.nrarfcn ]);

		if (data.rssi != null)
			rows.push([ 'RSSI', progressbar(formatNumber(data.rssi, ' dBm'), metricPercent(data.rssi, -110, -65)) ]);

		if (data.rsrp != null)
			rows.push([ 'RSRP', progressbar(formatNumber(data.rsrp, ' dBm'), metricPercent(data.rsrp, -120, -80)) ]);

		if (data.rsrq != null)
			rows.push([ 'RSRQ', progressbar(formatNumber(data.rsrq, ' dB'), metricPercent(data.rsrq, -20, -5)) ]);

		if (data.sinr != null)
			rows.push([ 'SINR', progressbar(formatNumber(data.sinr, ' dB'), metricPercent(data.sinr, 0, 25)) ]);

		var table = E('table', { 'class': 'table' });

		for (var i = 0; i < rows.length; i++) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ rows[i][0] ]),
				E('td', { 'class': 'td left' }, [ rows[i][1] ])
			]));
		}

		return table;
	}
});
