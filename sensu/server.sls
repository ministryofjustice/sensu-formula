{% from "sensu/map.jinja" import sensu with context %}
{% from "sensu/lib.sls" import sensu_check_procs with context %}
{% from "sensu/lib.sls" import sensu_check with context %}
{% from 'logstash/lib.sls' import logship with context %}

include:
  - nginx
  - redis
  - rabbitmq
  - apparmor
  - .client
  - .common
  - .deps
  - .checks
# for git


/etc/sensu/conf.d/redis.json:
  file.managed:
    - source: salt://sensu/templates/redis.json
    - template: 'jinja'

sensu-server-extra-pkgs:
  pkg.installed:
    - pkgs:
      - dsd-rubygem-redphone
      - dsd-rubygem-hipchat
      - mailutils
    - skip_verify: True
    - require:
      - pkg: sensu
    - watch_in:
      - service: sensu-server


/etc/sensu/conf.d/api.json:
  file.managed:
    - source: salt://sensu/templates/api.json
    - template: 'jinja'


/etc/sensu/conf.d/dashboard.json:
  file.managed:
    - source: salt://sensu/templates/dashboard.json
    - template: 'jinja'


/etc/sensu/conf.d/handlers.json:
  file.managed:
    - source: salt://sensu/templates/handlers.json
    - template: 'jinja'


sensu-server:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/redis.json
      - file: /etc/sensu/conf.d/rabbitmq.json
      - file: /etc/sensu/conf.d/handlers.json
      - file: /etc/sensu/conf.d/checks/*

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-server:
  file.managed:
    - source: salt://sensu/templates/server_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-server


sensu-api:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/api.json
      - file: /etc/sensu/conf.d/redis.json

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-api:
  file.managed:
    - source: salt://sensu/templates/api_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-api


sensu-dashboard:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/api.json
      - file: /etc/sensu/conf.d/dashboard.json

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-dashboard:
  file.managed:
    - source: salt://sensu/templates/dashboard_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-dashboard

sensu_rabbitmq_user:
  rabbitmq_user.present:
    - name: {{ sensu.rabbitmq.user }}
    - password: {{ sensu.rabbitmq.password }}
    - require:
      - pkg: rabbitmq-server
      - service: rabbitmq-server
    - require_in:
      - service: sensu-api
      - service: sensu-server

#perms are not working so we fall back to owner


sensu_rabbitmq_vhost:
  rabbitmq_vhost.present:
    - name: {{ sensu.rabbitmq.vhost }}
    - owner: {{ sensu.rabbitmq.user }}
    - require_in:
      - service: sensu-api
      - service: sensu-server

{{ logship('sensu-server.log',  '/var/log/sensu/sensu-server.log', 'sensu', ['sensu', 'sensu-server', 'log'],  'rawjson') }}
{{ logship('sensu-api.log',  '/var/log/sensu/sensu-api.log', 'sensu', ['sensu', 'sensu-api', 'log'],  'rawjson') }}
{{ logship('sensu-dashboard.log',  '/var/log/sensu/sensu-dashboard.log', 'sensu', ['sensu', 'sensu-dashboard', 'log'],  'rawjson') }}


/etc/nginx/conf.d/sensu.conf:
  file.managed:
    - source: salt://nginx/templates/vhost-proxy.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - context:
        appslug: sensu
        server_name: sensu.*
        proxy_to: localhost:9876
        is_default: False
    - watch_in:
      - service: nginx


{{ logship('sensu-access',  '/var/log/nginx/sensu.access.json', 'nginx', ['nginx', 'sensu', 'access'],  'rawjson') }}
{{ logship('sensu-error',  '/var/log/nginx/sensu.error.json', 'nginx', ['nginx', 'sensu', 'error'],  'json') }}
