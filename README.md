# GPO

1. Merge GPO
Does just that - takes seperate GPO's that have been exported to the file system and merges the settings, then re-imports back into GPO Managment (SysVol) 


2. Create MemSrv GPO - AD Groups - Restricted Group - Updates GPO's 
https://www.tenaka.net/post/how-to-create-gpos-with-restricted-groups-using-powershell

Creates a series of GPO's based on Server services eg SCOM or Exhange Sub-OU's
Creates Admin and RDP AD Groups for each Server Service for assiging to Restricted Groups
The newly created OU's have the GPO's assigned and are updated with the SID's for the relevant Service service group for Restricted Groups and URA Remote Desktop



