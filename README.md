# GPO

Merge GPO
Does just that - takes seperate GPO's that have been exported to the file system and merges the settings, then re-imports back into GPO Managment (SysVol) 




Create MemSrv sub-ous Restricted Groups and update GPOs with 
This is only draft and requires testing, better explanation to come.....

Creates a series of GPO's based on Server services eg SCOM or Exhange Sub-OU's
Creates Admin and RDP AD Groups for each Server Service for assiging to Restricted Groups
The newly created OU's have the GPO's assigned and are updated with the SID's for the relevant Service service group for Restricted Groups and URA Remote Desktop



