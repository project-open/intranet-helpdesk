-- upgrade-5.0.0.0.0-5.0.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-5.0.0.0.0-5.0.0.0.1.sql','');

update im_dynfield_widgets set parameters = '
SELECT im_dynfield_widget__new (
        null, ''im_dynfield_widget'', now(), 0, ''0.0.0.0'', null,
        ''customer_contact_select_ajax'', ''Customer Contact Select AJAX'', ''Customer Contact Select AJAX'',
        10007, ''integer'', ''generic_sql'', ''integer'',
        ''{custom {sql {
                select  u.user_id,
                        im_name_from_user_id(u.user_id) as name
                from    users u
                where   u.user_id not in (
                                -- Exclude deleted or disabled users
                                select  m.member_id
                                from    group_member_map m,
                                        membership_rels mr
                                where   m.group_id = acs__magic_object_id(''''registered_users'''') and
                                        m.rel_id = mr.rel_id and
                                        m.container_id = m.group_id and
                                        mr.member_state != ''''approved''''
                        )
                order by name
        }}
        after_html {
                <script type="text/javascript">
                function customerContactSelectOnChange() {
                    var xmlHttp1;
                    try { xmlHttp1=new XMLHttpRequest();        // Firefox, Opera 8.0+, Safari
                    } catch (e) {
                        try { xmlHttp1=new ActiveXObject("Msxml2.XMLHTTP");     // Internet Explorer
                        } catch (e) {
                            try { xmlHttp1=new ActiveXObject("Microsoft.XMLHTTP");
                            } catch (e) {
                                alert("Your browser does not support AJAX!");
                                return false;
                            }
                        }
                    }
                    xmlHttp1.onreadystatechange = function() {
                        if(xmlHttp1.readyState==4) {
                            var divElement = document.getElementById(''''customer_contact_div'''');
                                divElement.innerHTML = this.responseText;
                        }
                    }
                    var customer_id = document.helpdesk_ticket.ticket_customer_contact_id.value;
                    // Check, if customer_id is null, otherwise all conf_object_items are returned in portlet
                    if (!customer_id) { return false; } ;
                    xmlHttp1.open("GET","/intranet/components/ajax-component-value?plugin_name=Customer%20Info&package_key=intranet-helpdesk&ticket_customer_contact_id=" + customer_id,true);
                    xmlHttp1.send(null);
                }
                window.onload = function() {
                    var dropdown = document.helpdesk_ticket.ticket_customer_contact_id;
                    dropdown.onchange = customerContactSelectOnChange;

                    var divElement = document.getElementById(''''customer_contact_div'''');
                    if (divElement != null){
                        var div = document.helpdesk_ticket.ticket_customer_contact_id;
                        div.onchange = customerContactSelectOnChange;
                        if (div.value != null) { customerContactSelectOnChange() }
                }
                }
                </script>
        }
}''
);
' where widget_name = 'customer_contact_select_ajax';



-----------------------------------------------------------
-- Fix "Summary" tab
--

update im_menus
set url = '/intranet-helpdesk/index'
where label = 'helpdesk_summary';


-----------------------------------------------------------
-- "Dashboard" Tab below "Tickets"
--

SELECT im_menu__new (
	null,				-- p_menu_id
	'im_menu',			-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'intranet-helpdesk',		-- package_name
	'helpdesk_dashboard',		-- label
	'Dashboard',			-- name
	'/intranet-helpdesk/dashboard',	-- url
	20,				-- sort_order
	(select menu_id from im_menus where label = 'helpdesk'),
	null				-- p_visible_tcl
);

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'helpdesk_dashboard'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);




-----------------------------------------------------------
-- Move portlets from Home to Helpdesk Dashboard page
--

update im_component_plugins
set page_url = '/intranet-helpdesk/dashboard'
where	page_url = '/intranet/index' and
	package_name = 'intranet-helpdesk' and
	plugin_name <> 'Home Ticket Component';

