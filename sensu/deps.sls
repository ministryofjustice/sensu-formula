sensu_deps:
  pkg.installed:
    - pkgs:
      - gcc
      - git
      - bc # Needed for some of the community check plugins
