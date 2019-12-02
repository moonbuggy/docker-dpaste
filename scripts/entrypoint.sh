#!/bin/ash

LOCAL_SETTINGS="/app/dpaste/settings/local.py"
SQLITE_NAME="db/dpaste.sqlite"

# default to debugging enabled
# there's some problem with dpaste.css and dpaste.js staticinline files when
# debugging is disabled, this default can be removed once that problem is resolved
debug_state=True

if [ ! -z ${DEBUG+set} ]; then
	case $DEBUG in
		true|True|yes|on)
			debug_state=True
			;;
		false|False|no|off)
			debug_state=False
			;;
	esac
fi

ad_name="none"
ad_email="none@nowhere.com"

if [ ! -z ${ADMIN_NAME} ]; then
	ad_name=$ADMIN_NAME
fi

if [ ! -z ${ADMIN_EMAIL} ]; then
	ad_email=$ADMIN_EMAIL
fi

sed -E -i "/ADMINS\s*=\s*\(/a \    ('${ad_name}', '${ad_email}')," $LOCAL_SETTINGS

case $debug_state in
	True)
		echo "DEBUG = True" >> $LOCAL_SETTINGS
            ;;
	False)
		sed -E -i "/^[[:blank:]]*DEBUG[[:blank:]]*=[[:blank:]]*\S*[[:blank:]]*$/d" $LOCAL_SETTINGS
		;;
esac

if [ ! -z ${DB_TYPE+set} ]; then
	# remove existing settings
	sed -E -i "/^[[:blank:]]*'(NAME|HOST|USER|PASSWORD)':[[:blank:]]*'\S+',[[:blank:]]*$/d" $LOCAL_SETTINGS

	if [ $DB_TYPE == "mysql" ]; then
		db_type="mysql"
	elif [ $DB_TYPE == "postgres" ] || [ $DB_TYPE == "postgresql" ]; then
		db_type="postgresql"
	else
		db_type="sqlite3"
		DB_NAME=$SQLITE_NAME
	fi
	sed -E -i "s/('ENGINE':\s+'django\.db\.backends\.)(\w*)(',)/\1$db_type\3/" $LOCAL_SETTINGS
fi

if [ ! -z ${DB_NAME+set} ]; then
	sed -E -i "/('ENGINE':\s+'django\.db\.backends\.)(\w*)(',)/a \	'NAME': '$DB_NAME'," $LOCAL_SETTINGS
fi

if [ ! -z ${DB_HOST+set} ]; then
	sed -E -i "/('ENGINE':\s+'django\.db\.backends\.)(\w*)(',)/a \	'HOST': '$DB_HOST'," $LOCAL_SETTINGS
fi

if [ ! -z ${DB_USER+set} ]; then
	sed -E -i "/('ENGINE':\s+'django\.db\.backends\.)(\w*)(',)/a \	'USER': '$DB_USER'," $LOCAL_SETTINGS
fi

if [ ! -z ${DB_PASSWORD+set} ]; then
	sed -E -i "/('ENGINE':\s+'django\.db\.backends\.)(\w*)(',)/a \	'PASSWORD': '$DB_PASSWORD'," $LOCAL_SETTINGS
fi

if [ ! -z ${EXPIRE_DEFAULT+set} ]; then
    sed -E -i "s/(EXPIRE_DEFAULT\s*=\s*)(.*)$/\1$EXPIRE_DEFAULT/" $LOCAL_SETTINGS
fi

if [ ! -z ${SECRET_KEY+set} ]; then
    sed -E -i "s/(SECRET_KEY\s*=\s*')(\S*)(')/\1$SECRET_KEY\3/" $LOCAL_SETTINGS
fi

python3 ./manage.py makemigrations
python3 ./manage.py migrate

/usr/bin/crontab /app/crontab
/usr/sbin/crond -b -l 8

exec "$@"
