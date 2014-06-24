<div id=@diagram_id@></div>
<script type='text/javascript'>

Ext.require(['Ext.chart.*', 'Ext.Window', 'Ext.fx.target.Sprite', 'Ext.layout.container.Fit']);
Ext.onReady(function () {
    
    var ticketAgingStore = Ext.create('Ext.data.Store', {
        fields: ['age', 'prio1', 'prio2', 'prio3', 'prio4'],
	autoLoad: true,
	proxy: {
            type: 'rest',
            url: '/intranet-reporting/view',			// This is the generic ]po[ REST interface
            extraParams: {
		format: 'json',					// Ask for data in JSON format
		limit: @diagram_limit@,				// Limit the number of returned rows
		report_code: 'rest_ticket_aging_histogram'	// The code of the data-source to retreive
            },
            reader: { type: 'json', root: 'data' }		// Standard reader: Data are prefixed by "data".
	}
    });
    
    var ticketAgingChart = new Ext.chart.Chart({
	xtype: 'chart',
	animate: true,
	shador: true,
	store: ticketAgingStore,
	insetPadding: 20,
	theme: 'Blue',
        axes: [{
            type: 'Numeric',
            position: 'bottom',
            fields: ['prio1', 'prio2', 'prio3', 'prio4'],
            // title: 'Number of tickets',
            grid: false,
            minimum: 0
        }, {
            type: 'Numeric',
            position: 'left',
            fields: ['age'],
            // title: 'Age of tickets (days)',
            minimum: 0
        }],
	series: [{
	    type: 'bar',
	    axis: 'bottom',
	    xField: 'age',
	    yField: ['prio1', 'prio2', 'prio3', 'prio4'],
	    title: ['@prio1_l10n@', '@prio2_l10n@', '@prio3_l10n@', '@prio4_l10n@'],
	    stacked: true,
	    tips: {
                trackMouse: false,
                width: 200,
                height: 28,
                renderer: function(storeItem, item) {
		    var fieldName = item.series.title[item.series.yField.indexOf(item.yField)];
		    var ageDays = storeItem.get('age');
		    var daysL10n = (ageDays == 1) ? ' @day_l10n@' : ' @days_l10n@';
		    var ticketsL10n = (storeItem.get(item.yField) == 1) ? ' @ticket_l10n@' : ' @tickets_l10n@';
                    this.setTitle(fieldName + ': ' + storeItem.get(item.yField) + ticketsL10n + ' @of_l10n@ ' + ageDays + daysL10n);
                }
            }
	}],
	legend: { position: 'bottom' }
    });

    var ticketAgingPanel = Ext.create('widget.panel', {
        width: @diagram_width@,
        height: @diagram_height@,
        title: '@diagram_title@',
	renderTo: '@diagram_id@',
        layout: 'fit',
	header: false,
        items: ticketAgingChart
    });
});
</script>
