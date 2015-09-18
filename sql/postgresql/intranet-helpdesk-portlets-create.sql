-- /packages/intranet-helpdesk/sql/postgresql/intranet-helpdesk-portlets-create.sql
--
-- Copyright (c) 2003-2008 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com


select  im_component_plugin__del_module('intranet-helpdesk');
-- select  im_menu__del_module('intranet-helpdesk');


-----------------------------------------------------------
-- Component Plugin
--
-- Forum component on the ticket page itself

SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Discussions',			-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'bottom',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_forum_full_screen_component -object_id $ticket_id',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Ticket_Discussions" "Ticket Discussions"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Discussions' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


-- Timesheet plugin
select im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

	'Timesheet',				-- plugin_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'right',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	50,					-- sort_order
	'im_timesheet_project_component $current_user_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Timesheet "Ticket Timesheet"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Timesheet' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Timesheet'';
	FOR row IN
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Workflow Graph

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Workflow',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'right',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	10,					-- sort_order
	'im_workflow_graph_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Workflow "Ticket Workflow"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Workflow' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);



-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Workflow'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Journal on Absence View Page

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Journal',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'bottom',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	100,					-- sort_order
	'im_workflow_journal_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Journal "Ticket Journal"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Journal' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Journal'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



-- ------------------------------------------------------
-- Filestorage on Absence View Page

SELECT	im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Filestorage',				-- component_name - shown in menu
	'intranet-helpdesk',			-- package_name
	'bottom',				-- location
	'/intranet-helpdesk/new',		-- page_url
	null,					-- view_name
	110,					-- sort_order
	'im_filestorage_ticket_component $user_id $ticket_id $ticket_name $return_url', -- component_tcl
	'lang::message::lookup "" intranet-helpdesk.Ticket_Filestorage "Ticket Filestorage"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Filestorage' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

-- move component to Ticket Menu Tab for all users
create or replace function inline_0 ()
returns integer as '
declare
	row			RECORD;
	v_plugin_id		integer;
	v_sort_order		integer;
BEGIN
	select plugin_id, sort_order into v_plugin_id, v_sort_order from im_component_plugins 
	where package_name = ''intranet-helpdesk'' and plugin_name = ''Filestorage'';
	FOR row IN 
		select user_id from users_active au
		where 0 = (
			select count(*) from im_component_plugin_user_map cpum
			where cpum.user_id = au.user_id and cpum.plugin_id = v_plugin_id
		)
	LOOP
		insert into im_component_plugin_user_map (plugin_id, user_id, sort_order, minimized_p, location)
		values (v_plugin_id, row.user_id, v_sort_order, ''f'', ''none'');
	END LOOP;
	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- ------------------------------------------------------
-- List of Tickets at the home page
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Home Ticket Component',	-- plugin_name
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet/index',		-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_helpdesk_home_component',
	'lang::message::lookup "" intranet-helpdesk.Home_Ticket_Component "Home Ticket Component"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Home Ticket Component' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);



-- ------------------------------------------------------
-- Workflow Actions in the object's View Page
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Actions',			-- plugin_name
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	0,				-- sort_order
	'im_workflow_action_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Workflow_Actions "Ticket Workflow Actions"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'
	),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'
	),
        (select group_id from groups where group_name = 'Customers'),
        'read'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins 
	 where plugin_name = 'Actions' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Freelancers'),
        'read'
);



-- ------------------------------------------------------
-- Show the customer contacts information
-- to allow the helpdesk to contact the customer
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Customer Info',		-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	10,				-- sort_order
	'im_user_base_info_component -user_id $ticket_customer_contact_id -show_user_conf_items_p 1',
	'lang::message::lookup "" intranet-helpdesk.Customer_Info "Customer Info"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Customer Info' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);



-- ------------------------------------------------------
-- Show related objects
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Related Objects',	-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	91,				-- sort_order
	'im_biz_object_related_objects_component -object_id $ticket_id',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Related_Objects "Ticket Related Objects"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Ticket Related Objects' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);


-- ------------------------------------------------------
-- Show users associated with ticket
--
SELECT	im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Members',		-- plugin_name
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/new',	-- page_url
	null,				-- view_name
	80,				-- sort_order
        'im_group_member_component $ticket_id $current_user_id $user_admin_p $return_url "" "" 1',
	'lang::message::lookup "" intranet-helpdesk.Ticket_Members "Ticket Members"'
);

SELECT acs_permission__grant_permission(
        (
		select plugin_id
		from im_component_plugins 
		where plugin_name = 'Ticket Members' and package_name = 'intranet-helpdesk'
	),
        (
		select group_id 
		from groups 
		where group_name = 'Employees'
	),
        'read'
);



-- ------------------------------------------------------
-- Show tickets in SLA
--
SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Project Ticket Component',	-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'left',				-- location
	'/intranet/projects/view',	-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_helpdesk_project_component -project_id $project_id'	-- component_tcl
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Project Ticket Component' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


-----------------------------------------------------------
-- Ticket Aging Report
--
SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Ticket Aging',			-- plugin_name - shown in menu
	'intranet-helpdesk',		-- package_name
	'right',			-- location
	'/intranet-helpdesk/index',	-- page_url
	null,				-- view_name
	30,				-- sort_order
	'im_helpdesk_ticket_aging_diagram',	-- component_tcl
	'lang::message::lookup "" "intranet-helpdesk.Ticket_Aging" "Ticket Aging"'
);

SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Customers'),
	'read'
);
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Ticket Aging' and package_name = 'intranet-helpdesk'), 
	(select group_id from groups where group_name = 'Freelancers'),
	'read'
);



-----------------------------------------------------------
-- Ticket number and age per dept
--

SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'im_component_plugin',          -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Tickets per Queue & Dept',	-- plugin_name - shown in menu
        'intranet-helpdesk',            -- package_name
        'right',                        -- location
        '/intranet-helpdesk/index',     -- page_url
        null,                           -- view_name
        30,                             -- sort_order
        'im_helpdesk_ticket_age_number_per_queue',     -- component_tcl
        'lang::message::lookup "" "intranet-helpdesk.Ticket_per_Queue_and_Dept" "Tickets per Queue & Dept"'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Tickets per Queue & Dept' and package_name = 'intranet-helpdesk'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);


