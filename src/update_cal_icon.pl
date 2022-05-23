#!/usr/bin/perl

#####################################################
##           Update Ubuntu Calendar Icon           ##
#####################################################
##  Updates the calender icon to current date in   ##
##    Ubuntu 22.04.                                ##
##										           ##
##  Sebastian Lisić - git@lisics.net - 10/23/2022  ##
#####################################################
##                   What it does                  ##       
#####################################################
##  When the update command is used it creates       
##  an icon theme under a temp dir in /tmp. The
##  template SVG is used to generate PNGs for 
##  the current date using the accent colors of 
##  the current user theme. When done the template 
##  is installed to ~/.icons and set to the current
##  theme. The theme inherits the appropriate Yaru
##  theme so all the other icons are unchanged.
##
##  When install-timer is used a user systemd 
##  service and timer is installed to run the
##  script once a day at 00:00:00. The timer is
##  persistent so it will run if the computer was
##  asleep or turned off.
##
##  When remove-timer is run the user systemd
##  service and timer will be removed.
##
######################################################
##                    Known issues                  ##
######################################################
#  System performance may be noticeably affected     
#    during the icon generation.                                                        
######################################################

################
##Instructions##
################
use constant HELP => 
	'Usage: update_cal_icon.pl [command] [options]
		update - update icons
			options:
			--silent - only output errors
			--other-date [weekday,month] (default: weekday)
		install-timer - Install user systemd timer
			options:
			--silent - only output errors
			--other-date [weekday,month] (default: weekday)
			--now - Start timer after installing
		remove-timer - Remove user systemd timer
			options:
			--silent - only output errors
';

use strict;
use warnings;
use utf8;
use Encode qw/encode decode/;
use File::Copy;

#Prefix to know where we are located. Set during install by makefile
use constant APPDIR => '.';

###########
##Globals##
###########

#Get running theme from gsettings
my $currentGtkTheme;
open my $CMD,'-|','/usr/bin/gsettings get org.gnome.desktop.interface gtk-theme' or do {
	warn "Failed to run '/usr/bin/gsettings get org.gnome.desktop.interface gtk-theme': $@";
	exit 1;
};
$currentGtkTheme = <$CMD>;
close $CMD;
#Clean up output
chomp($currentGtkTheme);
$currentGtkTheme =~ s/^'|'$//g;

unless ( $currentGtkTheme )
{
	warn "\nCould not get current GTK theme\n";
	exit 1;
}

#Get current weekday name abbreviation. Using shell command as it has the locale setup already
my $weekDayName;
open $CMD,'-|','/usr/bin/date +%a' or do {
	warn "Failed to run '/usr/bin/date +\%a': $@";
	exit 1;
};
$weekDayName = <$CMD>;
close $CMD;
#Clean up output
chomp($weekDayName);
#To properly uppcase accents, utf8 string must be decoded
$weekDayName = decode('utf-8', $weekDayName);
$weekDayName = ucfirst($weekDayName);
$weekDayName = encode('utf-8', $weekDayName);

unless ( $weekDayName )
{
	warn "\nCould not get current weekday name\n";
	exit 1;
}

#Get current month name abbreviation. Using shell command as it has the locale setup already
my $monthName;
open $CMD,'-|','/usr/bin/date +%b' or do {
	warn "Failed to run '/usr/bin/date +\%b': $@";
	exit 1;
};
$monthName = <$CMD>;
close $CMD;
#Clean up output
chomp($monthName);
#To properly uppcase accents, utf8 string must be decoded
$monthName = decode('utf-8', $monthName);
$monthName = ucfirst($monthName);
$monthName = encode('utf-8', $monthName);

unless ( $monthName )
{
	warn "\nCould not get current month name\n";
	exit 1;
}

my $userIconPath = "$ENV{HOME}/.icons/Calendar-update-$currentGtkTheme"; #Where icon theme is located
my $systemdLocalDir = "$ENV{HOME}/.local/share/systemd"; #Where user systemd files are located

