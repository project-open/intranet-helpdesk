-- upgrade-5.0.4.0.1-5.0.4.0.2.sql                                                                                                                                  

SELECT acs_log__debug('/packages/intranet-helpdesk/sql/postgresql/upgrade/upgrade-5.0.4.0.1-5.0.4.0.2.sql','');



-----------------------------------------------------------
-- "New Ticket" menu
--

SELECT im_menu__new (
	null, 'im_menu', now(), null, null, null,
	'intranet-helpdesk',		-- package_name
	'helpdesk_new_ticket',		-- label
	'New Ticket',			-- name
	'/intranet-helpdesk/new',	-- url
	20,				-- sort_order
	(select menu_id from im_menus where label = 'helpdesk'),
	null				-- p_visible_tcl
);

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'helpdesk_new_ticket'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


