# check_bird
This program helps to get the status of the bgp routing program called bird:  https://bird.network.cz/  

Can be used in icinga / icinga2 / nagios / zabbix to monitoring this status.

Example of usage:
```
/usr/lib64/nagios/plugins/check_bird.pl -p MY_BGP_PEER
BIRD_PROTO OK - MY_BGP_PEER up since 17:03:44.692 with connection   Established    routes: 44749 exported:1 preferred: 44243|'established_routes'=44749;;;0 'exported_routes'=1;;;0 'preferred_routes'=44243;;;0
```
