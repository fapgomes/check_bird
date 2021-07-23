# check_bird
This program helps to get the status of the bgp routing program called bird:  https://bird.network.cz/  

Can be used in icinga / icinga2 / nagios / zabbix to monitoring this status.

Example of usage:
/usr/lib64/nagios/plugins/check_bird.pl -p MY_BGP_PEER
BIRD_PROTO OK - MY_BGP_PEER up since 20:35:14.482 with connection Established routes: 96664|'established_routes'=96664;;;0