#Get current time
(my $sec, my $min,my $hour, my $mday,my $mon,my $year,my $wday,my $yday, my $isdst) = localtime();

my $templateDir = APPDIR."/templates"; #Dir where templates are located
my $templateName = 'calendar.svg'; #Template file to use to gen icon
my $tempDirRoot = '/tmp'; #Where to create tempdir

#Gen unused temp dir name ( will be under /tmp/ )#
my $tempDirName = "update_ubuntu_calendar_icon.";

while ( 1 )
{
	for ( 1 .. 10 ) 
	{
		$tempDirName = $tempDirName.int(rand(10));
	}

	unless ( -d "$tempDirRoot/$tempDirName" )
	{
		last;
	}
}

#Options
my $silentOutput = 0; #If true, only output errors
my $startTimerNow  = 0; #Run timer after creating it
my $otherDate = 'weekday'; #What the secondary date should be, default weekday
my $accentColor; #The RGB code of the requested accent color, default to nothing

#Icon dirs in the theme
my @iconDirs =
	qw (
			16x16/apps
			16x16@2x/apps
			24x24/apps
			24x24@2x/apps
			32x32/apps
			32x32@2x/apps
			48x48/apps
			48x48@2x/apps
			256x256/apps
			256x256@2x/apps
);

#Names of calendar icon files inside above dirs ( not the symlinks )
my @iconFiles =
	qw (
		calendar-app.png
		x-calendar-app.png
	);

#Symlinks of the above as they exist in the Ubuntu themes
#Actual file, symlink 
my @iconFileSymLinks =
(
	["calendar-app.png","calendar.png"],
	["calendar-app.png","gnome-calendar.png"],
	["calendar-app.png","office-calendar.png"],
	["calendar-app.png","org.gnome.Calendar.png"],
);

#Accent colors taken from the Yaru theme
# Name,RGB
my @accentColors =
(
	["Yaru","#E95420"],
	["Yaru-bark","#787859"],
	["Yaru-sage","#657B69"],
	["Yaru-olive","#4B8501"],
	["Yaru-viridian","#03875B"],
	["Yaru-prussiangreen","#308280"],
	["Yaru-blue","#0073E5"],
	["Yaru-purple","#7764D8"],
	["Yaru-magenta","#B34CB3"],
	["Yaru-red","#DA3450"]
);

############################
##Read command and options##
############################

my $runCommand = $ARGV[0]; # Used to determine which function to run

#Get command or print help
unless ( $runCommand )
{
	print HELP."\n";
	exit
}
unless (
	"update" eq $runCommand or
	"install-timer" eq $runCommand or
	"remove-timer" eq $runCommand 
	)
{
	print HELP."\n";
	exit;	
}

my $commandLineLoopCount = 1;

while ( $commandLineLoopCount < ( int(@ARGV) ) )
{
	if ( "--silent" eq $ARGV[$commandLineLoopCount] )
	#Only print out errors
	{
		$silentOutput = 1;
	}
	elsif ( "--other-date" eq $ARGV[$commandLineLoopCount] and ( "update" eq $runCommand or "install-timer" eq $runCommand ) )
	#Set other date to either weekday or month
	{
		$commandLineLoopCount++;
		if ( "weekday" eq $ARGV[$commandLineLoopCount] )
		{
			$otherDate = 'weekday';
		}
		elsif ( "month" eq $ARGV[$commandLineLoopCount] )
		{
			$otherDate = 'month';
		}
	}
	elsif ( "--now" eq $ARGV[$commandLineLoopCount] and "install-timer" eq $runCommand )
	#Start timer after installing timer
	{
		$startTimerNow = 1;
	}
	else
	{
		warn "Invalid option '$ARGV[$commandLineLoopCount]' for command '$runCommand'\n";
		warn HELP;
		exit 1;
	}

	$commandLineLoopCount++;
}

