#!/usr/bin/perl -w

# --------------------------------------------------------
#
# import-pop3
#
# ]project-open[ ERP/Project Management System
# (c) 2008 - 2010 ]project-open[
# frank.bergmann@project-open.com
#
# --------------------------------------------------------

use FindBin;
use lib $FindBin::Bin;
use DBI;
use Net::POP3;
use MIME::Parser;
use MIME::Entity;

# --------------------------------------------------------
# Debug? 0=no output, 10=very verbose
$debug = 1;


# --------------------------------------------------------
# Database Connection Parameters
#

# The name of the ]po[ server
$server = "projop";				# The name of the database instance.
$db_username = "$server";			# By default the same as the server.
$db_pwd = "";					# The DB password. Empty by default.
$db_datasource = "dbi:Pg:dbname=$server";	# How to identify the database
$server_file_storage = "/web/$server/filestorage/tickets"; # Default filename for ticket file storage


# --------------------------------------------------------
# The POP3 Mail Account

$pop3_server = "pop.1und1.de";			# POP3 server with the mailbox
$pop3_user = "mailbox\@your-server.com";	# Username - you need to quote the ampersand!
$pop3_pwd = "secret";				# POP3 password


# --------------------------------------------------------
# Types of attachments to be saved to disk
my @attypes= qw(application
		audio
		image
		text
);


# --------------------------------------------------------
# Define the date format for debugging messages
$date = `/bin/date +"%Y%m%d.%H%M"` || 
    die "common_constants: Unable to get date.\n";
chomp($date);



# --------------------------------------------------------
# Establish the database connection
# The parameters are defined in common_constants.pm
$dbh = DBI->connect($db_datasource, $db_username, $db_pwd) ||
    die "import-pop3: Unable to connect to database.\n";



# --------------------------------------------------------
# Establish a connection to the POP3 server
#
$pop3_conn = Net::POP3->new($pop3_server, Timeout => 60) 
    || die "import-pop3: Unable to connect to POP3 server $pop3_server: Timeout\n";

$n = $pop3_conn->login($pop3_user,$pop3_pwd) 
    || die "import-pop3: Unable to connect to POP3 server $pop3_server: Bad Password\n"; 

if (0 == $n) { 
    print "import-pop3: No messages on server.\n";
    exit 0; 
}

# Get the list of messages
$msgList = $pop3_conn->list(); 
print "import-pop3: Reading pop3 message list: ", keys(%$msgList), "\n" if ($debug >= 1);


# MIME Parser initialization
my $parser = new MIME::Parser;
$parser->ignore_errors(1);
$parser->output_to_core(1);
$parser->tmp_to_core(1);


# Initialize attachment arrays
my @attachment = ();
my @attname = ();


