{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}

include:
  - firewall
  - bootstrap
  - apparmor
  - logstash.client
  - repos
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

{% for gem_name in sensu.gems %}
install_sensu_{{gem_name}}_gem:
  cmd.run:
    - name: '/opt/sensu/embedded/bin/gem install {{gem_name}}'
    - unless: '/opt/sensu/embedded/bin/ruby -r {{gem_name}} -e exit'
{% endfor %}

# Sensu Community Plugins
https://github.com/sensu/sensu-community-plugins.git:
  git.latest:
    - target: /etc/sensu/community
    - rev: {{ sensu.community_plugins_rev }}
    - require:
      - pkg: sensu_deps

sensu-community-permissions:
  file.directory:
    - name: /etc/sensu/community
    - user: sensu
    - group: sensu
    - mode: 700
    - recurse:
      - user
      - group
      - mode
    - require:
      - git: https://github.com/sensu/sensu-community-plugins.git

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
      - cmd: rest-client
      - cmd: raindrops
    - watch_in:
      - service: sensu-client

raindrops:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install raindrops --no-rdoc --no-ri
    - unless: /opt/sensu/embedded/bin/gem which raindrops >/dev/null 2>/dev/null

rest-client:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install rest-client --no-rdoc --no-ri
    - unless: /opt/sensu/embedded/bin/gem which rest-client >/dev/null 2>/dev/null

sensu-client:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/*
    - order: last

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-client:
  file.managed:
    - source: salt://sensu/templates/client_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-client

# order last as a hask workaround for sensu: Client exits on failure to connect #680
# https://github.com/sensu/sensu/issues/680


{{ logship('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
