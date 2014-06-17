{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}
{% from "sensu/lib.sls" import sensu_check,sensu_check_graphite,sensu_check_procs with context %}

include:
  - apparmor
  - logstash.client
  - .common

/etc/sensu/conf.d/rabbitmq.json:
  file.managed:
    - source: salt://sensu/templates/rabbitmq.json
    - template: jinja
    - mode: 644


/etc/sensu/conf.d/client.json:
  file.managed:
    - source: salt://sensu/templates/client.json
    - template: jinja
    - mode: 644

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
                        "Root Disk Used Percentage") }}

###
### CHECKS --- Load
###

# shortterm - warning=1 critical=2
{{ sensu_check_graphite("load-shortterm", 
                        "metrics.:::metric_prefix:::.load.load.shortterm", 
                        "-a 600",
                        "Short Term LoadAve") }}

# midterm - warning=2 critical=3
{{ sensu_check_graphite("load-midterm", 
                        "metrics.:::metric_prefix:::.load.load.midterm", 
                        "-a 600",
                        "Mid Term LoadAve") }}

# longterm - warning=2 critical=3
{{ sensu_check_graphite("load-longterm", 
                        "metrics.:::metric_prefix:::.load.load.longterm", 
                        "-a 600",
                        "Long Term LoadAve") }}


###
### CHECKS --- Memory
###

# mem-used - warning 70% critical 85%
{{ sensu_check_graphite("memory-used",
                        "'asPercent(metrics.:::metric_prefix:::.memory.memory.used,sum(metrics.:::metric_prefix:::.memory.memory.*))'",
                        "-a 600",
                        "Memory Used Percentage") }}

###
### CHECKS --- Swap
###

# Linux can swap even when there's free mem, so %ages do need to be used, not absolute values
# swap-used - warning 30% critical 50%
{{ sensu_check_graphite("swap-used", 
                        "'asPercent(metrics.:::metric_prefix:::.swap.swap.used,sum(metrics.:::metric_prefix:::.swap.swap.*))'",
                        "-a 600",
                        "Swap Used Percentage") }}


# Sensu Community Plugins
https://github.com/sensu/sensu-community-plugins.git:
  git.latest:
    - target: /etc/sensu/community
    - rev: {{ sensu.community_plugins_rev }}
    - require:
      - pkg: sensu_deps

sensu_plugins_remove_symlink:
  cmd.run:
    # We used to have the community plugins installed in /etc/sensu/community
    # and symlinked to /etc/sensu/plugins. We don't want that anymore but need
    # to remove the symlink first
    - name: rm /etc/sensu/plugins
    - onlyif: '[ -L /etc/sensu/plugins ]'

# Locally created plugins
/etc/sensu/plugins:
  file.recurse:
    - source: salt://sensu/files/plugins
    - include_empty: True
    - clean: True
    - user: sensu
    - group: sensu
    - file_mode: 700
    - dir_mode: 700
    - require:
      - cmd: sensu_plugins_remove_symlink


sensu-plugin:
  gem.installed


{{ sensu_check_procs("cron") }}
{{ sensu_check_procs("collectd") }}

sensu-client:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/*
    - order: last

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-client:
  file.managed:
    - source: salt://sensu/files/client_apparmor_profile
    - template: 'jinja'
    - watch_in:
       - command: reload-profiles
       - service: sensu-client


# order last as a hask workaround for sensu: Client exits on failure to connect #680
# https://github.com/sensu/sensu/issues/680



{{ logship('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
