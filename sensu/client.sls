{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}
{% from "sensu/lib.sls" import sensu_check,sensu_check_host_graphite,sensu_check_procs with context %}

include:
  - .common

/etc/sensu/conf.d/rabbitmq.json:
  file.managed:
    - source: salt://sensu/templates/rabbitmq.json
    - template: jinja


/etc/sensu/conf.d/client.json:
  file.managed:
    - source: salt://sensu/templates/client.json
    - template: jinja

{{ sensu_check('check_mem', '/etc/sensu/plugins/system/check-memory-pcnt.sh -w 70 -c 85') }}
{{ sensu_check('check_disk', '/etc/sensu/plugins/system/check-disk.rb') }}
{{ sensu_check('check_load', '/etc/sensu/plugins/system/check-load.rb -w 1,2,3 -c 2,3,4') }}
{{ sensu_check('check_swap', '/etc/sensu/plugins/system/check-swap-percentage.sh -w 5 -c 25') }}

https://github.com/sensu/sensu-community-plugins.git:
  git.latest:
    - target: /etc/sensu/community
    - require:
      - pkg: sensu_deps


/etc/sensu/plugins:
  file.symlink:
    - target: /etc/sensu/community/plugins
    - force: True
    - require:
      - git: https://github.com/sensu/sensu-community-plugins.git


sensu-plugin:
  gem.installed


{{ sensu_check_host_graphite("free_root_disk", "df.root.df_complex.free", "-w 70000 -a 600") }}
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
