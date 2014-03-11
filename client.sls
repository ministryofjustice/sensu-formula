{% from "sensu/map.jinja" import sensu with context %}
{% from 'logging/lib.sls' import logship with context %} 
{% from "sensu/lib.sls" import sensu_check with context %}
include:
  - .common

/etc/sensu/conf.d/rabbitmq.json:
  file:
    - managed
    - source: salt://sensu/templates/rabbitmq.json
    - template: jinja


/etc/sensu/conf.d/client.json:
  file:
    - managed
    - source: salt://sensu/templates/client.json
    - template: jinja

{{ sensu_check('check_mem', '/etc/sensu/plugins/system/check-memory-pcnt.sh -w 70 -c 85') }}
{{ sensu_check('check_disk', '/etc/sensu/plugins/system/check-disk.rb') }}
{{ sensu_check('check_load', '/etc/sensu/plugins/system/check-load.rb -w 1,2,3 -c 2,3,4') }}
{{ sensu_check('check_swap', '/etc/sensu/plugins/system/check-swap-percentage.sh -w 5 -c 25') }}


sensu-client:
  service:
    - running
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/*

{{ logship('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
