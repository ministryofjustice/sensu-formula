{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}
{% from "sensu/lib.sls" import sensu_check,sensu_check_graphite,sensu_check_procs with context %}

{{ sensu_check('apparmor_check', "/etc/sensu/plugins/check-elastic.rb -r 5m -k 'apparmor_rest' -q 'tags:apparmor NOT apparmor_evt:STATUS' -t apparmor  -s 'AppArmor violation! Please check the logs'", subscribers=['monitoring.server'], handlers=["hipchat"], interval=300) }}
{{ sensu_check_procs("cron") }}
{{ sensu_check_procs("collectd") }}

###
### CHECKS --- Root Disk Free Space
### 

# Old Sensu Check - replaced with graphite to ensure aligned reporting
## - sensu_check('check_disk', '/etc/sensu/community/plugins/system/check-disk.rb') 

# Warning at 75% of disk in use (only 25% left free), critical at 90% in use (i.e. only 10% space
# left unreserved)
{{ sensu_check_graphite("used-root-disk", 
                        "'asPercent(metrics.:::metric_prefix:::.df.root.df_complex.used,sum(metrics.:::metric_prefix:::.df.root.df_complex.{free,used}))'",
                        "-a 600",
                        "Root Disk Used Percentage",
                        occurrences=2) }}

###
### CHECKS --- Load
###

# shortterm - warning=1 critical=2
{{ sensu_check_graphite("load-shortterm", 
                        "metrics.:::metric_prefix:::.load.load.shortterm", 
                        "-a 600",
                        "Short Term LoadAve",
                        occurrences=2) }}

# midterm - warning=2 critical=3
{{ sensu_check_graphite("load-midterm", 
                        "metrics.:::metric_prefix:::.load.load.midterm", 
                        "-a 600",
                        "Mid Term LoadAve",
                        occurrences=2) }}

# longterm - warning=2 critical=3
{{ sensu_check_graphite("load-longterm", 
                        "metrics.:::metric_prefix:::.load.load.longterm", 
                        "-a 600",
                        "Long Term LoadAve",
                        occurrences=2) }}


###
### CHECKS --- Memory
###

# mem-used - warning 70% critical 85%
{{ sensu_check_graphite("memory-used",
                        "'asPercent(metrics.:::metric_prefix:::.memory.memory.used,sum(metrics.:::metric_prefix:::.memory.memory.*))'",
                        "-a 600",
                        "Memory Used Percentage",
                        occurrences=2) }}

###
### CHECKS --- Swap
###

# Linux can swap even when there's free mem, so %ages do need to be used, not absolute values
# swap-used - warning 30% critical 50%
{{ sensu_check_graphite("swap-used", 
                        "'asPercent(metrics.:::metric_prefix:::.swap.swap.used,sum(metrics.:::metric_prefix:::.swap.swap.*))'",
                        "-a 600",
                        "Swap Used Percentage",
                        occurrences=2) }}
