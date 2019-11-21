# FermentrackManager
FermentrackManager is a macOS application that manages a Fermentrack installation and allows it to run natively on macOS without the need for a Raspberry Pi server.

Fermentrack is a web application designed to manage and log fermentation temperatures and specific gravity. It is BrewPi compatible and can control fermentation temperatures. It acts as a complete replacement for the web interface used by BrewPi written in Python using the Django web framework. On macOS, it runs inside of the Apache web server.

Fermentrack's homepage: [http://www.fermentrack.com]()

## Requirements

macOS 10.15 (Catalina) or later

## Installation

1. Download the **[Latest Release](https://github.com/corbinstreehouse/FermentrackManager/releases/latest)**
1. **Run.** It detects if you have the requirements to do the install, which are:
	* **Python 3.x**: [https://www.python.org/downloads/mac-osx/]()
	* **Xcode**: [https://apps.apple.com/us/app/xcode/id497799835]()
1. Click **Full Automated Install**

That should be it! Fermentrack will automatically run each time the computer is booted. Fermentrack Manager **does not** need to run; it simply manages the setup.

Fermentrack will be available at [http://localhost:8000/]() (or your machine name).

**TODO**: Add an option to use another port, particularly 80. I avoided port 80 to avoid conflicting with the standard apache install.

## Options

Before running a "Full Automated Install", you can click "Manual Setup and Install" and set up the locations that it will install and run at. I only recommend setting the Installation Directory to an empty folder if you intend to do a full automated install.

You can do a manual install by selecting a home directory that already has Fermentrack setup in it, however, it needs to have the python virtual environment already setup correctly for macOS (TODO: I could add a button that would add a correct python venv, if people want this).

The manual setup also allows the Manager to install redis and the launch daemon. 


## What It Does

The automated install does this:

* Installs a launch daemon, which manages circusd, the web server and redis
* Installs a pre-built copy of redis into the installation directory
* Clones the Fermentrack repository into a sub-directory
* Sets up a python virtual environment
* Makes the secret settings
* Does a migrate on the Django app to set it up
* Collects the static files
* Pings the launch daemon to get started, which creates a setup of the webserver in /var/tmp/fermentrack_apache


## Issues

If you have issues, copy the install log and email me. (corbin at corbinstreehouse dot com) or start a discussion on the Home Brew forums.


## Uninstallation

Currently, this is a manual process, and the order is somewhat important, and will require admin rights:

1. Unload the launch agent from Terminal with:  `sudo launchctl unload /Library/LaunchDaemons/com.redwoodmonkey.FermentrackProcessManager.plist`
1. Delete the launch daemon plist: `sudo rm /Library/LaunchDaemons/com.redwoodmonkey.FermentrackProcessManager.plist`
1. Delete the launch daemon application: `sudo rm /Library/PrivilegedHelperTools/com.redwoodmonkey.FermentrackProcessManager`
1. Stop the web server: `/var/tmp/fermentrack_apache/apachectl stop`
1. Delete the Fermentrack installation; the default location is: `~/Library/Application Support/Fermentrack`
1. (Optionally) Delete the Apache configuration: `/var/tmp/fermentrack_apache'
1. Delete Fermentrack Manager.app





## License

MIT I suppose. 









