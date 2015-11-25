<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">helpdesk</property>


<h1>@page_title@</h1>

<h3>Ticket Queues</h3>
<ul>
<li><a href="/admin/group-types/one?group_type=im_ticket_queue">Admin Ticket Queues</a>
</ul>

<h3>Categories</h3>
<ul>
<li><a href="<%= [export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Status"}}] %>"
    >Category: Intranet Ticket Status</a>
<li><a href="<%= [export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Type"}}] %>"
    >Category: Intranet Ticket Type</a>
<li><a href="<%= [export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Action"}}] %>"
    >Category: Intranet Ticket Action</a>
<li><a href="<%= [export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Priority"}}] %>"
    >Category: Intranet Ticket Priority</a>
<li><a href="<%= [export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Ticket Class"}}] %>"
    >Category: Intranet Ticket Class (-ification)</a>
</ul>