################
##Run Commands##
################

if ( "update" eq $runCommand ) { update_icon_files(); }
if ( "install-timer" eq $runCommand ) { install_systemd_timer(); }
if ( "remove-timer" eq $runCommand ) { remove_systemd_timer(); }

unless ( $silentOutput )
{
	print "\n";
}

########
##Subs##
########

sub install_systemd_timer
#Install user systemd service and timer
{
	unless ( $silentOutput )
    {
        print "\nCreating user Systemd files";
    }

	#Create local systemd dir if missing
	unless ( -d "$ENV{HOME}/.local" )
	{
		mkdir "$ENV{HOME}/.local" or do {
			warn "Could not create '$ENV{HOME}/.local' $!";
			exit 1;
		}
	}
	unless ( -d "$ENV{HOME}/.local/share" )
	{
		mkdir "$ENV{HOME}/.local/share" or do {
			warn "Could not create '$ENV{HOME}/.local/share' $!";
			exit 1;
		}
	}
	unless ( -d "$ENV{HOME}/.local/share/systemd" )
	{
		mkdir "$ENV{HOME}/.local/share/systemd" or do {
			warn "Could not create '$ENV{HOME}/.local/share/systemd' $!";
			exit 1;
		}
	}
	unless ( -d "$ENV{HOME}/.local/share/systemd/user" )
	{
		mkdir "$ENV{HOME}/.local/share/systemd/user" or do {
			warn "Could not create '$ENV{HOME}/.local/share/systemd/user' $!";
			exit 1;
		}
	}
	
	#Define service and timer file contents
	my $options = "--other-date $otherDate --silent";

        my @systemdServiceFileContents = 
	(
		"[Unit]",
		"Description=Update Calendar Icon to Current Date",
		'OnFailure=mail-systemd-failure@%n.service',
		"",
		"[Service]",
		"Type=oneshot",
		"ExecStart=".APPDIR."/bin/update_cal_icon.pl update ".$options,
		""
	);

	my @systemdTimerFileContents =
	(
		"[Unit]",
		"Description=Daily Update Calander Icon",
		"",
		"[Timer]",
		"Unit=update_calendar_icon.service",
		"OnCalendar=*-*-* 00:00:00",
		"Persistent=true",
		"",
		"[Install]",
		"WantedBy=timers.target",
		""
	);

	#Write files
	my $file;
	open $file, '>:encoding(UTF-8)', "$systemdLocalDir/user/update_calendar_icon.service" or do {
		warn "Could not create $systemdLocalDir/user/update_calendar_icon.service $!";
		exit 1;
	};
    print $file join("\n",@systemdServiceFileContents);
    close $file;
	
	unless ( $silentOutput )
	{
		print "\nCreated $systemdLocalDir/user/update_calendar_icon.service";
	}
	open $file, '>:encoding(UTF-8)', "$systemdLocalDir/user/update_calendar_icon.timer" or do {
		warn "Could not create $systemdLocalDir/user/update_calendar_icon.timer $!";
		exit 1;
	};
	print $file join("\n",@systemdTimerFileContents);
    close $file;

	unless ( $silentOutput )
	{
		print "\nCreated $systemdLocalDir/user/update_calendar_icon.timer\n";
	}

	#Enable timer
	if ( $silentOutput )
	{
		system("/usr/bin/systemctl daemon-reload --user -q") and do {
    		warn "Failed to run '/usr/bin/systemctl daemon-reload --user -q': $?";
    		exit 1;
		};
		system("/usr/bin/systemctl enable --user --now -q update_calendar_icon.timer") and do {
    		warn "Failed to run '/usr/bin/systemctl enable --user --now -q update_calendar_icon.timer': $?";
    		exit 1;
		};
	}
	else
	{
		system("/usr/bin/systemctl daemon-reload --user") and do {
    		warn "Failed to run '/usr/bin/systemctl daemon-reload --user': $?";
    		exit 1;
		};
		system("/usr/bin/systemctl enable --user --now update_calendar_icon.timer") and do {
    		warn "Failed to run '/usr/bin/systemctl enable --user --now update_calendar_icon.timer': $?";
    		exit 1;
		};
	}

	if ( $startTimerNow )
	{
		system("/usr/bin/systemctl start --user update_calendar_icon.service") and do {
    		warn "Failed to run '/usr/bin/systemctl start --user update_calendar_icon.service': $?";
    		exit 1;
		};
	}
	
	unless ( $silentOutput )
	{
		print "\nEnabled and started update_calendar_icon.timer";
	}

}

