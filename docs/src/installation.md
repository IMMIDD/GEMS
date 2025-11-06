
# [Full Installation Guide](@id installation)

We recommend using VSCode to work with GEMS.   
In case you are new to Julia or VSCode, you might need to install and setup additional software to run GEMS.
But don't worry! Please check out the installation guide below for further information about how to setup the environment for your simulations.

## Windows

In order to run the framework, please install the following.

### 1. Installing Julia
The GEMS framework was developed under Julia v.1.11.3. 
 
1. Download the Windows installer for version v.1.11.3 of [Julia](https://julialang.org/downloads/) from the JuliaLang website.
2. Run the installer and follow the on-screen instructions. You can generally accept the default settings. However, make sure to check the option to add the PATH variable automatically, which is NOT selected by default. Otherwise, you'll have to configure it manually as explained below. Setting the PATH variable for all users requires administration rights, so the installation of the software packages might need to be done by your IT department. If you're installing the software just for yourself, user rights are sufficient.

!!! info "Note"
     You can also download the latest version of Julia (if there is any newer version available), but it might cause dependency issues during the installation of GEMS that have to be resolved manually. If you run into this issue, please consult the GEMS development team.

A system reboot might be required after installation.

### 2. Installing MiKTex and Pandoc (optional)
!!! info "Exporting Simulation Reports as pdf-Files"
     The automated simulation report generator requires Pandoc and a TeX distribution, while the HTML report does not need additional software. If the pdf-file is requested, please install the following:
     - [Pandoc](https://pandoc.org/installing.html)
     - [MiKTeX](https://miktex.org/download) (or any other distribution containing xelatex)


**MiKTeX**

1. Visit the [MiKTeX](https://miktex.org/download) website.
2. Download the MiKTeX Installer for Windows.
3. Run the installer and choose the "Install MiKTeX" option.
4. Follow the on-screen instructions to complete the installation. Generally, you can accept the default settings. However, consider changing the "ask me first" option to prevent multiple confirmation requests when installing additional packages the first time you run GEMS.


**Pandoc**

1. Visit the [Pandoc](https://pandoc.org/installing.html) website.
2. Download the Windows Installer for Pandoc (the name ends with windows-x86_64.msi).
3. Run the installer and follow the on-screen instructions. Generally, you can accept the default settings

### 3. Installing VSCode

1. Visit the [Visual Studio Code](https://code.visualstudio.com/download) website.
2. Download the Windows installer for Visual Studio Code.
3. Run the installer and follow the on-screen instructions. Generally, you can accept the default settings.

### 4. Checking Path Variables

All previously mentioned software packages require a PATH system variable to function correctly. It is therefore worthwhile to ensure that these have been configured correctly at this point.
1. Open the Start menu and search for "Environment Variables".
2. Click on "Edit the system environment variables." (If you do not have admin rights or have installed the software only for your account and not system-wide use the "Environment Variables for this account" option instead).
3. In the System Properties window, click the "Environment Variables" button.
4. In the "System Variables" section, scroll down and find the "Path" variable. Select it and click "Edit".
5. Check that an entry for all software packages exists.


To ensure that your system can make use of all software packages you have installed, you should reboot it at this point.

### 5. VS Code Extensions

To use Julia in VS Code. You need to install the Julia extension for VS Code.
1. Open Visual Studio Code.
2. Go to the Extensions view by clicking the square icon on the sidebar or pressing Ctrl + Shift + X.
3. Search for "Julia" in the Extensions view search bar.
4. Install the "Julia" extension provided by the JuliaLang organization.
5. You can now start the Julia REPL by pressing Alt + J + O in Visual Studio Code. If you are encountering errors consult the troubleshooting at the bottom.


Congratulations! You successfully set up the coding environment to use GEMS.


## Mac OS

### 1. Installing Julia
The GEMS framework was developed under Julia v.1.11.3. 

1. Visit the [Julia](https://julialang.org/downloads/) website.
2. Download the MacOS installer (usually a .dmg file) for your MacOS system for version v.1.11.3, i.e., the newest version, of Julia.
3. Locate the downloaded '.dmg' file and double click on it to mount the disk image. The julia application icon should now be visible, drag the icon to the "Applications" folder to install it. Setting the PATH variable for all users requires administration rights, so the installation of the software packages might need to be done by your IT department. If you're installing the software just for yourself, user rights are sufficient.

!!! info "Note"
     You can also download the current version of Julia by using the terminal . Start the terminal , execute the following command:
     ```
     curl -fsSL https://install.julialang.org | sh
     ```

**Configuring PATH for Julia**

If you want to launch Julia from the command line, first open a new terminal window, then run the following snippet from your shell (e.g., using the Terminal app, not inside the Julia prompt).
```
sudo mkdir -p /usr/local/bin
sudo rm -f /usr/local/bin/julia
sudo ln -s /Applications/Julia-1.10.app/Contents/Resources/julia/bin/julia /usr/local/bin/julia
```
To launch Julia, simply type 'julia' inside your shell and press return.

### 2. Installing MiKTex and Pandoc (optional)
!!! info "Exporting Simulation Reports as pdf-Files"
     The automated simulation report generator requires Pandoc and a TeX distribution, while the HTML report does not need additional software. If the pdf-file is requested, please install the following:
     - [Pandoc](https://pandoc.org/installing.html)
     - [MacTeX](https://tug.org/mactex/mactex-download.html) (or any other distribution containing xelatex)


**MiKTeX**

1. Visit the [MacTeX](https://tug.org/mactex/mactex-download.html) website.
2. Download the MacTex Installer.
3. Run the installer and follow the on-screen instructions to complete the installation.
4. A folder named TeX should now be visible in your Applications folder.


**Pandoc**

1. Visit the [Pandoc](https://pandoc.org/installing.html) website.
2. Download the macOS Installer for Pandoc (usually a '.pkg' file ).
3. Run the installer and follow the on-screen instructions. Generally, you can accept the default settings.

### 3. Installing VSCode

1. Visit the [Visual Studio Code](https://code.visualstudio.com/download) website.
2. Download the Mac installer for Visual Studio Code.
3. Open the downloaded file and drag the Visual Studio Code icon to the Applications folder to complete the installation.

### 4. Checking Path Variables

All previously mentioned software packages require a PATH system variable to function correctly. It is therefore worthwhile to ensure that these have been configured correctly at this point.
1. Open the terminal and type the following commands:

```
which tex
```
It should be typically something like /Library/TeX/texbin/tex.


```
which pandoc
```
It should be something like /usr/local/bin/pandoc.


```
which code
```
It should be something like /usr/local/bin/code.

To ensure that your system can make use of all software packages you have installed, you should reboot it at this point.

### 5. VS Code Extensions

To use Julia in VS Code. You need to install the Julia extension for VS Code.
1. Open Visual Studio Code.
2. Go to the Extensions view by clicking the square icon on the sidebar or pressing Cmd + Shift + X.
3. Search for "Julia" in the Extensions view search bar.
4. Install the "Julia" extension provided by the JuliaLang organization.
5. You can now start the Julia REPL in Visual Studio by pressing Cmd + Shift + P to open the command palette and typing "Julia: Start REPL".


Congratulations! You successfully set up the coding environment to use GEMS.