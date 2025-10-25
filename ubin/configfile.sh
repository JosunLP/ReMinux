-- example of a user shortcut.
-- files placed in this location can be created by users, making shortcuts that display in the menu to.
-- in this case, we are simply telling edit to open the settings file, but you could add any lua code in here

shell.run("/bin/edit.sh /usr/minux-main/settings.cfg")
