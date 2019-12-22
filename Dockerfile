ARG ALPINE_VERSION=3.10.3
ARG PYTHON_VERSION=3.7
ARG DPASTE_VERSION=3.4

ARG APP_PATH=/app
ARG VIRTUAL_ENV=${APP_PATH}/venv

# get the source code
#
FROM alpine:$ALPINE_VERSION as source

ARG DPASTE_VERSION
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

RUN apk add --no-cache curl \
	&& curl -o dpaste.tar.gz -L https://github.com/bartTC/dpaste/archive/v${DPASTE_VERSION}.tar.gz \
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
	&& pip install --no-cache-dir django==2.2.9 mysqlclient

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

ENV VIRTUAL_ENV="${VIRTUAL_ENV}" \
	APP_PATH="${APP_PATH}" \
	PYTHON_VERSION="${PYTHON_VERSION}" \
	PATH="${VIRTUAL_ENV}/bin:$PATH" \
	PYTHONPATH="${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/" \
	PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

WORKDIR ${APP_PATH}

COPY --from=builder ${APP_PATH}/ ./
COPY ./etc /etc

RUN apk add --no-cache \
		python3=~${PYTHON_VERSION} \
		mariadb-connector-c-dev \
		mailcap \
	&& python3 ./manage.py collectstatic --noinput

ENTRYPOINT ["/init"]
