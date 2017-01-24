##Using "wvdial" to connect to WWAN using Point-to-Point Protocol:##


The connection to Internet is accomplished through wvdial. wvdial uses a 
config file wvdial.conf. The wvdial application is started by udev when 
it finds a WWAN modem being attached to the system. This is accomplished 
using the 75-wwan-net.rules file. 

##Setup:##


**As root -**
 1. Copy 75-wwan-net.rules to */etc/udev/rules.d/*
 2. Copy wvwaggle.sh to */usr/bin/*, and make it executable with *chmod +x /usr/bin/wvwaggle.sh*
 3. Copy wvdial.conf to */etc/*
 4. reload udevrules - *udevadm control --reload-rules*

After the above steps, connect the modem and the system should attempt to get 
network connection ___30-35 seconds___  after the modem is plugged in.

A successful network connection will show up under ___ppp0___  entry  when *ifconfig* is issued. 


