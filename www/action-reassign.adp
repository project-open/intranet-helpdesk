<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>

<h2><%=[lang::message::lookup "" intranet-helpdesk.Ticket_Reassign "Reassign the following tickets"]%>:</h2>
<p>@ticket_list_html;noquote@</p>
<br><br>
<form action="<%=$form_action%>" method="GET">
@select_box;noquote@
@hidden_tid_html;noquote@
<input type='hidden' name='return_url' value='@return_url@'>
<input class="form-button40" name="formbutton:send" value="Submit" type="submit">
</form>

