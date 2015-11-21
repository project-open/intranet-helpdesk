<div id=@diagram_id@></div>
<script type='text/javascript'>

Ext.Loader.setPath('PO', '/sencha-core');
Ext.Loader.setPath('GanttEditor', '/intranet-gantt-editor');
Ext.require([
    'Ext.chart.*', 
    'Ext.Window', 
    'Ext.fx.target.Sprite', 
    'Ext.layout.container.Fit',
    'PO.controller.StoreLoadCoordinator',
    'PO.class.PreferenceStateProvider',
    'PO.Utilities',
    'PO.class.PreferenceStateProvider',
    'PO.store.user.SenchaPreferenceStore',
    'PO.model.user.SenchaPreference'
]);


/**
 * Launch the actual editor
 * This function is called from the Store Coordinator
 * after all essential data have been loaded into the
 * browser.
 */
var objectMap = {};
function launchTicketStats@diagram_id@(debug, ticketTypes) {

    var queueNumStore = Ext.StoreManager.get('queueNumStore');
    var queueAgeStore = Ext.StoreManager.get('queueAgeStore');
    var deptNumStore = Ext.StoreManager.get('deptNumStore');
    var deptAgeStore = Ext.StoreManager.get('deptAgeStore');

    // Define the colors for the diagram
    var colors = ['#ff0000', '#b4003f','#7e007b','#4702b7', '#0f00f1'];			// '#5800a2','#3300cb'
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
        highlight: true,
        tips: {
            trackMouse: false,
            width: @diagram_tooltip_width@,
            height: @diagram_tooltip_height@,
            renderer: function(storeItem, item) {
                var fieldName = item.series.title[item.series.yField.indexOf(item.yField)];
                var value = Math.round(10.0 * storeItem.get(item.yField)) / 10.0;
		var q = (storeItem.get('queue') == undefined) ? "" : "queue " +storeItem.get('queue');
		var d = (storeItem.get('dept') == undefined) ? "" : "department " + storeItem.get('dept');
                this.setTitle(value + " open " + item.yField + "s<br>in " + q+d);
            }
        },
	renderer: function(sprite, record, attributes, index, store) {
	    // Replace empty queue/dept with a more readable name.
	    if (!!record) {
		var queue = record.get('queue');
		var dept = record.get('dept');
		if ("" == queue) { record.set('queue', "@not_assigned_l10n@"); }
		if ("" == dept) { record.set('dept', "@not_assigned_l10n@"); }
	    }
	    return attributes;
	},
        listeners: {
            itemclick: function(item, mouseEvent) {
                console.log(item);
		var ticketType = item.yField;
		var ticketTypeId = objectMap[ticketType];
		var queueName = item.storeItem.get('queue');
		var queueId = objectMap[queueName];
		if ("" == queueId) queueId = "null";
		var deptName = item.storeItem.get('dept');
		var deptId = objectMap[queueId];
		if ("" == deptId) deptId = "null";
		

                var url = "/intranet-helpdesk/index?";
		url = url + "mine_p=all";
		url = url + "&ticket_status_id=30000";
		if (!!ticketTypeId) url = url + "&ticket_type_id="+ticketTypeId;
		if (!!queueId) url = url + "&ticket_queue_id="+queueId;
		if (!!deptId) url = url + "&assignee_dept_id="+deptId;
		if (!!'@ticket_customer_contact_id@') url = url + "&ticket_customer_contact_id=@ticket_customer_contact_id@";

                window.open(url);
            }
        }
    };

    // Calculate the number of ticks in the lower horizontal axis
    var majorTickSteps = 3;

    var ticketChart = new Ext.chart.Chart({
        xtype: 'chart',
	flex: 1,
        title: '@diagram_title@',
        layout: 'fit',
        animate: true,
        shadow: false,
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
            minimum: 0,
	    majorTickSteps: majorTickSteps
        }, {
            type: 'Category',
            position: 'left',
            fields: ['queue'],
            minimum: 0,
            label: { 
		font: '@diagram_font@',
		renderer: function(value, label, storeItem, item, i, display, animate, index) {
		    if (value.substring(0,2) == 'Co') value = value.slice(2);		// Remove "Company" prefix from Departments
		    return value;
		}
	    }
        }],
        series: [serie],
        legend: { 
            position: 'float',
            x: @diagram_width@ - @diagram_legend_width@,
            y: 0,
            labelFont: '@diagram_font@'
        },
	listeners: {'boxready': function() { 
	    configureDiagram(); 
	}}
    });

    // Show a reasonable message if there are no open tickets
    if (0 == ticketTypes.length) {
	var allTicketsUrl = "/intranet-helpdesk/index?mine_p=all&ticket_status_id=&ticket_customer_contact_id=@current_user_id@";
	ticketChart = Ext.create('Ext.Component', {
	    html: "You don't have any tickets in status 'open' at the moment.<br>"+
		"Here is the <a href='"+allTicketsUrl+"' target='_blank'>list of all tickets</a>.",
	    width: 300, height: 100, padding: 10
	});
    }

    var configureDiagram = function () {
	if (!ticketChart.rendered) return;						// Chart has not been rendered yet
        var series = ticketChart.series;
        var buttonToggleLegend = Ext.getCmp('buttonToggleLegend');
        var comboNumberAge = Ext.getCmp("comboNumberAge");
        var comboQueueDept = Ext.getCmp("comboQueueDept");
        if (!buttonToggleLegend || !comboNumberAge || !comboQueueDept) return;

        var showLegend = buttonToggleLegend.pressed;
        var legend = ticketChart.legend;
        legend.toggle(showLegend);
        var numAge = comboNumberAge.getValue();						// "num" or "age"
        var queueDept = comboQueueDept.getValue();					// "queue" or "dept"
        var stacked = (numAge == "num");						// Numbers add up, age doesn't

	// Position the legend at the right of the diagram
	var diagramWidth = ticketChart.curWidth;
	var legendXPos = diagramWidth - @diagram_legend_width@;
	ticketChart.legend.x = legendXPos;

        // Determine the field to show at the left axis
        var axis = ticketChart.axes;
        var leftAxis = axis.get('left');
        leftAxis.fields = [queueDept];

        // Determine the store to show
        var storeName = queueDept;
        storeName = storeName + numAge.charAt(0).toUpperCase() + numAge.slice(1);
        storeName = storeName + "Store";
        var store = Ext.StoreManager.get(storeName);

	// Check if the chart already has a surface - owtherwise redraw will throw an error
	var chartSurface = ticketChart.surface;
	if (!chartSurface) return;

        series.clear();
	serie.stacked = stacked;		  
        series.add(serie);
        ticketChart.bindStore(store);							// Store with number of tickets
        ticketChart.redraw();
    };

    var panel = Ext.create('Ext.panel.Panel', {
	id: 'panelTicketAgePerQueuePanel',
        renderTo: '@diagram_id@',
        width: @diagram_width@,
        height: @diagram_height@,
        title: false,
	layout: 'fit',
        items: [ticketChart],
        dockedItems : [{
            xtype : 'toolbar',
            dock  : 'top',
            items : [{
                xtype: 'combobox',
        	id: "comboQueueDept",
                stateId : 'comboQueueDept',
                // tooltip: 'Show Department or Queue?',
                displayField: 'category',
                valueField: 'category_id',
                hideLabel: true,
                value: 'queue',
                width: 100,
                store: Ext.create('Ext.data.Store', { fields: ['category_id', 'category'], data: [
                    {category_id: "queue", category: '@queue_l10n@'},
                    {category_id: "dept", category: '@dept_l10n@'}
                ]}),
                allowBlank: false,
                forceSelection: true,
                stateful : true,
                listeners: {change: function() { configureDiagram(); }}
            }, {
                xtype: 'combobox',
        	id: "comboNumberAge",
                stateId : 'comboNumberAge',
                // tooltip: 'Show age or number of tickets?',
                displayField: 'category',
                valueField: 'category_id',
                hideLabel: true,
                value: 'num',
                width: 80,
                store: Ext.create('Ext.data.Store', { fields: ['category_id', 'category'], data: [
                    {category_id: "num", category: '@number_l10n@'},
                    {category_id: "age", category: '@age_l10n@'}
                ]}),
                allowBlank: false,
                forceSelection: true,
                stateful : true,
                listeners: {change: function() { configureDiagram(); }}
            }, '->', {
                xtype: 'button',
                id: 'buttonToggleLegend',
                icon: '/intranet/images/navbar_default/layout.png',
                tooltip: '@show_or_hide_legend_l10n@',
                pressed: true,
                enableToggle: true,
                handler: function(button) { this.fireEvent('press'); configureDiagram(); },

		// Stateful Configuration - remember if the button was pressed.
                stateful : true,
                stateEvents: ['press'],
                stateId : 'buttonToggleLegend',
                getState: function() { return { pressed: this.pressed }; },
                applyState: function(state) { this.toggle(state.pressed); },
                listeners: { toggle: function() { this.fireEvent('press'); configureDiagram(); }}
            }, {
                xtype: 'button',
                id: 'buttonToggleHelp',
                icon: '/intranet/images/navbar_default/help.png',
                tooltip: '@show_or_hide_help_l10n@',
                pressed: true,
		hidden: true,
                enableToggle: true,
                handler: function(button) { 
		    this.fireEvent('press');
		    if (this.pressed) {
			var helpWindows = Ext.getCmp('helpWindow');
			helpWindow.show();
		    } else {
			var helpWindows = Ext.getCmp('helpWindow');
			helpWindow.hide();
		    }
		},

		// Stateful Configuration - remember if the button was pressed.
                stateful : true,
                stateEvents: ['press'],
                stateId : 'buttonToggleHelp',
                getState: function() { return { pressed: this.pressed }; },
                applyState: function(state) { 
		    this.toggle(state.pressed); 
		    if (state.pressed) {
//			var helpWindows = Ext.getCmp('helpWindow');
//			helpWindow.show();
		    } else {
//			var helpWindows = Ext.getCmp('helpWindow');
//			helpWindow.hide();
		    }
		},
                listeners: { toggle: function() { 
		    this.fireEvent('press'); 
		}}
            }]
        }]
    });


    var panelViewRegion = ticketChart.getViewRegion();		// Get the position of the main panel
    var helpWindow = Ext.create('Ext.window.Window', {
	id: 'tipOfTheDayWindow',
	title: 'Tip of the Day',
	height: 200,
	width: panelViewRegion.right - panelViewRegion.left - 20,
	x: panelViewRegion.x + 10,
	y: panelViewRegion.y + 10,
	layout: 'fit',
	items: {						// Let's put an empty grid in just to illustrate fit layout
            xtype: 'grid',
            border: false,
            columns: [{header: 'World'}],			// One header just for show. There's no data,
            store: Ext.create('Ext.data.ArrayStore', {})	// A dummy empty data store
	},
	closeAction: 'hide'					// Don't destroy the window when closing
    }).hide();

    var controller = new Ext.create('Ext.app.Controller', {
	init: function() {
	    this.control({
		'#buttonToggleHelp': {
		    'toggle': this.onButtonToggleHelp,
		    'applystate': this.onButtonToggleApplyState
		},
		'#panelTicketAgePerQueuePanel': { 
		    'afterrender': this.onPanelAfterRender
		}
	    });
	},
	
	onButtonToggleHelp: function(button, pressed) {
	    console.log('ticketAgePerQueue.onButtonToggleHelp: pressed='+pressed);
	},

	onButtonToggleApplyState: function() {
	    console.log('ticketAgePerQueue.onButtonToggleApplyState');
	},

	onPanelAfterRender: function() {
	    console.log('ticketAgePerQueue.onPanelAfterRender');
	},

	redrawGanttBarPanel: function() {
	    var ganttBarPanel = this.getGanttBarPanel();
	    ganttBarPanel.redraw();
	}
    }).init();
};




