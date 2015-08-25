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
function launchTicketStatsPer(debug, ticketTypes) {

    var queueNumStore = Ext.StoreManager.get('queueNumStore');
    var queueAgeStore = Ext.StoreManager.get('queueAgeStore');
    var deptNumStore = Ext.StoreManager.get('deptNumStore');
    var deptAgeStore = Ext.StoreManager.get('deptAgeStore');

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
        store: queueNumStore,
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

    var configureDiagram = function () {
        var series = ticketChart.series;
        var buttonToggleLegend = Ext.getCmp('buttonToggleLegend');
        var showLegend = buttonToggleLegend.pressed;
        var legend = ticketChart.legend;
        legend.toggle(showLegend);

        var comboNumberAge = Ext.getCmp("comboNumberAge");
        var numAge = comboNumberAge.getValue();         // "num" or "age"
        var comboQueueDept = Ext.getCmp("comboQueueDept");
        var queueDept = comboQueueDept.getValue();         // "queue" or "dept"

        var stacked = (numAge == "num");                // Numbers can be stacked (adding up), age doesn't

	// Determine the field to show at the left axis
        var axis = ticketChart.axes;
	var leftAxis = axis.get('left');
	leftAxis.fields = [queueDept];

	// Determine the store to show
        var storeName = queueDept;
        storeName = storeName + numAge.charAt(0).toUpperCase() + numAge.slice(1);
        storeName = storeName + "Store";
        var store = Ext.StoreManager.get(storeName);

        series.clear();
        serie.stacked = stacked;                  
        series.add(serie);
        ticketChart.bindStore(store);       // Store with number of tickets
        ticketChart.redraw();
    };

    var panel = Ext.create('Ext.panel.Panel', {
        renderTo: '@diagram_id@',
        items: [ticketChart],
        dockedItems : [{
            xtype : 'toolbar',
            dock  : 'top',
            items : [{
                xtype: 'combobox',
        	id: "comboNumberAge",
                tooltip: 'Show age or number of tickets?',
                displayField: 'category',
                valueField: 'category_id',
                hideLabel: true,
		value: 'num',
                width: 80,
                store: Ext.create('Ext.data.Store', { fields: ['category_id', 'category'], data: [
                    {category_id: "num", category: 'Number'},
                    {category_id: "age", category: 'Age'}
                ]}),
                allowBlank: false,
                forceSelection: true,
                listeners: {change: function(el, newValue, oldValue) { configureDiagram(); }}
            }, {
                xtype: 'combobox',
        	id: "comboQueueDept",
                tooltip: 'Show Department or Queue?',
                displayField: 'category',
                valueField: 'category_id',
                hideLabel: true,
		value: 'queue',
                width: 80,
                store: Ext.create('Ext.data.Store', { fields: ['category_id', 'category'], data: [
                    {category_id: "queue", category: 'Queue'},
                    {category_id: "dept", category: 'Dept'}
                ]}),
                allowBlank: false,
                forceSelection: true,
                listeners: {change: function(el, newValue, oldValue) { configureDiagram(); }}
            }, '->', {
                xtype: 'button',
                id: 'buttonToggleLegend',
                icon: '/intranet/images/navbar_default/layout.png',
                tooltip: 'Show or hide legend',
                pressed: true,
                enableToggle: true,
                handler: function(button) { configureDiagram(); }
            }]
        }]
    });


};




/**
 * Load Stores from server before
 * starting the actual Chart.
 */
