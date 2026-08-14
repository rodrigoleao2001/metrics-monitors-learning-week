#!/usr/bin/env bash
# Print export lines for the Datadog keys held in the login keychain, so a plain
# terminal can run the lab scripts without the control panel:
#
#     eval "$(./lw-keys.sh)"
#
# Nothing is printed if a key is not stored yet.
SERVICE="learning-week-datadog"
for a in DD_API_KEY DD_APP_KEY; do
    v=$(security find-generic-password -s "$SERVICE" -a "$a" -w 2>/dev/null) || continue
    [ -n "$v" ] && printf 'export %s=%q\n' "$a" "$v"
done
site=$(grep -E '^DD_SITE=' "$(dirname "$0")/.env" 2>/dev/null | cut -d= -f2)
printf 'export DD_SITE=%q\n' "${site:-datadoghq.com}"
