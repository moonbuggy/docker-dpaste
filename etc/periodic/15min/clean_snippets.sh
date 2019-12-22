#!/usr/bin/with-contenv /bin/sh

${VIRTUAL_ENV}/bin/python3 ${APP_PATH}/manage.py cleanup_snippets 2>&1
