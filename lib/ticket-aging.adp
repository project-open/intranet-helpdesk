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
		report_code: '@diagram_report_code@'	// The code of the data-source to retreive
            },
            reader: { type: 'json', root: 'data' }		// Standard reader: Data are prefixed by "data".
	}
    });

    // Define the colors for the diagram
    var colors = ['#b4003f','#7e007b','#4702b7', '#0f00f1'];   // '#5800a2','#3300cb'
    var baseColor = '#eee';
    Ext.define('Ext.chart.theme.Custom', {
	extend: 'Ext.chart.theme.Base',
	constructor: function(config) {
	    this.callParent([Ext.apply({
		colors: colors
	    }, config)]);
	}
    });
    
    var ticketAgingChart = new Ext.chart.Chart({
	xtype: 'chart',
	width: @diagram_width@,
        height: @diagram_height@,
        title: '@diagram_title@',
	renderTo: '@diagram_id@',
        layout: 'fit',
	animate: true,
	shador: true,
	store: ticketAgingStore,
	insetPadding: @diagram_inset_padding@,
	theme: '@diagram_theme@',
        axes: [{
            type: 'Numeric',
            position: 'bottom',
            fields: ['prio1', 'prio2', 'prio3', 'prio4'],
	    label: { font: '@diagram_font@' },
            // title: 'Number of tickets',
            grid: false,
            minimum: 0
        }, {
            type: 'Numeric',
            position: 'left',
            fields: ['age'],
	    label: { font: '@diagram_font@' },
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
	    highlight: true,
	    tips: {
                trackMouse: false,
                width: @diagram_tooltip_width@,
                height: @diagram_tooltip_height@,
                renderer: function(storeItem, item) {
		    var fieldName = item.series.title[item.series.yField.indexOf(item.yField)];
		    var ageDays = storeItem.get('age');
		    var daysL10n = (ageDays == 1) ? ' @day_l10n@' : ' @days_l10n@';
		    var ticketsL10n = (storeItem.get(item.yField) == 1) ? ' @ticket_l10n@' : ' @tickets_l10n@';
                    this.setTitle(fieldName + ': ' + storeItem.get(item.yField) + ticketsL10n + ' @of_l10n@ ' + ageDays + daysL10n);
                }
            }
	}],
	legend: { 
		position: 'float',
		x: @diagram_width@ - @diagram_legend_width@,
		y: 0,
		labelFont: '@diagram_font@'
	}
    });

});
</script>
