-- upgrade-4.1.0.1.6-5.0.0.0.0.sql

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-4.1.0.1.6-5.0.0.0.0.sql','');

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

