<div id=@diagram_id@></div>
<script type='text/javascript'>

Ext.Loader.setPath('PO', '/sencha-core');
Ext.Loader.setPath('GanttEditor', '/intranet-gantt-editor');
Ext.require([
    'Ext.chart.*', 
    'Ext.Window', 
    'Ext.fx.target.Sprite', 
    'Ext.layout.container.Fit'
]);



/**
 * Launch the actual editor
 * This function is called from the Store Coordinator
 * after all essential data have been loaded into the
 * browser.
 */
function launchTicketAgePerQueue(debug, ticketTypes) {

    var ticketAgeStore = Ext.StoreManager.get('ticketAgeStore');


    // Define the colors for the diagram
    var colors = ['#ff0000', '#b4003f','#7e007b','#4702b7', '#0f00f1'];   // '#5800a2','#3300cb'
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
        store: ticketAgeStore,
        insetPadding: @diagram_inset_padding@,
        theme: '@diagram_theme@',
        axes: [{
            type: 'Numeric',
            position: 'bottom',
            fields: ticketTypes,
            label: { font: '@diagram_font@' },
            // title: 'Number of tickets',
            grid: false,
            minimum: 0
        }, {
            type: 'Category',
            position: 'left',
            fields: ['queue'],
            label: { font: '@diagram_font@' },
            // title: 'Age of tickets (days)',
            minimum: 0
        }],
        series: [{
            type: 'bar',
            axis: 'bottom',
            xField: 'age',
            yField: ticketTypes,
            title: ticketTypes,
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
                    var url = "/intranet-helpdesk/index?mine_p=all&start_date="+ticketStartDate+"&end_date="+ticketEndDate+"&ticket_status_id=30000"
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




/**
 * Load Stores from server before
 * starting the actual Chart.
 */
Ext.onReady(function () {

    var debug = true;

    // "Raw" store with age, queue and ticket type from the database
    var rawStore = Ext.create('Ext.data.Store', {
        storeId: 'rawStore',
        fields: ['number', 'age', 'queue', 'type'],
        autoLoad: true,
        proxy: {
            type: 'rest',
            url: '/intranet-reporting/view',			// This is the generic ]po[ REST interface
            extraParams: {
                format: 'json',					// Ask for data in JSON format
                report_code: '@diagram_report_code;noquote@'	// The code of the data-source to retreive
            },
            reader: { type: 'json', root: 'data' }		// Standard reader: Data are prefixed by "data".
        }
    });

    // Derived stores with aggreated numbers and age per queue and ticket type
    var ticketAgeStore = Ext.create('Ext.data.ArrayStore', {storeId: 'ticketAgeStore'});
    var ticketNumberStore = Ext.create('Ext.data.ArrayStore', {storeId: 'ticketNumberStore'});

    // Reformat once the raw data are loaded
    rawStore.on('load', function(store, records, successful, eOpts) {

        if (!successful) { 
            Console.log("ticket-age-per-queue: Unable to load store 'rawStore'"+
                        "from report with code='@diagram_report_code;noquote@'.");
        }

        // Gather the list of ticket types and queues from raw data
        var queues = [];
        var ticketTypes = [];
        rawStore.each(function(record) {
            var type = record.get('type');
            if (ticketTypes.indexOf(type) < 0) ticketTypes.push(type);

            var queue = record.get('queue');
            if ("" == queue) { queue = "No Queue"; }
            if (queues.indexOf(queue) < 0) queues.push(queue);
        });

        ticketTypes.sort();
        queues.sort();

        // Aggregate the data on the level of queues and types
        var ageFields = ["queue"];
        ticketTypes.forEach(function(type) {ageFields.push(type); });

        var ageData = [];
        queues.forEach(function(queue) {
            var row = {'queue': queue};
            ticketTypes.forEach(function(type) {row[type] = 0; });
            ageData.push(row);
        });

        rawStore.each(function(record) {
            var age = record.get('age');
            var num = record.get('number');
            var queue = record.get('queue');
            if ("" == queue) { queue = "No Queue"; }
            var type = record.get('type');
            
            // Check if there is already an entry
            var queueIndex = queues.indexOf(queue);
            var queueRow = ageData[queueIndex];
            queueRow[type]++;
        });

        // Setup custom store with ticket queue fields from rawStore
        ticketAgeStore = Ext.create('Ext.data.Store', {
            storeId: 'ticketAgeStore',
          fields: ageFields,
          data: ageData
        });

        launchTicketAgePerQueue(debug, ticketTypes);
        
    });

});
</script>
