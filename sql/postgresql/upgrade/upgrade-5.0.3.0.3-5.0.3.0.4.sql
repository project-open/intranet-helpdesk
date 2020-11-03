-- upgrade-5.0.3.0.3-5.0.3.0.4.sql                                                                                                                                  

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-5.0.3.0.3-5.0.3.0.4.sql','');


update im_dynfield_widgets
set parameters =
 	'{custom {sql {
		select	u.user_id,
			im_name_from_user_id(u.user_id) as name
		from	users u
		where	u.user_id not in (
				-- Exclude deleted or disabled users
				select	m.member_id
				from	group_member_map m,
					membership_rels mr
				where	m.group_id = acs__magic_object_id(''registered_users'') and
					m.rel_id = mr.rel_id and
					m.container_id = m.group_id and
					mr.member_state != ''approved''
			)
		order by name
	}}
	after_html {
		<script type="text/javascript" nonce="[im_csp_nonce]">
		function customerContactSelectOnChange() {
		    var xmlHttp1;
		    try { xmlHttp1=new XMLHttpRequest();	// Firefox, Opera 8.0+, Safari
		    } catch (e) {
			try { xmlHttp1=new ActiveXObject("Msxml2.XMLHTTP");	// Internet Explorer
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
			    var divElement = document.getElementById(''customer_contact_div'');
				divElement.innerHTML = this.responseText;
			}
		    }
		    var customer_id = document.helpdesk_ticket.ticket_customer_contact_id.value;
		    xmlHttp1.open("GET","/intranet/components/ajax-component-value?plugin_name=Customer%20Info&package_key=intranet-helpdesk&ticket_customer_contact_id=" + customer_id,true);
		    xmlHttp1.send(null);
		}
		window.onload = function() {
		    var dropdown = document.helpdesk_ticket.ticket_customer_contact_id;
		    dropdown.onchange = customerContactSelectOnChange;

		    var divElement = document.getElementById(''customer_contact_div'');
		    if (divElement != null){
			var div = document.helpdesk_ticket.ticket_customer_contact_id;
			div.onchange = customerContactSelectOnChange;        
			if (div.value != null) { customerContactSelectOnChange() }
		}
		}
		</script>
	}
}'
where widget_name = 'customer_contact_select_ajax';






delete from im_view_columns where column_id = 27099;

insert into im_view_columns (
        column_id, view_id, sort_order,
	column_name,
	column_render_tcl,
        visible_for
) values (
        27099,270,-1,
        '<input id=list_check_all type=checkbox name=_dummy>',
        '$action_checkbox',
        ''
);
