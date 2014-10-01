<master>
<property name="title">@page_title@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>

<h2><%=[lang::message::lookup "" intranet-helpdesk.Change_Tickets "Change Prio for the following tickets"]%>:</h2>
<p>@ticket_list_html;noquote@</p>
<br><br>
<form action="<%=$form_action%>" method="POST">
<%= [export_form_vars return_url] %>
@hidden_tid_html;noquote@
@select_box;noquote@
<input class="form-button40" name="formbutton:send" value="Submit" type="submit">
</form>


