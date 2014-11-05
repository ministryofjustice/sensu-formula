sensu_deps:
  pkg.installed:
    - pkgs:
      - gcc
      - git
      - build-essential
      - bc # Needed for some of the community check plugins
