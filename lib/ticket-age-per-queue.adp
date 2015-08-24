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
function launchTicketStatsPerQueue(debug, ticketTypes) {

    var ticketNumStore = Ext.StoreManager.get('ticketNumStore');
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

    var serie = {
            type: 'bar',
            axis: 'bottom',
            yField: ticketTypes,
            title: ticketTypes,
            stacked: true,
            highlight: true
    };

    var ticketChart = new Ext.chart.Chart({
        xtype: 'chart',
        width: @diagram_width@,
        height: @diagram_height@,
        title: '@diagram_title@',
        layout: 'fit',
        animate: true,
        shador: true,
        store: ticketNumStore,
        insetPadding: @diagram_inset_padding@,
//        theme: '@diagram_theme@',
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
        series: [serie],
        legend: { 
                position: 'float',
                x: @diagram_width@ - @diagram_legend_width@,
                y: 0,
                labelFont: '@diagram_font@'
        }
    });

    var panel = Ext.create('Ext.panel.Panel', {
        renderTo: '@diagram_id@',
	items: [
	    ticketChart
	],
	dockedItems : [{
	    xtype : 'toolbar',
	    dock  : 'top',
	    items : [{
		xtype: 'combobox',
		name: 'uom_id',
		displayField: 'category',
		valueField: 'category_id',
		queryMode: 'local',
		fieldLabel: "Show:",
		hideLabel: true,
		emptyText: 'Number of Tickets',
		width: 200,
		margins: '0 6 0 0',
		store: Ext.create('Ext.data.Store', { fields: ['category_id', 'category'], data: [
                    {category_id: "num", category: 'Number of Tickets'},
                    {category_id: "age", category: 'Age of Tickets'}
		]}),
		allowBlank: false,
		forceSelection: true,
		listeners: {
		    change: function(el, newValue, oldValue) {
			var series = ticketChart.series;
			series.clear();
			switch (newValue) {
			case "num":
			    serie.stacked = true;
			    series.add(serie);
			    ticketChart.bindStore(ticketNumStore);
			    ticketChart.redraw();
			    break;
			case "age": 
			    serie.stacked = false;
			    series.add(serie);
			    ticketChart.bindStore(ticketAgeStore);
			    ticketChart.redraw();
			    break;
			default:
			    break;
			}
                    }
		}
	    }]
	}]
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
    var ticketNumStore = Ext.create('Ext.data.ArrayStore', {storeId: 'ticketNumStore'});

    var simplifyTicketType = function(str) {
	str = str.replace("Ticket", "");
	str = str.replace("Request", "");
	str = str.replace("Generic", "");
	str = str.replace("Alert", "");
	str = str.replace("  ", " ");
	return str;
    };

    var simplifyQueue = function(str) {
	str = str.replace("Admins", "");
	str = str.replace("  ", " ");
	return str;
    };

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
	    type = simplifyTicketType(type);
            if (ticketTypes.indexOf(type) < 0) ticketTypes.push(type);

            var queue = record.get('queue');
	    queue = simplifyQueue(queue);
            if ("" == queue) { queue = "No Queue"; }
            if (queues.indexOf(queue) < 0) queues.push(queue);
        });

        ticketTypes.sort();
        queues.sort();

        // Aggregate the data on the level of queues and types
        var ageFields = ["queue"];
        ticketTypes.forEach(function(type) {ageFields.push(type); });

        var ageData = [];
        var numData = [];
        queues.forEach(function(queue) {
            var row = {'queue': queue};
            ticketTypes.forEach(function(type) { row[type] = 0.0; });
            ageData.push(row);

            var row2 = {'queue': queue};
            ticketTypes.forEach(function(type) { row2[type] = 0.0; });
            numData.push(row2);
        });

        rawStore.each(function(record) {
            var age = parseFloat(record.get('age'));
            var num = parseFloat(record.get('number'));
            var queue = record.get('queue');
	    queue = simplifyQueue(queue);
            if ("" == queue) { queue = "No Queue"; }
            var queueIndex = queues.indexOf(queue);
            var type = record.get('type');
	    type = simplifyTicketType(type);
            
            // Update the Age store
            var queueRow = ageData[queueIndex];
            queueRow[type] = queueRow[type] + age;

            // Update the Num store
            var queueRow2 = numData[queueIndex];
            queueRow2[type] = queueRow2[type] + num;
        });

        // Setup custom store with ticket queue fields from rawStore
        ticketNumStore = Ext.create('Ext.data.Store', {
            storeId: 'ticketNumStore',
            fields: ageFields,
            data: numData
        });

        ticketAgeStore = Ext.create('Ext.data.Store', {
            storeId: 'ticketAgeStore',
            fields: ageFields,
            data: ageData
        });

        launchTicketStatsPerQueue(debug, ticketTypes);
        
    });

});
</script>
