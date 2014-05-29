include:
  - .deps

sensu:
  pkg.installed


/etc/default/sensu:
  file.managed:
    - source: salt://sensu/files/default_sensu
    - require:
      - pkg: sensu


/etc/sensu:
  file.directory:
    - user: sensu
    - group: sensu
    - mode: 700
    - require:
      - pkg: sensu


# The logic below is pretty warped but it seems like the only way
# for salt to treat a managed directory as idempotent to ensure
# that changes in state are not incorrectly generated.

sensu-confd-checks-clean:
  file.directory:
    - name: /etc/sensu/conf.d/checks
    - clean: True
    - require:
      - pkg: sensu
      - file: /etc/sensu/conf.d/checks

/etc/sensu/conf.d/checks:
  file.directory:
    - require:
      - pkg: sensu
