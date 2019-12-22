#/bin/sh

SETUP_FILE=/app/setup.cfg

for dep in $EXCLUDE_MODS; do
	sed -E -i "/^[[:blank:]]*${dep}/d" $SETUP_FILE
done

