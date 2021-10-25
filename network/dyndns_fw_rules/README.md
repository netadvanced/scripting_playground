# Dynamic addresses firewall rules updates
I started out with the UFW version on a project, then quickly realised I also needed an IPtables version for the second server. I will eventually merge both files with a flag and improve error control unless you do first, then PR your work, thanks.

# Dynamic IP Firewall rules updates
## dynip_set_ufw.sh
This file will update your firewall rules if you are using UFW.

Background: Unknown contributors found @ http://notepad2.blogspot.com/2012/06/shell-script-update-ufw-rules-for-hosts.html, also found it referenced @ https://rubysash.com/operating-system/linux/bash-script-update-ufw-rule-for-dynamic-host/

I modernized the code to the latest specs and added a hosts.allow handling.
You'll need a few files for this to work:
- /etc/ufw-dynamic-hosts.allow
- /var/tmp/ufw-dynamic-ips.allow
- or adjust the paths and files accordingly in the dynip_set_ufw.sh file

*dynip_set_ufw.sh* should be placed in an executable area where crontab can get to, same goes for file permissions.

*ufw-dynamic-hosts.allow* should contain the host and port details as shown below:
Format: *{prot}:{port}:{dyn_hostname}:{Comments}*
tcp:22:myhost.dynip.whatever:Your name or memo used as comment in rules and hosts.allow file

This file is read and parsed accordingly every few minutes.
