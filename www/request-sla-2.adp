<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>
<property name="sub_navbar">@ticket_navbar_html;literal@</property>

<h1>@page_title@</h1>

<p>
<%= [lang::message::lookup "" intranet-helpdesk.Successfully_requested "You have successfully requested a new Ticket Container."] %>
</p>
<p>&nbsp;</p>
<p>
<%= [lang::message::lookup "" intranet-helpdesk.Check_Inbox_for_email "Please check your Inbox for a confirmation email."] %>
</p>
<p>
<%= [lang::message::lookup "" intranet-helpdesk.Confirm_mail "You will receive another email once the support team has processed your request."] %>
</p>


