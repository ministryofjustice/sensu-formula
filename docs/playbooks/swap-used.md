swap-used Playbook
=================

**swap-used reports that your systems swap file has been used.**

However, the fact that the swap file has been used does not indicate tha the system is in a degraded state.

This check is better thought of as a 'virtual memory capacity' monitor. If there is no available virtual memory,
the Out-Of-Memory (OOM) killer will kick in - generally killing processes that you do not want killed.

Note that once swap has been used, it will often not free up automatically, hence this alarm will require intervention to clear.

Resolution
----------

There can be many reasons why a system has run low on memory and has paged to disk.

Generally if this alert triggers though, one of the following needs to occur:

* The cause of the high virtual memory usage needs to be resolved.
* More memory needs to be assigned to the system
* More swap space needs to be assigned to the system.


Key things to check:

* `free -m` -- show free memory. Are we still low on free memory (inc. cached?)
* `top -o RES` -- show the current high memory processes.
* memory-used graphs -- has something been quickly/slowly eating memory?
* process count graphs -- is there a spike in number of processes?

However, it is possible that the condition that caused swap to be used has cleared. Checking the swap-out graphs should indicate when the paging occurred.

Once this alarm has been triggered, the swap-used value will not drop until the processes that had pages swapped out have been restarted. This usually requires a reboot.

TODO: There may be a way of finding out which processes have pages in the swap file.

Threshold Levels
----------------

The default thresholds for this check are Warning > 80%, and Critical > 95%.

Warning is set to '>80%' to give early warning that we have gotten close to the OOM Killer being required.

Critical is set to '>95%' to highlight that the OOM killer *probably* was called into play, or that it very nearly was. 

