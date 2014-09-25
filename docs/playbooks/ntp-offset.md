NTP-offset Playbook
=================

This check finds the average time offset to external NTP servers. So if you are reading this your clock is probably wrong or NTP may not be running.

Resolution
----------

Key things to check:

* `service ntp status` -- check that NTP is running and installed.
* `ntpq -p` -- check the status of the peered NTP servers.
* firewall rules. Can you connect to the servers in `/etc/ntp.conf`?

The check will auto resolve if the clock goes back into sync. Try to force it with `sudo ntpdate -v 0.pool.ntp.org`


Threshold Levels
----------------

The default thresholds for this check are Warning > 0.5s, and Critical > 1s.

Technicals
----------

Collectd connects to the NTP server running locally on UDP 123 and requests stats on the peered servers.

We use graphite to average the offset of all the peers that are reported and then take the absolute of this value.
