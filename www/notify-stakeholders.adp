<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>

<!-- Show calendar on start- and end-date -->
<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('alerts', this.checked) });
});
</script>


<h1>@page_title@</h1>

<form action="/intranet/member-notify" method=GET>
<%= [export_vars -form {return_url}] %>

<table>
<tr>
<td>
	<%= [lang::message::lookup "" intranet-helpdesk.To To] %>
</td>
<td>
	<table>
	<tr class=rowtitle>
	<th align="center">
	<input id=list_check_all type="checkbox" name="_dummy" title="<%= [lang::message::lookup "" intranet-helpdesk.Check_Uncheck_all_rows "Check/Uncheck all rows"] %>" checked>
	</th>
	<th><%= [lang::message::lookup "" intranet-helpdesk.Name Name] %></th>
	<th><%= [lang::message::lookup "" intranet-helpdesk.Email Email] %></th>
	</tr>

	<multiple name=stakeholders>
	<if @stakeholders.rownum@ odd>
	  <tr class="list-odd">
	</if> <else>
	  <tr class="list-even">
	</else>

	<td class="list-narrow">
	      <input type="checkbox" name="user_id_from_search" value="@stakeholders.user_id@" id="alerts,@user_id@" @stakeholders.checked@>
	</td>
	<td class="list-narrow">
	<a href="@stakeholders.stakeholder_url@">@stakeholders.user_name@</a>
	</td>
	<td class="list-narrow">
	<a href="mailto:@stakeholders.email@">@stakeholders.email@</a>
	</td>
	</tr>
	</multiple>
	</table>
</td>
</tr>


<tr>
<td>
	<%= [lang::message::lookup "" intranet-helpdesk.Subject Subject] %>
<td>
	<input type="text" size="70" name="subject" value='@subject@'>
</td>
</tr>

<tr>
<td>
	<%= [lang::message::lookup "" intranet-helpdesk.Message Message] %>
<td>
	<textarea name=message rows=15 cols=80>@message;noquote@</textarea>
</td>
</tr>

<tr>
<td>&nbsp;</td>
<td>
	<input type="submit" name="submit" value="@send_msg@">
</td>
</tr>
</table>




</form>

