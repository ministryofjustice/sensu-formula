{% from "sensu/map.jinja" import sensu with context %}
{% from 'monitoring/logs/lib.sls' import logship2 with context %}
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


sensu-client:
  service:
    - running
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/client.json
      - file: /etc/sensu/conf.d/rabbitmq.json


{{ logship2('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
