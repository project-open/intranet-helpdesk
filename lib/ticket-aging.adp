<div id=@diagram_id@></div>
<script type='text/javascript'>
Ext.Loader.setPath('PO', '/sencha-core');
Ext.require([
    'Ext.chart.*', 
    'Ext.Window', 
    'Ext.fx.target.Sprite', 
    'Ext.layout.container.Fit',
    'PO.controller.StoreLoadCoordinator'
]);



function launchDiagram@diagram_id@(debug) {
    
    var ticketAgingStore = Ext.StoreManager.get('ticketAgingStore');

    // Define the colors for the diagram
    var colors = ['#ff0000', '#b4003f','#7e007b','#4702b7', '#0f00f1'];		// '#5800a2','#3300cb'
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
        shadow: false,
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
            },
            listeners: {
                itemclick: function(item,e) {
                    console.log('ticket-aging: itemclick on:');
                    console.log(item);

                    var ticketAge = Number(item.value[0]);
                    var ticketDate = new Date(new Date().getTime() - ticketAge * 1000 * 3600 * 24);
                    var ticketStartDate = ticketDate.toISOString().substring(0,10);
                    var ticketEndDate = new Date(ticketDate.getTime() + 1000 * 3600 * 24).toISOString().substring(0,10);
                    var url = "/intranet-helpdesk/index?";
                    url = url + "mine_p=all";
                    url = url + "&start_date="+ticketStartDate;
                    url = url + "&end_date="+ticketEndDate;
                    url = url + "&ticket_status_id=30000";
                    if ("" != "@ticket_customer_contact_id@" && 0 != parseInt("@ticket_customer_contact_id@")) {
                        url = url + "&ticket_customer_contact_id=@ticket_customer_contact_id@";
                    }
                    if ("" != "@ticket_customer_contact_dept_code@") {
                        url = url + "&customer_contact_dept_code=@ticket_customer_contact_dept_code@";
                    }
                    if ("" != "@ticket_assignee_dept_code@") {
                        url = url + "&assignee_dept_code=@ticket_assignee_dept_code@";
                    }
                    window.open(url);
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
};


Ext.onReady(function () {
    Ext.QuickTips.init();							// No idea why this is necessary, but it is...
    // Ext.getDoc().on('contextmenu', function(ev) { ev.preventDefault(); });	// Disable Right-click context menu on browser background
    var debug = true;

    var ticketAgingStore = Ext.create('Ext.data.Store', {
	storeId: 'ticketAgingStore',
        fields: ['age', 'prio1', 'prio2', 'prio3', 'prio4'],
        autoLoad: false,							// Force to use the StoreLoadCoordinator
        proxy: {
            type: 'rest',
            url: '/intranet-reporting/view',					// This is the generic ]po[ REST interface
            extraParams: {
                format: 'json',							// Ask for data in JSON format
                limit: @diagram_limit@,						// Limit the number of returned rows
                report_code: '@diagram_report_code;noquote@',			// The code of the data-source to retreive
                sla_id: '@ticket_sla_id;noquote@',
                customer_contact_id: '@ticket_customer_contact_id@',
                customer_dept_code: '@ticket_customer_contact_dept_code;noquote@',
                assignee_dept_code: '@ticket_assignee_dept_code;noquote@',
                type_id: '@ticket_type_id@',
                status_id: '@ticket_status_id@',
                prio_id: '@ticket_prio_id@'
            },
            reader: { type: 'json', root: 'data' }				// Standard reader: Data are prefixed by "data".
        }
    });

    // Delay loading the store for 10-110ms to allow the rest
    // of the page to be more reactive 
    var task = new Ext.util.DelayedTask(function(){ ticketAgingStore.load(); });
    task.delay(500 + 2000*Math.random());

    // Go create the diagram even thought the store isn't loaded yet.
    // The diagram will redraw once the data are there.
    launchDiagram@diagram_id@(debug);
});
</script>
