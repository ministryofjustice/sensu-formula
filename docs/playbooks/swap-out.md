swap-out Playbook
=================

**swap-out reports that your system has paged memory out to the swap device in the last 15 minutes.**

Our systems are generally configured so that paging is unlikely: sufficient memory, low swappiness.

Hence, if this check fires, we likely have a system that is not performing optimally.

Resolution
----------

There can be many reasons why a system has run low on memory and is paging to disk.

Key things to check:

* `top -o RES` -- show the current high memory processes.
* memory-used graphs -- has something been quickly/slowly eating memory?
* process count graphs -- is there a spike in number of processes?

The check itself will often resolve itself when the paging stops. It is likely that during the paging, other performance issues (such as slower page response times) may have been reported. Any paging activity needs to be understood and addressed.

If the check remains in error state, the system is *thrashing* (constantly paging to disk), and the cause should be assertained immediately.

Threshold Levels
----------------

The default thresholds for this check are Warning > 0, and Critical > 50.

Warning is set to '>0' to ensure that any paging activity is recorded. Our systems are generally configured to avoid paging where possible, so this is a good indication that something is awry.

The Critical alert can be set on a system-by-system basis, but 50 is a good starting point for indicating that a system has paged heavily in the last 15 minutes.


Technicals
----------

Collectd reads the 'pswpout' value from `/proc/vmstat`, and turns this
into a pages-per-second value.

We read this from Graphite as an integral(), hence the total amount of paging
in the given period.
