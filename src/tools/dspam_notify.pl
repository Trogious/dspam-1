#!/usr/bin/perl

use Net::SMTP;

# Enter the location of you dspam.conf file.
$DSPAMCONF = "/etc/dspam.conf";

# Who will the notifications be sent from?
$FROM = 'dspam@domain.tld';
  
# What will the notification subject be?
$SUBJECT = 'Daily Spam Quarantine Summary';

# Quarantine URL
$DSPAM_URL = 'https://dspam.domain.tld';

# Address of your SMTP server?  localhost should be fine.
$SERVER = 'localhost';

# Enable User Preference Checking (Very CPU Intensive!!!) Not Recommended for more than 500 email accounts.
$PREF_CHECK = 0;

######################################
# No need to config below this point.#
######################################


#Build the Quarantine URL
$QUARANTINE_URL = $DSPAM_URL . '/dspam.cgi?template=quarantine';

# Autodetect Scale
my $X = `dspam --version`;
if ($X =~ /--enable-domain-scale/) {
  $DOMAIN_SCALE = 1;
  $LARGE_SCALE = 0;
}
if ($X =~ /--enable-large-scale/) {
  $LARGE_SCALE = 1;
  $DOMAIN_SCALE = 0;
}


# Date Formatting
my ($SEC,$MIN,$HOUR,$MDAY,$MON,$YEAR,$WDAY,$YDAY,$ISDST) = localtime(time);
  
# Array containing Days of the week abreviations
@WEEKDAYS = ('Sun','Mon','Tue','Wed','Thur','Fri','Sat');
    
# Array containing Month abreviations
@MONTHS = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
    
$D = (localtime)[6];
$M = (localtime)[4];

$DAY_ABR = $WEEKDAYS[$D];
$MONTH_ABR = $MONTHS[$M];
$DAY_NUM = $MDAY; 
$YEAR += 1900;

$TODAY = $DAY_ABR . " " . $MONTH_ABR . " " . $DAY_NUM;
    
# Get the location of dspamhome
chomp($DSPAMHOME = `awk '/Home / {print \$2}' $DSPAMCONF`);


# Create a Recipient List
chomp(@DSPAM_STATS = `dspam_stats | awk '{print \$1 " " \$3}'`);		# Get A list of users from dspam_stats

foreach $LINE (@DSPAM_STATS) { 
  @SPLIT= split(/ /, $LINE);
  if (@SPLIT[1] != 0) {                                                 	# If dspam user has TP's then
    push(@RECIPIENT_LIST, @SPLIT[0]);                                   	# add to Recipient List
  } 
  @SPLIT = ();                                                          	# Destroy Array for next split
}
@DSPAM_STATS = ();                                                      	# Destroy Array, no further use

# Check for AllowOverride
if ($PREF_CHECK == 1) {
  chomp($ALLOW_OVERRIDE = `dspam_admin agg pref 'default' 2>&1 | grep -i -c "Ignoring disallowed preference 'dailyQuarantineSummary'"`);
  if ($ALLOW_OVERRIDE == 1) {
    $ALLOW_OVERRIDE = "off";
    }
  if ($ALLOW_OVERRIDE == 0) {
    $ALLOW_OVERRIDE = "on";
  }
  # Get the default user preference
  chomp($DEFAULT_PREF = `dspam_admin li pref 'default' | grep -i 'dailyQuarantineSummary' | cut -d= -f2`);
} else {									# Preference Checking disabled,
  $ALLOW_OVERRIDE = "off";							# Set some default values
  $DEFAULT_PREF = "on";								#
}

# Gather Recipient Quarantine Info
foreach $RECIPIENT (@RECIPIENT_LIST) {

  # Get User Preference from dspam_admin
  if ($ALLOW_OVERRIDE eq "on") {						# Check for Allow Overides
    chomp($USER_PREF = `dspam_admin li pref '$RECIPIENT' | grep -i 'dailyQuarantineSummary' | cut -d= -f2`);
    if ($USER_PREF ne 'on' && $USER_PREF ne 'off') {
      $USER_PREF = $DEFAULT_PREF;						# User Preference in valid, use default preference
    }
  } else {
    $USER_PREF = $DEFAULT_PREF;							# Overrides off, use default preference
  }
  
  # Build path to Quarantine .mbox
  if ($DOMAIN_SCALE == 1) {							# Format Quarantine path for Domain Scale
    @USER_DOMAIN = split(/@/, $RECIPIENT);
    $u = @USER_DOMAIN[0];
    $D = @USER_DOMAIN[1];
    $MBOX = $DSPAMHOME . "/data/" . $D . "/" . $u . "/" . $u . ".mbox";
  }
    
  if ($LARGE_SCALE == 1) {							# Format Quarantine path for Large Scale
    $u = substr($RECIPIENT, 0, 1);
    $s = substr($RECIPIENT, 1, 1);
    $MBOX = $DSPAMHOME . "/data/" . $u . "/" . $s . "/" . $RECIPIENT . ".mbox";
  }
    
  if ($DOMAIN_SCALE == 0 && $LARGE_SCALE == 0) {				# Format Quarantine path for Normal Scale
    $MBOX = $DSPAMHOME . "/data/" . $RECIPIENT . "/" . $RECIPIENT . ".mbox";
  }
  
  # Tally Quarantine messages
  if ($USER_PREF ne "off" && -e $MBOX) {					# Check if .mbox file exists and user pref
    chomp($NEW = `grep 'From QUARANTINE $TODAY' $MBOX| wc -l`);			# Count New messages in Quarantine
    push(@Q_NEW_ITEMS, $NEW);							# Send Count to Array for later use
    chomp($TOTAL = `grep 'From QUARANTINE' $MBOX | wc -l`);			# Count Total messages in Quarantine
    push(@Q_TOTAL_ITEMS, $TOTAL);						# Send Count to Array for later use
  } else {                                                              	# .mbox doesn't exist
    push(@Q_NEW_ITEMS, 0);                                              	# insert 0's
    push(@Q_TOTAL_ITEMS, 0);							# keeps indexes in sync
  }
  @USER_DOMAIN = ();								# Destroy Array, no further use
}


# Send some emails
$SMTP = Net::SMTP->new($SERVER);						# Establish SMTP Connection
$I = 0;
for ($I = 0; $I <= $#RECIPIENT_LIST; $I++) {					# Loop through Recipients List and send the message
  if (@Q_TOTAL_ITEMS[$I] != 0) {						# Don't send reminders to users with empty quarantines
    
    $SMTP->mail($FROM);
    $SMTP->to($RECIPIENT_LIST[$I]);
    $SMTP->data();
    $SMTP->datasend("To: $RECIPIENT_LIST[$I]\n");
    $SMTP->datasend("Subject: $SUBJECT\n");
    $SMTP->datasend("Mime-Version: 1.0\n");
    $SMTP->datasend("Content-Type: text/html; charset=UTF-8\n");
    $SMTP->datasend("Quarantine Summary for: $RECIPIENT_LIST[$I]<br>");
    $SMTP->datasend("Date: $TODAY, $YEAR<br>");
    $SMTP->datasend("<br>");
    $SMTP->datasend("  New Messages: @Q_NEW_ITEMS[$I]<br>");
    $SMTP->datasend("Total Messages: @Q_TOTAL_ITEMS[$I]<br>");
    $SMTP->datasend("<br>");
    $SMTP->datasend("<br>");
    $SMTP->datasend("Please remember to check <a href='$QUARANTINE_URL'>Your Quarantine</a> regularly.");
    $SMTP->dataend();
  }
}
$SMTP->quit;									# Close SMTP Connection

