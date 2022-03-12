# FHEM_GW1000_TCP
Implements a FHEM module that reads GW1000/WH2650 weatherstation data via TCP. It uses the published API from Ecowitt: https://osswww.ecowitt.net/uploads/20210716/WN1900%20GW1000,1100%20WH2680,2650%20telenet%20v1.6.0%20.pdf

This a first working draft that gets Live-Data from the weatherstation (CMD_GW1000_LIVEDATA). There will be probably no further development by me, since my FHEM instance reads weatherstation's data via 868MHz now.

Link to FHEM-discussion: https://forum.fhem.de/index.php/topic,124794.msg1193601.html#msg1193601

Dependency (perl module): IO::Socket::INET


