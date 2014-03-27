sensu:
  pkg:
    - installed


/etc/default/sensu:
  file:
    - managed
    - source: salt://sensu/files/default_sensu
    - require:
      - pkg: sensu


/etc/sensu/conf.d/checks:
  file:
    - directory
    - require:
      - pkg: sensu

