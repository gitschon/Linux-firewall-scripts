# Linux-firewall-scripts
Simple iptables/nftables bash scripts templates.

nftables.sh is a simple script that allows you to generate nftables ruleset automaticaly. This ruleset is sutable for simple internet gateway running on debian 10. 
To use in please fill in the nessesary variables in the script, make nftables.sh executable and run "./nftables.sh start". After that execute "./nftables.sh save"  for the autostart your ruleset with linix. Make sure that you have nftables unit running and activated. Plese execute "systemctl status nftables.service" to be shure.
Be careful if you going to use this script. It was tested and used only in debian 10. And remember, absolutely no warranty!!! You can use it on you own risk.