Ext.onReady(function () {

    Ext.QuickTips.init();
    var debug = true;

    // "Raw" store with age, queue and ticket type from the database
    var rawStore = Ext.create('Ext.data.Store', {
        storeId: 'rawStore',
        fields: ['number', 'age', 'queue', 'assignee_dept', 'type'],
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
    var queueAgeStore = Ext.create('Ext.data.ArrayStore', {storeId: 'queueAgeStore'});
    var queueNumStore = Ext.create('Ext.data.ArrayStore', {storeId: 'queueNumStore'});
    var deptAgeStore = Ext.create('Ext.data.ArrayStore', {storeId: 'deptAgeStore'});
    var deptNumStore = Ext.create('Ext.data.ArrayStore', {storeId: 'deptNumStore'});

    var simplifyTicketType = function(str) {
        str = str.replace("Ticket", "");
        str = str.replace("Request", "");
        str = str.replace("Generic", "");
        str = str.replace("Alert", "");
        str = str.replace("  ", " ");
        return str.trim();
    };

    var simplifyQueue = function(str) {
        str = str.replace("Admins", "");
        str = str.replace("  ", " ");
        return str.trim();
    };

    var simplifyDept = function(str) {
        return str.trim();
    };

    // Reformat once the raw data are loaded
    rawStore.on('load', function(store, records, successful, eOpts) {

        if (!successful) { 
            Console.log("ticket-age-per-queue: Unable to load store 'rawStore'"+
                        "from report with code='@diagram_report_code;noquote@'.");
        }

        // Gather the list of ticket types and queues from raw data
        var queues = [];
        var depts = [];
        var ticketTypes = [];
        rawStore.each(function(record) {
            var type = record.get('type').trim();
            type = simplifyTicketType(type);
            var queue = record.get('queue').trim();
            queue = simplifyQueue(queue);
            var dept = record.get('assignee_dept').trim();
            dept = simplifyDept(dept);

            if (ticketTypes.indexOf(type) < 0) ticketTypes.push(type);
            if (queues.indexOf(queue) < 0) queues.push(queue);
            if (depts.indexOf(dept) < 0) depts.push(dept);
        });
        ticketTypes.sort();
        queues.sort();
        depts.sort();

        // Aggregate the data on the level of queues and types
        var queueFields = ["queue"];
        var deptFields = ["dept"];
        ticketTypes.forEach(function(type) {
            queueFields.push(type); 
            deptFields.push(type); 
        });

        var queueAgeData = [];
        var queueNumData = [];
        queues.forEach(function(queue) {
            var row = {'queue': queue};
            ticketTypes.forEach(function(type) { row[type] = 0.0; });
            queueAgeData.push(row);

            var row2 = {'queue': queue};
            ticketTypes.forEach(function(type) { row2[type] = 0.0; });
            queueNumData.push(row2);
        });

        var deptAgeData = [];
        var deptNumData = [];
        depts.forEach(function(dept) {
            var row3 = {'dept': dept};
            ticketTypes.forEach(function(type) { row3[type] = 0.0; });
            deptAgeData.push(row3);

            var row4 = {'dept': dept};
            ticketTypes.forEach(function(type) { row4[type] = 0.0; });
            deptNumData.push(row4);
        });

        // Aggregate the raw data in the specified slots
        rawStore.each(function(record) {
            var age = parseFloat(record.get('age'));
            var num = parseFloat(record.get('number'));
            var queue = record.get('queue').trim();
            queue = simplifyQueue(queue);
            var dept = record.get('assignee_dept').trim();
            dept = simplifyDept(dept);
            var type = record.get('type').trim();
            type = simplifyTicketType(type);

            var queueIndex = queues.indexOf(queue);
            var deptIndex = depts.indexOf(dept);
            
            // Update the Age store
            var queueRow = queueAgeData[queueIndex];
            queueRow[type] = queueRow[type] + age;

            // Update the Num store
            var queueRow2 = queueNumData[queueIndex];
            queueRow2[type] = queueRow2[type] + num;

            // Update the Age store
            var deptRow = deptAgeData[deptIndex];
            deptRow[type] = deptRow[type] + age;

            // Update the Num store
            var deptRow2 = deptNumData[deptIndex];
            deptRow2[type] = deptRow2[type] + num;

        });

        // Setup custom store with ticket queue fields from rawStore
        queueNumStore = Ext.create('Ext.data.Store', {
            storeId: 'queueNumStore',
            fields: queueFields,
            data: queueNumData
        });

        queueAgeStore = Ext.create('Ext.data.Store', {
            storeId: 'queueAgeStore',
            fields: queueFields,
            data: queueAgeData
        });

        deptNumStore = Ext.create('Ext.data.Store', {
            storeId: 'deptNumStore',
            fields: deptFields,
            data: deptNumData
        });

        deptAgeStore = Ext.create('Ext.data.Store', {
            storeId: 'deptAgeStore',
            fields: deptFields,
            data: deptAgeData
        });

        launchTicketStatsPer(debug, ticketTypes);
        
    });

});
</script>