# --------------------------------------------------------
# Loop for each of the mails
foreach $msg (keys(%$msgList)) {
    # Get the mail as a file handle
    $message = $pop3_conn->get($msg);
    
    # Parse the MIME email
    my $parsed = $parser->parse_data($message);
    my $error = ($@ || $parser->last_error);
    print "import-pop3: error:$error\n" if ("" ne $error);
    # $parsed->dump_skeleton();
    my $header = $parsed->head();
    my $subject = $header->get('Subject');
    my $to = $header->get('To');
    my $from = $header->get('From');
    chomp($from);
    chomp($to);
    chomp($subject);

    print "import-pop3: \n" if ($debug >= 1);
    print "import-pop3: from:\t$from\n" if ($debug >= 1);
    print "import-pop3: to:\t$to\n" if ($debug >= 1);
    print "import-pop3: subject:\t$subject\n" if ($debug >= 1);

    # Parse the message body
    my @parts = $parsed->parts();
    for my $part (@parts) {
	my $mime_type = $part->mime_type;
	print "import-pop3: mime_type=$mime_type\n" if ($debug >= 1);

	if ($mime_type eq "text/plain") {
	    print "import-pop3: text/plain: ", $part->body(), "\n" if ($debug >= 1);
	    $body .= $part->body();
	} elsif ($mime_type eq "text/html") {
	    print "import-pop3: text/html: ", $part->body(), "\n" if ($debug >= 1);
	    $body .= $part->body();
	} elsif ($mime_type eq "multipart/alternative") {
	    print "import-pop3: multipart/alternative: \n" if ($debug >= 1);
	    if ($part->parts() == 2 and $part->parts(0)->effective_type eq "text/plain" and $part->parts(1)->effective_type eq "text/html") {
		# Let's just use the plain text part of the mail
		$body .= $part->parts(0)->body_as_string();
		print "import-pop3: ", $part->parts(0)->body_as_string(), "\n" if ($debug >= 1);
	    } else {
		for my $subpart ($part->parts()) {
		    print "import-pop3: multipart/alternative: subpart: ", $subpart->body_as_string(), "\n" if ($debug >= 1);
		    $body .= $subpart->body_as_string();
		}
	    }
	} elsif ($mime_type eq "message/delivery-status") {
	    print "import-pop3: message/delivery-status: ", $part->body(), "\n" if ($debug >= 1);
	} else {
	    my $mime_main_type = "";
	    if ($mime_type =~ /^(\w+)\/(\w+)/) {
		$mime_main_type = $1;
	    }
	    print "import-pop3: trying to identify attachment for mime_main_type=$mime_main_type\n" if ($debug >= 1);
	    foreach $x (@attypes){
		if ($mime_main_type =~ m/$x/i){
		    print "import-pop3: found attachment for $mime_main_type\n" if ($debug >= 1);
		    $bh = $part->bodyhandle;
		    $attachment = $bh->as_string;
		    push @attachment, $attachment;
		    push @attname, $part->head->mime_attr('content-disposition.filename');
		}
	    }
	}
    }

    print "import-pop3\n" if ($debug >= 1);
    print "import-pop3: body=$body\n" if ($debug >= 1);
    print "import-pop3: attachments: @attname\n" if ($debug >= 1);

    # $pop3_conn->delete($msg);
    # $pop3_conn->quit(); exit 0;


    # --------------------------------------------------------
    # Calculate ticket database fields
    
    # Ticket Nr: Take current number from the im_ticket_seq sequence
    $sth = $dbh->prepare("SELECT nextval('im_ticket_seq') as ticket_nr");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $row = $sth->fetchrow_hashref;
    my $ticket_nr = $row->{ticket_nr};
    
    # Ticket Name: Ticket Nr + Mail Subject
    my $ticket_name = "$ticket_nr - $subject";
    
    # Customer ID: Who should pay to fix the ticket?
    # Let's take the "internal" company (=the company running this server).
    $sth = $dbh->prepare("SELECT company_id as company_id from im_companies where company_path = 'internal'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $ticket_customer_id = $row->{company_id};

    # SLA: Just get the first open SLA for the customer as an example.
    # Customers may want to use more complex logic and assign the
    # ticket to different SLAs depending on the sender domain etc.
    $sth = $dbh->prepare("SELECT min(project_id) as sla_id from im_projects where company_id = '$ticket_customer_id' and project_type_id = 2502 and project_status_id = 76");
    my $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    my $ticket_sla_id = "NULL";
    if ($rv >= 0) {
	$row = $sth->fetchrow_hashref;
	my $ticket_sla_id = $row->{sla_id};
    }
    
    # Customer's contact: Check database for "From" email
    my $sql = "select party_id from parties where lower(trim(email)) = lower(trim('$from'))";
    $rv = $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    my $ticket_customer_contact_id = 0;
    if ($rv >= 0) {
	$row = $sth->fetchrow_hashref;
	my $ticket_customer_contact_id = $row->{party_id};
    }
    
    # Ticket Type:
    #  30102 | Purchasing request
    #  30104 | Workplace move request
    #  30106 | Telephony request
    #  30108 | Project request
    #  30110 | Bug request
    #  30112 | Report request
    #  30114 | Permission request
    #  30116 | Feature request
    #  30118 | Training request
    my $ticket_type_id = 30110;
    
    # Ticket Status:
    #    30000 | Open
    #    30001 | Closed
    #    30010 | In review
    #    30011 | Assigned
    #    30012 | Customer review
    #    30090 | Duplicate
    #    30091 | Invalid
    #    30092 | Outdated
    #    30093 | Rejected
    #    30094 | Won't fix
    #    30095 | Can't reproduce
    #    30096 | Resolved
    #    30097 | Deleted
    #    30098 | Canceled
    my $ticket_status_id = 30000;
    
    # Ticket Prio
    # 30201 |	 	1 - Highest
    # 30202	|		2 
    # 30203 |		3 	
    # 30204 |		4 	
    # 30205 |		5 	
    # 30206 |		6 	
    # 30207 |		7 	
    # 30208 |		8 	
    # 30209 |		9 - Lowest
    my $ticket_prio_id = 30205;


    # --------------------------------------------------------
    # Insert the basis ticket into the SQL database
    $sth = $dbh->prepare("
		SELECT im_ticket__new (
			nextval('t_acs_object_id_seq')::integer, -- p_ticket_id
			'im_ticket'::varchar,			-- object_type
			now(),					-- creation_date
			0::integer,				-- creation_user
			'0.0.0.0'::varchar,			-- creation_ip
			null::integer,				-- (security) context_id
	
			'$ticket_name'::varchar,
			'$ticket_nr'::varchar,
			'$ticket_customer_id'::integer,
			'$ticket_type_id'::integer,
			'$ticket_status_id'::integer
		) as ticket_id
    ");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $ticket_id = $row->{ticket_id};
    
    # Update ticket field stored in the im_tickets table
    $sql = "
		update im_tickets set
			ticket_type_id			= '$ticket_type_id',
			ticket_status_id		= '$ticket_status_id',
			ticket_customer_contact_id	= '$ticket_customer_contact_id',
			ticket_prio_id			= '$ticket_prio_id'
		where
			ticket_id = $ticket_id
    ";
    $sth = $dbh->prepare($sql);
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    
    # Update ticket field stored in the im_projects table
    $sth = $dbh->prepare("
		update im_projects set
			project_name		= '$ticket_name',
			project_nr		= '$ticket_nr',
			parent_id		= $ticket_sla_id
		where
			project_id = $ticket_id;
    ");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";


    # --------------------------------------------------------
    # Add a Forum Topic Item into the ticket
    
    # Get the next topic ID
    $sth = $dbh->prepare("SELECT nextval('im_forum_topics_seq') as topic_id");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $topic_id = $row->{topic_id};
    
    my $topic_type_id = 1108; # Note
    my $topic_status_id = 1200; # open
    
    # Insert a Forum Topic into the ticket container
    $sql = "
		insert into im_forum_topics (
			topic_id, object_id, parent_id,
			topic_type_id, topic_status_id, owner_id,
			subject, message
		) values (
			'$topic_id', '$ticket_id', null,
			'$topic_type_id', '$topic_status_id', '$ticket_customer_contact_id',
			'$subject', '$body'
		)
    ";
    $sth = $dbh->prepare($sql);
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";


    # --------------------------------------------------------
    # Start a new dynamic workflow around the ticket
    
    # Get the next topic ID
    $sth = $dbh->prepare("SELECT aux_string1 from im_categories where category_id = '$ticket_type_id'");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
    $row = $sth->fetchrow_hashref;
    my $workflow_key = $row->{aux_string1};
    
    if ("" ne $workflow_key) {
	print "import-pop3: Starting workflow '$workflow_key'\n" if ($debug);
	$sql = "
		select workflow_case__new (
			null,
			'$workflow_key',
			null,
			'$ticket_id',
			now(),
			0,
			'0.0.0.0'
		) as case_id
	";
	$sth = $dbh->prepare($sql) || die "import-pop3: Unable to prepare SQL statement: \n$sql\n";
	$sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
	$row = $sth->fetchrow_hashref;
	my $case_id = $row->{case_id};

	$sql = "
		select workflow_case__start_case (
			'$case_id',
			'$ticket_customer_contact_id',
			'0.0.0.0',
			null
		)
	";
	$sth = $dbh->prepare($sql) || die "import-pop3: Unable to prepare SQL statement: \n$sql\n";
	$sth->execute() || die "import-pop3: Unable to execute SQL statement: \n$sql\n";
	
    }


    # --------------------------------------------------------
    # Save Attachments
    #
    $sth = $dbh->prepare("SELECT company_path from im_companies where company_id = $ticket_customer_id");
    $sth->execute() || die "import-pop3: Unable to execute SQL statement.\n";
    $row = $sth->fetchrow_hashref;
    my $customer_path = $row->{company_path};

    for($i=0; $i <= $#attname; $i++){
	my $att_name = $attname[$i];
	my $att_content = $attachment[$i];
	my $path = "$server_file_storage/$customer_path/$ticket_nr";
	print "import-pop3: Writing attachment to file=$path/$att_name\n" if ($debug >= 1);
	system("mkdir -p $path");
	open(OUT, ">$path/$att_name");
	print OUT $att_content;
	close(OUT);
    }

    # Remove the message from the inbox
    $pop3_conn->delete($msg);

}

# --------------------------------------------------------
# Close the connection to the POP3 server
$pop3_conn->quit();

# --------------------------------------------------------
# check for problems which may have terminated the fetch early
$sth->finish;
warn $DBI::errstr if $DBI::err;

# --------------------------------------------------------
# Close the database connection
$dbh->disconnect ||
	warn "Disconnection failed: $DBI::errstr\n";


# --------------------------------------------------------
# Return a successful execution ("0"). Any other value
# indicates an error. Return code meaning still needs
# to be determined, so returning "1" is fine.
exit(0);