sub remove_systemd_timer
#Remove user systemd service and timer
{
	unless ( $silentOutput )
	{
		print "\nRemoving user Systemd files\n";
	}

	#Disable timer
	if ( $silentOutput )
	{
		system("/usr/bin/systemctl disable --user -q update_calendar_icon.timer") and do {
    		warn "Failed to run '/usr/bin/systemctl disable --user -q update_calendar_icon.timer': $?";
    		exit 1;
		};
	}
	else
	{
		system("/usr/bin/systemctl disable --user update_calendar_icon.timer") and do {
    		warn "Failed to run '/usr/bin/systemctl disable --user update_calendar_icon.timer': $?";
    		exit 1;
		};
	}

	#Delete files
	unlink "$systemdLocalDir/user/update_calendar_icon.service" or do {
		warn "Could not delete $systemdLocalDir/user/update_calendar_icon.service $!";
		exit 1;
	};
		
	unless ( $silentOutput )
	{
			print "\nDeleted $systemdLocalDir/user/update_calendar_icon.service";
	}

	unlink"$systemdLocalDir/user/update_calendar_icon.timer" or do {
		warn "Could not delete $systemdLocalDir/user/update_calendar_icon.timer $!";
		exit 1;
	};

	unless ( $silentOutput )
	{
		print "\nDeleted $systemdLocalDir/user/update_calendar_icon.timer\n";
	}

	#Reload systemd
	if ( $silentOutput )
	{
		system("/usr/bin/systemctl daemon-reload --user -q") and do {
    		warn "Failed to run '/usr/bin/systemctl daemon-reload --user -q': $?";
    		exit 1;
		};
	}
	else
	{
		system("/usr/bin/systemctl daemon-reload --user") and do {
    		warn "Failed to run '/usr/bin/systemctl daemon-reload --user': $?";
    		exit 1;
		};
	}

	unless ( $silentOutput )
	{
		print "\nDisabled and removed update_calendar_icon.timer";
	}

}

