# Overview
Jealous of Mac users with their fancy date accurate calendar icon, keep missing meetings since you somehow always think it's the 28th of the month,
is the static "28" calendar icon driving your OCD mad all but one day of the month?

I have the solution for you my friend, behold, the Update Ubuntu Calendar Icon program. A super duper script that will update your calendar icon
automatically each day.

Not only will you be able to make that important meeting, but now you can make your Mac friends jealous with the following features!

Want the current date and day to show up on your dock icon? Got it!

![Calendar Icon](docs/images/example.png?raw=true "Calendar Icon")

Want the month shown instead of the weekday? Got it!

![Calendar Icon with Month](docs/images/month-ex.png?raw=true "Month")

Theme accents? Got 'em too!

![Calendar Icons with Accents](docs/images/accents-cal-800px.png?raw=true "Accents")

Want to use your local language's day and month names even if they require unicode? Got it! 

![Calendar Icons with Unicode](docs/images/unicode-ex.png?raw=true "Unicode")

Only two dependencies (Inkscape and ImageMagic), everything runs as a regular user, and thanks to the magic of systemd it will run once a day
even if your computer was snoozing or turned off during the night. 

# Install
```console
$ sudo apt install inkscape imagemagick make git
$ mkdir -p ~/src
$ cd ~/src
$ git clone https://github.com/SebLisic/UpdateUbuntuCalendarIcon.git
$ cd UpdateUbuntuCalendarIcon
$ make install
```
# Standard set up ( with weekday and the day's date )
```console
$ ~/UpdateUbuntuCalendarIcon/bin/update_cal_icon.pl install-timer --now
```

# Other set-ups

## I want the month instead of the weekday
```console
$ ~/UpdateUbuntuCalendarIcon/bin/update_cal_icon.pl install-timer --other-date month --now
```

# Uninstall
```console
$ cd ~/src/UpdateUbuntuCalendarIcon
$ make uninstall
```

# Manual Uninstall
```console
$ gsettings set org.gnome.desktop.interface icon-theme Yaru
$ rm -r ~/.icons/Calendar-update-*
$ rm -r ~/UpdateUbuntuCalendarIcon
$ rm ~/.local/share/systemd/user/update_calendar_icon.timer
$ rm ~/.local/share/systemd/user/update_calendar_icon.service
$ systemctl daemon-reload --user
```

# FAQ
## Which versions of Ubuntu are supported?
Only mainline Ubuntu 22.04 LTS is supported. 

## Does this work with non Ubuntu themes
No. This program works by creating an icon theme under ~/.icons/ that inherits the standard themes under /usr/share/icons/. Other icon themes would compete
with that.

# Known Issues
## Going to Gnome Settings -> Appearence resets the icon to the Ubuntu default
Re-run the user service file from the command line, or wait until the next day.
```console
systemctl --user start update_calendar_icon.service
```
## There is a CPU spike when generating icons
This is a consequence of generating PNGs from the SVG template. On modern systems this shouldn't be an issue (on my i7-11370H it takes ~15 seconds), but if you have a low-end system you may want to run the program manually (see above) and determine if you are comfortable with the time it takes.

# Credits
The SVG calendar icon used is a modification of the one from Victor Musienko's [gnome-update-calendar-icon](https://github.com/sdwvit/gnome-update-calendar-icon).
