# Flud
Cross-platform HUD for quickly getting to apps or files and managing to-do lists.  
Currently supports Windows and Linux.

## Screenshots
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/98940204-2cf7-4f3b-ab7f-30bddb650e8a" />

## Features
- Search for and open installed apps
- Manage multiple lists of tasks using built in to-do lists
- Bind a sequence of keys to shortcuts to get to frequently used apps quickly - or run a custom command
- Search for files by just typing out file paths, with tab autocomplete

## Setup
Releases can be found in the releases tab.  
These will launch the app, but for this to be useful you'll probably want the app to open any time a key combination is pressed. Most Linux desktop environments will support custom keyboard shortcuts out of the box but on Windows this will require other software such as AutoHotKey, and extra configuration to run it at startup.

## Usage
Buttons on the left can be used to add/manage shortcuts and to-dos. Shortcuts can also be added by searching for apps and clicking on the star icon.  
Once the app opens, immediately any typed characters will go into the search bar to search for apps quickly. Pressing space before anything else triggers the shortcuts, and then typing a sequence of characters will launch any existing shortcut.  
Typing out a file path will show files on the system, and allow you to open files or directories using the system's default apps. Presing tab will autofill the first result.
Pressing escape at any time will exit the app.