sub update_icon_files
#Update calendar icon files
{
	my $indexThemeFileInheritsLine; #Used to link to proper Ubuntu system theme.
	my $nonDarkTheme; #Theme name without '-dark'. Used for fill and stroke color matching.
	my $accentColor; #Used to store accent color.

	#Set up theme inheritance. 
	if ( "dark" eq substr($currentGtkTheme,-4,4) )
	{
		$nonDarkTheme = substr($currentGtkTheme,0,-5);
		$indexThemeFileInheritsLine = "Inherits=$currentGtkTheme,$nonDarkTheme,Yaru-dark,Humanity,hicolor"; 	
	}
	else
	{
		$nonDarkTheme = $currentGtkTheme;
		$indexThemeFileInheritsLine = "Inherits=$currentGtkTheme,Yaru,Humanity,hicolor"; 	
	}

	#Match accent color based on the currently used theme name.
	for( my $x = 0; $x < int(@accentColors); $x++ )
	{
		if ( $nonDarkTheme eq $accentColors[$x][0] )
		{
			$accentColor = $accentColors[$x][1];
			last;
		}
	}

	#Index file to be used in user icon theme.
	my @indexThemeFileContents =
	(
		"[Icon Theme]",
		"Name=Calendar-update-$currentGtkTheme",
		"Comment=Ubuntu Calendar Update Theme",
		$indexThemeFileInheritsLine,
		"Example=folder",
		'Directories=16x16/apps,16x16@2x/apps,24x24/apps,24x24@2x/apps,32x32/apps,32x32@2x/apps,48x48/apps,48x48@2x/apps,256x256/apps,256x256@2x/apps',
		"",
		"[16x16/apps]",
		"Context=Applications",
		"Size=16",
		"Type=Fixed",
		"",
		'[16x16@2x/apps]',
		"Context=Applications",
		"Scale=2",
		"Size=16",
		"Type=Fixed",
		"",
		"[24x24/apps]",
		"Context=Applications",
		"Size=24",
		"Type=Fixed",
		"",
		'[24x24@2x/apps]',
		"Context=Applications",
		"Scale=2",
		"Size=24",
		"Type=Fixed",
		"",
		"[32x32/apps]",
		"Context=Applications",
		"Size=32",
		"Type=Fixed",
		"",
		'[32x32@2x/apps]',
		"Context=Applications",
		"Scale=2",
		"Size=32",
		"Type=Fixed",
		"",
		"[48x48/apps]",
		"Context=Applications",
		"Size=48",
		"Type=Fixed",
		"",
		'[48x48@2x/apps]',
		"Context=Applications",
		"Scale=2",
		"Size=48",
		"Type=Fixed",
		"",
		"[256x256/apps]",
		"Context=Applications",
		"Size=256",
		"MinSize=64",
		"MaxSize=256",
		"Type=Scalable",
		"",
		'[256x256@2x/apps]',
		"Context=Applications",
		"Scale=2",
		"Size=256",
		"MinSize=64",
		"MaxSize=256",
		"Type=Scalable",
	);

	##Create temp dir to work in##

	#Make dir and sub dirs
	mkdir "$tempDirRoot/$tempDirName" or do
	{
		warn "Could not create '$tempDirRoot/$tempDirName' $!";
		exit 1;
	};
		
	foreach my $iconDir ( @iconDirs )
	{
		my @iconDirSplit = split('/',$iconDir);
		mkdir "$tempDirRoot/$tempDirName/$iconDirSplit[-2]" or do {
			warn "Could not create '$tempDirRoot/$tempDirName/$iconDirSplit[-2]' $!";
			remove_temp_dir();
			exit 1;
		};
			
		mkdir "$tempDirRoot/$tempDirName/$iconDirSplit[-2]/$iconDirSplit[-1]" or do {
			warn "Could not create '$tempDirRoot/$tempDirName/$iconDirSplit[-2]/$iconDirSplit[-1]' $!";
			remove_temp_dir();
			exit 1;
		};
	}

	#Copy template file to temp dir root
	copy("$templateDir/$templateName","$tempDirRoot/$tempDirName/$templateName") or do {
		warn "Copy failed ( $templateDir/$templateName > $tempDirRoot/$tempDirName/$templateName): $!";
		remove_temp_dir();
		exit 1;
	};
		
	##Update the temp template file##

	#Read file
	open my $file, '<:encoding(UTF-8)', "$tempDirRoot/$tempDirName/$templateName" or do {
		warn "Could not open $tempDirRoot/$tempDirName/$templateName $!";
		remove_temp_dir();
		exit 1;
	};
		
	my @templateConents; #Store contents of template

	#Update values in template
	while ( <$file> )
	{
		#Update current day
		$_ =~ s/#D#/$mday/g;

		#Update other date
		if ( "weekday" eq $otherDate )
		{
			$_ =~ s/#OD#/$weekDayName/g;
		}
		elsif ( "month" eq $otherDate )
		{
			$_ =~ s/#OD#/$monthName/g;
		}

		#Update accent colors ( the color #fc8c84 in the template will be replaced )
		$_ =~ s/#fc8c84/$accentColor/g;

		push(@templateConents,$_);
	}

	#Write template file
	open $file, '>', "$tempDirRoot/$tempDirName/$templateName" or do {
		warn "Could not open $tempDirRoot/$tempDirName/$templateName $!";
		remove_temp_dir();
		exit 1;
	};
	print $file join('',@templateConents);
	close $file;

	##Create new image files##
	
	#Flags
	#     -background none #Transparency
	#     -density 300 #Render svg in high dpi for conversion to png
	my $convertFlags = "-background none -density 300";

	#Generate images
	foreach my $iconDir ( @iconDirs )
	{
        foreach my $iconFile ( @iconFiles )
        {
			my $iconSize;

			#Determine icon size from dir name
			my @iconDirSplit = split('/',$iconDir);
			my $tempIconDir = join('/',$tempDirRoot,$tempDirName,$iconDirSplit[-2],$iconDirSplit[-1]);

			if ( '@2x' eq substr($iconDirSplit[-2],-3,3) )
			#Icon is twice the size of the dirname
			{
				my @twiceSplit = split('x',$iconDirSplit[-2]);
				my $newSize = $twiceSplit[0] * 2;
				$iconSize = $newSize."x".$newSize;
			}
			else
			#Icon is the same size as the dir name
			{
				$iconSize = $iconDirSplit[-2];
			}
			
			#Do conversion to PNGs
			system("/usr/bin/convert -resize $iconSize $convertFlags $tempDirRoot/$tempDirName/$templateName $tempIconDir/$iconFile") and do {
    			warn "Failed to run '/usr/bin/convert -resize $iconSize $convertFlags $tempDirRoot/$tempDirName/$templateName $tempIconDir/$iconFile': $?";
				remove_temp_dir();
				exit 1;
			};
		}
	}

	##Copy images to new user theme##
	#Remove old icon theme dir
	system("rm -rf $ENV{HOME}/.icons/Calendar-update-*") and do {
		warn "Failed to run 'rm -rf $ENV{HOME}/.icons/Calendar-update-*': $?";
		remove_temp_dir(); #Clean up what we can
		exit 1;
	};
	#Create user theme dir
	mkdir $userIconPath or do {
		warn "Could not create '$userIconPath$!";
		remove_temp_dir();
		exit 1;
	};
		
	foreach my $iconDir ( @iconDirs )
	{
		my @iconDirSplit = split('/',$iconDir);
		mkdir "$userIconPath/$iconDirSplit[-2]" or do {
			warn "Could not create '$userIconPath/$iconDirSplit[-2]' $!";
			remove_temp_dir();
			exit 1;
		};
			
		mkdir "$userIconPath/$iconDirSplit[-2]/$iconDirSplit[-1]" or do {
			warn"Could not create '$userIconPath$iconDirSplit[-2]/$iconDirSplit[-1]' $!";
			remove_temp_dir();
			exit 1;
		};
	}

	#Write theme.index file
	open $file, '>:encoding(UTF-8)', "$userIconPath/index.theme" or do {
		warn "Could not create $userIconPath/index.theme $!";
		remove_temp_dir();
		exit 1;
	};
    print $file join("\n",@indexThemeFileContents);
    close $file;

	#Copy images#
	foreach my $iconDir ( @iconDirs )
	{
        foreach my $iconFile ( @iconFiles )
        {
			my @iconDirSplit = split('/',$iconDir);
			my $tempIconDir = join('/',$tempDirRoot,$tempDirName,$iconDirSplit[-2],$iconDirSplit[-1]);

			copy("$tempIconDir/$iconFile","$userIconPath/$iconDir/$iconFile") or do {
				warn "Copy failed ( $tempIconDir/$iconFile > $userIconPath/$iconDir/$iconFile): $!";
				remove_temp_dir();
				exit 1;
			};
			
			#See if there are symlinks and create them
			for( my $x = 0; $x < int(@iconFileSymLinks); $x++ )
			{
				if ( $iconFile eq $iconFileSymLinks[$x][0] )
				{
					symlink ( "$iconFile", "$userIconPath/$iconDir/$iconFileSymLinks[$x][1]" ) or do {
						warn "Symlink creation failed ( $userIconPath/$iconDir/$iconFileSymLinks[$x][1]): $!";
						remove_temp_dir();
						exit 1;
					};
					unless ( $silentOutput ) { print "\nCreated symlink $userIconPath/$iconDir/$iconFileSymLinks[$x][1]"; }
				}
			}
			chmod(0644, "$userIconPath/$iconDir/$iconFile") or do {
				warn "Chmod failed ( $userIconPath/$iconDir/$iconFile ): $!";
				remove_temp_dir();
				exit 1;
			};
				
			unless ( $silentOutput ) { print "\nCreated $userIconPath/$iconDir/$iconFile"; }
		}
	}

	##Update theme##
	system("/usr/bin/touch $userIconPath") and do {
		warn "Failed to run '/usr/bin/touch $userIconPath': $?";
		remove_temp_dir();
		exit 1;
	};
	system("/usr/sbin/update-icon-caches $ENV{HOME}/.icons/*") and do {
		warn "Failed to run '/usr/sbin/update-icon-caches $ENV{HOME}/.icons/*': $?";
		remove_temp_dir();
		exit 1;
	};
	#Force icon refresh by applying non-calendar icon theme before update.
	system("/usr/bin/gsettings set org.gnome.desktop.interface icon-theme $currentGtkTheme") and do {
		warn "Failed to run '/usr/bin/gsettings set org.gnome.desktop.interface icon-theme $currentGtkTheme': $?";
		remove_temp_dir();
		exit 1;
	}; 
	system("/usr/bin/gsettings set org.gnome.desktop.interface icon-theme Calendar-update-$currentGtkTheme") and do {
		warn "Failed to run '/usr/bin/gsettings set org.gnome.desktop.interface icon-theme Calendar-update-$currentGtkTheme': $?";
		remove_temp_dir();
		exit 1;
	}; 
	
	remove_temp_dir();
}

