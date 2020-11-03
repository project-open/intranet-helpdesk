<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>
<property name="sub_navbar">@ticket_navbar_html;literal@</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<!-- Show calendar on start- and end-date -->
<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('start_date_calendar').addEventListener('click', function() { showCalendar('start_date', 'y-m-d'); });
     document.getElementById('end_date_calendar').addEventListener('click', function() { showCalendar('end_date', 'y-m-d'); });

     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('ticket', this.checked) });
});
</script>

<table cellspacing="0" cellpadding="0" border="0" width="100%">
<form action=/intranet-helpdesk/action method=POST>
<%= [export_vars -form {return_url}] %>
<tr valign="top">
<td>

	<table class="table_list_page">
	<%= $table_header_html %>
	<%= $table_body_html %>
	<%= $table_continuation_html %>
	<%= $table_submit_html %>
	</table>

</td>
<td width="<%= $dashboard_column_width %>">
<%= $dashboard_column_html %>
</td>
</tr>
</form>
</table>