/**
 * Load Stores from server before
 * starting the actual Chart.
 */
Ext.onReady(function () {

    Ext.QuickTips.init();
    var debug = true;

    // Store state
    var senchaPreferenceStore = Ext.create('PO.store.user.SenchaPreferenceStore');
    senchaPreferenceStore.load();

    // "Raw" store with age, queue and ticket type from the database
    var rawStore = Ext.create('Ext.data.Store', {
        storeId: 'rawStore',
        fields: ['number', 'age', 'queue', 'queue_id', 'assignee_dept', 'assignee_dept_id', 'type', 'type_id'],
        autoLoad: false,
        proxy: {
            type: 'rest',
            url: '/intranet-reporting/view',						// This is the generic ]po[ REST interface
            extraParams: {
                format: 'json',								// Ask for data in JSON format
                report_code: '@diagram_report_code;noquote@',				// The code of the data-source to retreive
                customer_contact_id: '@ticket_customer_contact_id;noquote@'		// The code of the data-source to retreive
            },
            reader: { type: 'json', root: 'data' }					// Standard reader: Data are prefixed by "data".
        }
    });

    // Load the store 10-110ms after the the rest of the page is ready.
    // This allows the rest of the page to be more reactive.
    var task = new Ext.util.DelayedTask(function(){ rawStore.load(); });
    task.delay(500 + 2000*Math.random());


    // Setup the stores for the various views
    ticketTypes = @ticket_types_json;noquote@;
    var queueFields = ["queue"];
    var deptFields = ["dept"];
    ticketTypes.forEach(function(type) {
        queueFields.push(type); 
        deptFields.push(type); 
    });
    
    queueNumStore = Ext.create('Ext.data.Store', { storeId: 'queueNumStore', fields: queueFields });
    queueAgeStore = Ext.create('Ext.data.Store', { storeId: 'queueAgeStore', fields: queueFields });
    deptNumStore = Ext.create('Ext.data.Store', { storeId: 'deptNumStore', fields: deptFields });
    deptAgeStore = Ext.create('Ext.data.Store', { storeId: 'deptAgeStore', fields: deptFields });

    var simplifyTicketType = function(str) {
        return str.trim();
    };

    var simplifyQueue = function(str) {
        return str.trim();
    };

    var simplifyDept = function(str) {
        return str.trim();
    };


    // Store Coodinator starts app after all stores have been loaded:
    var coordinator = Ext.create('PO.controller.StoreLoadCoordinator', {
        debug: debug,
        stores: [
            'rawStore',
            'senchaPreferenceStore'
        ],
        listeners: {
            load: function() {
                if ("boolean" == typeof this.loadedP) { return; }			// Check if the application was launched before
                this.loadedP = true;							// Mark the application as launched

		Ext.state.Manager.setProvider(new PO.class.PreferenceStateProvider({
		    url: '/intranet-helpdesk/lib/ticket-age-per-queue'
		}));

                // Gather the list of ticket types and queues from raw data
                var queues = [];
                var depts = [];
		objectMap = {'@not_assigned_l10n@': ''};				// Map from object_name to object_id, hopefully unique :-)
                rawStore.each(function(record) {
                    var type = record.get('type').trim();
                    var type_id = record.get('type_id').trim();
                    type = simplifyTicketType(type);
		    objectMap[type] = type_id;

                    var queue = record.get('queue').trim();
                    var queue_id = record.get('queue_id').trim();
                    queue = simplifyQueue(queue);
		    objectMap[queue] = queue_id;

                    var dept = record.get('assignee_dept').trim();
                    var dept_id = record.get('assignee_dept_id').trim();
                    dept = simplifyDept(dept);
		    objectMap[dept] = dept_id;

                    if (queues.indexOf(queue) < 0) queues.push(queue);
                    if (depts.indexOf(dept) < 0) depts.push(dept);
                });
                queues.sort().reverse();
                depts.sort().reverse();

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
		queueNumStore.add(queueNumData);
		queueAgeStore.add(queueAgeData);
                deptNumStore.add(deptNumData);
                deptAgeStore.add(deptAgeData);

            }
        }
    });

    launchTicketStats@diagram_id@(debug, ticketTypes, objectMap);

});
</script>
