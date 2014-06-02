{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}
{% from "sensu/lib.sls" import sensu_check,sensu_check_graphite,sensu_check_procs with context %}

include:
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

# Collectd generates disk free metrics per byte so need to multiply by 1024*1024*1024
# Warning at 10Gb free space, Critical at 5Gb
{{ sensu_check_graphite("free-root-disk", 
                        "metrics.:::metric_prefix:::.df.root.df_complex.free", 
                        "--below -w 10737418240 -c 5368709120 -a 600",
                        "Root Disk Full") }}

###
### CHECKS --- Load 
###

# Old Sensu Check - replaced with graphite to ensure aligned reporting
# - sensu_check('check_load', '/etc/sensu/community/plugins/system/check-load.rb -w 1,2,3 -c 2,3,4') 

# shortterm - warning=1 critical=2
{{ sensu_check_graphite("load-shortterm", 
                        "metrics.:::metric_prefix:::.load.load.shortterm", 
                        "-w 1 -c 2 -a 600",
                        "Short Term LoadAve") }}

# midterm - warning=2 critical=3
{{ sensu_check_graphite("load-midterm", 
                        "metrics.:::metric_prefix:::.load.load.midterm", 
                        "-w 2 -c 3 -a 600",
                        "Mid Term LoadAve") }}

# longterm - warning=2 critical=3
{{ sensu_check_graphite("load-longterm", 
                        "metrics.:::metric_prefix:::.load.load.longterm", 
                        "-w 3 -c 4 -a 600",
                        "Long Term LoadAve") }}



{{ sensu_check('check_mem', '/etc/sensu/community/plugins/system/check-memory-pcnt.sh -w 70 -c 85') }}

###
### CHECKS --- Swap
###

# Old Sensu Check - replaced with graphite to ensure aligned reporting
# - sensu_check('check_swap', '/etc/sensu/community/plugins/system/check-swap-percentage.sh -w 5 -c 25') 

# We should never be in swap so percentages are not required. 
# swap-used - warning=20M critical=100M
{{ sensu_check_graphite("swap-used", 
                        "metrics.:::metric_prefix:::.swap.swap.used", 
                        "-w 20971520 -c 104857600 -a 600",
                        "Swap In Used") }}


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

# order last as a hask workaround for sensu: Client exits on failure to connect #680
# https://github.com/sensu/sensu/issues/680



{{ logship('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
