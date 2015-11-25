<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>

<h2><%=[lang::message::lookup "" intranet-helpdesk.Change_Tickets "Change Prio for the following tickets"]%>:</h2>
<p>@ticket_list_html;noquote@</p>
<br><br>
<form action="<%=$form_action%>" method="POST">
<%= [export_vars -form {return_url}] %>
@hidden_tid_html;noquote@
@select_box;noquote@
<input class="form-button40" name="formbutton:send" value="Submit" type="submit">
</form>


