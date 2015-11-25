<if @enable_master_p@>
<master src="../../intranet-core/www/master">
</if>

<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context;literal@</property>
<property name="main_navbar_label">helpdesk</property>
<property name="focus">@focus;literal@</property>
<property name="sub_navbar">@sub_navbar;literal@</property>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<%= [im_box_header $page_title] %>
<formtemplate id="ticket"></formtemplate>
<%= [im_box_footer] %>
