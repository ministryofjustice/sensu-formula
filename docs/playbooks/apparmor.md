Apparmor Playbook
=================

This check runs against ElasticSearch, relying on Logstash to be correctly parsing and
marking up auditd and apparmor messages.

Resolution
----------

Search in Kibana for: 'tags:apparmor NOT apparmor_evt:STATUS' - this is the query that the
check is performing.

This will give you a better indication of the number and type of apparmor issues we are seeing.

Then, try to categorise them, and find which subsystems are problematic. The
'apparmor_kvdata_profile' field should give you this information.

Unfortunately after than, you need to figure out exactly what is happening. Typically they are
false positives, eg nginx not configured to allow it to read static files. However, it could
be a valid intrusion, so please do investigate and fix known false positives.

NB: most will have an 'apparmor=ALLOWED' field. This is because we are generally running in
warning mode - so the transaction is allowed but if we were in enforce mode it would not be.
Look at the other fields (eg denied_mask) for the actual failed operation.


Threshold Levels
----------------

This alerts on any apparmor messages found in ES in the last 30 mins.

Technicals
----------

This all surrounds the 'audit' and 'apparmor' processing of syslog and auditd in Logstash. See
logstash-formula for more info.
