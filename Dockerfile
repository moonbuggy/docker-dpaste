ARG ALPINE_VERSION="3.13"
ARG NGINX_VERSION="1.18"
ARG PYTHON_VERSION="3.8"
ARG DPASTE_VERSION="3.5"
ARG DPASTE_TARBALL="https://api.github.com/repos/bartTC/dpaste/tarball/v${DPASTE_VERSION}"

ARG APP_PATH="/app"
ARG VIRTUAL_ENV="${APP_PATH}/venv"

ARG FROM_IMAGE="moonbuggy2000/alpine-s6-nginx-uwsgi:${NGINX_VERSION}-alpine${ALPINE_VERSION}"

ARG TARGET_ARCH_TAG="amd64"
ARG QEMU_PREFIX="amd64"

## get the source code
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

WORKDIR "${APP_PATH}"

RUN wget -qO- "${DPASTE_TARBALL}" | tar -xz --strip-components 1 \
	&& for dep in $EXCLUDE_MODS; do \
		sed -e "/^[[:blank:]]*${dep}/d" -i setup.cfg; done \
	&& for file in $REMOVE_FILES; do \
		rm -rf "${APP_PATH}/${file}"; done


## compile static files
#
FROM node:lts-alpine as staticfiles

RUN apk -U add --no-cache \
		bash \
		make

ARG APP_PATH
WORKDIR "${APP_PATH}"

COPY --from=source "${APP_PATH}/package.json" "${APP_PATH}/package-lock.json" "${APP_PATH}/Makefile" ./
COPY --from=source "${APP_PATH}/client" ./client

RUN npm ci --ignore-scripts \
	&& mkdir -p dpaste/static \
	&& make css js


## build the virtual environment
#
FROM "${QEMU_PREFIX}/python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}" as venv_builder

# QEMU static binaries from pre_build
ARG QEMU_DIR
ARG QEMU_ARCH=""
COPY _dummyfile "${QEMU_DIR}/qemu-${QEMU_ARCH}-static*" /usr/bin/

RUN apk -U add --no-cache \
		gcc \
		libffi-dev \
		mariadb-connector-c-dev \
		musl-dev \
		postgresql-dev \
		python3-dev

ARG APP_PATH
WORKDIR "${APP_PATH}"

ARG VIRTUAL_ENV
ENV	VIRTUAL_ENV="${VIRTUAL_ENV}" \
	PYTHONDONTWRITEBYTECODE="1" \
	PYTHONUNBUFFERED="1"

# Python wheels from pre_build
ARG IMPORTS_DIR
ARG TARGET_ARCH_TAG
COPY _dummyfile "${IMPORTS_DIR}/${TARGET_ARCH_TAG}*" "/${IMPORTS_DIR}/"

RUN python3 -m pip install --upgrade virtualenv \
	&& python3 -m virtualenv --download "${VIRTUAL_ENV}"

COPY --from=staticfiles "${APP_PATH}" ./
COPY --from=source "${APP_PATH}/" ./
COPY settings/ dpaste/settings/

# this ENV activates the virtualenv
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"
RUN python3 -m pip install --only-binary=:all: --find-links "/${IMPORTS_DIR}/"  django==2.2.9 mysqlclient \
	|| python3 -m pip install --find-links "/${IMPORTS_DIR}/" django==2.2.9 mysqlclient

RUN python3 -m pip install --only-binary=:all: --find-links "/${IMPORTS_DIR}/"  -e .[production] \
	|| python3 -m pip install --find-links "/${IMPORTS_DIR}/" -e .[production]

#RUN python3 -m pip install --find-links "/${IMPORTS_DIR}/" django==2.2.9 mysqlclient \
#	&& python3 -m pip install --find-links "/${IMPORTS_DIR}/" -e .[production]

RUN mkdir db \
	&& ln -sf /usr/bin/python3 "${VIRTUAL_ENV}/bin/python"


## build the image
#
FROM "${FROM_IMAGE}" AS builder

# QEMU static binaries from pre_build
ARG QEMU_DIR
ARG QEMU_ARCH=""
COPY _dummyfile "${QEMU_DIR}/qemu-${QEMU_ARCH}-static*" /usr/bin/

ARG APP_PATH
WORKDIR "${APP_PATH}"

COPY --from=venv_builder "${APP_PATH}/" ./
COPY ./etc /etc

ARG PYTHON_VERSION
RUN apk -U add --no-cache \
		python3=~"${PYTHON_VERSION}" \
		mariadb-connector-c-dev \
		mailcap

ARG VIRTUAL_ENV
RUN add-contenv \
		PATH="${VIRTUAL_ENV}/bin:$PATH" \
		APP_PATH="${APP_PATH}" \
		PYTHON_VERSION="${PYTHON_VERSION}" \
		PYTHONPATH="${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/" \
		VIRTUAL_ENV="${VIRTUAL_ENV}" \
		PYTHONDONTWRITEBYTECODE="1" \
		PYTHONUNBUFFERED="1"

RUN . /etc/contenv_extra \
	&& python3 ./manage.py collectstatic --noinput

RUN rm -f "/usr/bin/qemu-${QEMU_ARCH}-static" >/dev/null 2>&1


## drop the QEMU binaries
#
FROM "moonbuggy2000/scratch:${TARGET_ARCH_TAG}"

COPY --from=builder / /

ENTRYPOINT ["/init"]

HEALTHCHECK --start-period=10s --timeout=10s \
	CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/nginx-ping && echo 'okay' || exit 1
