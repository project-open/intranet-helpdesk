ad_library {

    Initialization for intranet-helpdesk module
    
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @creation-date 10 April, 2012
    @cvs-id $Id$
}

# Initialize the sourceforge import "semaphore" to 0.
# There should be only one thread importing at a time...
nsv_set intranet_helpdesk_sourceforge_sweeper sweeper_p 0

# Check for changed files every X minutes
ad_schedule_proc -thread t [parameter::get_from_package_key -package_key intranet-cost -parameter SourceForgeTrackerSweeperInterval -default 3600] im_helpdesk_sourceforge_tracker_import_sweeper


# Initialize the POP3 import "semaphore" to 0.
# There should be only one thread importing at a time...
nsv_set intranet_helpdesk_pop3_import sweeper_p 0

# Check for incoming email to be converted into tickets
set sweeper_interval [parameter::get_from_package_key -package_key intranet-helpdesk -parameter InboxPOP3SweeperInterval -default 60] 
if {"" != $sweeper_interval && [string is integer $sweeper_interval] && $sweeper_interval > 0} {
    ad_schedule_proc -thread t $sweeper_interval im_helpdesk_inbox_pop3_import_sweeper
}