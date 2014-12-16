###

# mem-used - warning 70% critical 85%
{{ sensu_check_graphite("memory-used",
                        "asPercent(metrics.:::metric_prefix:::.memory.memory.used,sum(metrics.:::metric_prefix:::.memory.memory.*))",
                        "-a 600",
                        "Memory Used Percentage",
                        occurrences=2) }}

###
### CHECKS --- Swap
###

# Linux can swap even when there's free mem, so %ages do need to be used, not absolute values
# swap-used - warning 80% critical 95%
# Now we have the swap-out check, this is really checking that we are not getting close to our
# swap limit - and hence risking the OOM killer kicking in.
{{ sensu_check_graphite("swap-used",
                        "asPercent(metrics.:::metric_prefix:::.swap.swap.used,sum(metrics.:::metric_prefix:::.swap.swap.*))",
                        "-a 600",
                        "Swap Used Percentage",
                        occurrences=2,
                        playbook='https://github.com/ministryofjustice/sensu-formula/tree/master/docs/playbooks/swap-used.md'
                        ) }}

# A better check for memory pressure is swap_io.swap-out -- actual paging activity.
# Look at last 15 mins so we don't flap the alert too quickly, but get quick feedback if it
# is resolved.
# Report the integral -- the total amount of paging in the period.
{{ sensu_check_graphite("swap-out",
                        "integral(metrics.:::metric_prefix:::.swap.swap_io.out)",
                        "-a 600 --from -15mins --method max",
                        "Swap Out Total",
                        occurrences=2,
                        playbook='https://github.com/ministryofjustice/sensu-formula/tree/master/docs/playbooks/swap-out.md'
                        ) }}