sub remove_temp_dir
#Remove temp dir
{
	##Remove temp files##
	foreach my $iconDir ( @iconDirs )
	{
		my @iconDirSplit = split('/',$iconDir);
		my $tempIconDir = join('/',$tempDirRoot,$tempDirName,$iconDirSplit[-2],$iconDirSplit[-1]);

		#Remove files
        foreach my $iconFile ( @iconFiles )
        {
			if ( -f "$tempIconDir/$iconFile" )
			{
				unlink("$tempIconDir/$iconFile") or do {
					warn "Delete failed ( $tempIconDir/$iconFile ): $!";
				};
			}		
		}

		#Remove apps dir
		if ( -d $tempIconDir )
		{
			rmdir "$tempIconDir" or do {
				warn "Delete failed '$tempIconDir' $!";
			};
		}
			
		#Remove parent dir
		if ( -d "/$tempDirRoot/$tempDirName/$iconDirSplit[-2]" )
		{
			rmdir "/$tempDirRoot/$tempDirName/$iconDirSplit[-2]" or do {
				warn "Delete failed '/$tempDirRoot/$tempDirName/$iconDirSplit[-2]' $!";
			};
		}		
	}

	#Remove template file
	if ( -f "$tempDirRoot/$tempDirName/$templateName" )
	{
		unlink("$tempDirRoot/$tempDirName/$templateName") or do {
			warn "Delete failed ( $tempDirRoot/$tempDirName/$templateName): $!";
		};	
	}

	#Remove temp dir root
	if ( -d "$tempDirRoot/$tempDirName" )
	{
		rmdir "$tempDirRoot/$tempDirName" or do {
			warn "Delete failed '$tempDirRoot/$tempDirName' $!";
		};	
	}

}
