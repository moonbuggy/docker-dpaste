ARG ALPINE_VERSION=3.11.6
ARG PYTHON_VERSION=3.8
ARG DPASTE_VERSION=3.5
ARG DPASTE_TARBALL="https://api.github.com/repos/bartTC/dpaste/tarball/v${DPASTE_VERSION}"

ARG APP_PATH=/app
ARG VIRTUAL_ENV=${APP_PATH}/venv

# get the source code
#
FROM moonbuggy2000/fetcher:latest as source

ARG DPASTE_TARBALL
ARG APP_PATH

ENV EXCLUDE_MODS="\
	pytest \
	pytest-cov \
	pytest-django \
	tox"

ENV REMOVE_FILES=".dockerignore \
	.git* \
	.travis.yml \
	CHANGELOG.rst \
	Dockerfile \
	README.rst \
	docker-compose.yml \
	docs \
	dpaste/tests \
	tox.ini"

WORKDIR ${APP_PATH}

RUN wget -qO dpaste.tar.gz ${DPASTE_TARBALL} \
	&& tar -xf dpaste.tar.gz --strip-components 1 \
	&& rm -f dpaste.tar.gz \
	&& for dep in $EXCLUDE_MODS; do \
		sed -e "/^[[:blank:]]*${dep}/d" -i setup.cfg; done \
	&& for file in $REMOVE_FILES; do \
		rm -rf ${APP_PATH}/${file}; done


# compile static files
#
FROM node:lts-alpine as staticfiles

ARG APP_PATH

RUN apk add --no-cache \
		bash \
		make

WORKDIR ${APP_PATH}

COPY --from=source ${APP_PATH}/package.json ${APP_PATH}/package-lock.json ${APP_PATH}/Makefile ./
COPY --from=source ${APP_PATH}/client ./client

RUN npm ci --ignore-scripts \
	&& mkdir -p dpaste/static \
	&& make css js


# build the virtual environment
#
FROM python:${PYTHON_VERSION}-alpine as builder

ARG VIRTUAL_ENV
ARG APP_PATH

ENV PATH="${VIRTUAL_ENV}/bin:$PATH" \
	PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

RUN apk add --no-cache \
		gcc \
		libffi-dev \
		mariadb-connector-c-dev \
		musl-dev \
		postgresql-dev \
		py3-virtualenv

WORKDIR ${APP_PATH}

RUN python3 -m venv $VIRTUAL_ENV \
	&& pip install --no-cache-dir --upgrade pip \
	&& pip install --no-cache-dir wheel django==2.2.9 mysqlclient

RUN set -x && which pip && which pip3

COPY --from=staticfiles ${APP_PATH} ${APP_PATH}/
COPY --from=source ${APP_PATH}/ ./
COPY settings/ dpaste/settings/

RUN pip install --no-cache-dir -e .[production] \
	&& mkdir db \
	&& ln -sf /usr/bin/python3 ${VIRTUAL_ENV}/bin/python3 \
	&& echo "SECRET_KEY = '$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)'" >> dpaste/settings/local.py


# create the final image
#
FROM moonbuggy2000/alpine-s6-nginx-uwsgi:$ALPINE_VERSION

ARG PYTHON_VERSION
ARG VIRTUAL_ENV
ARG APP_PATH

ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

WORKDIR ${APP_PATH}

COPY --from=builder ${APP_PATH}/ ./
COPY ./etc /etc

RUN	add-contenv \
		APP_PATH=${APP_PATH} \
		PYTHON_VERSION=${PYTHON_VERSION} \
		VIRTUAL_ENV=${VIRTUAL_ENV} \
		PYTHONPATH=${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/ \
		PYTHONDONTWRITEBYTECODE=1 \
		PYTHONUNBUFFERED=1\
	&& apk add --no-cache \
		python3=~${PYTHON_VERSION} \
		mariadb-connector-c-dev \
		mailcap \
	&& source /etc/contenv_extra \
	&& python3 ./manage.py collectstatic --noinput

ENTRYPOINT ["/init"]
