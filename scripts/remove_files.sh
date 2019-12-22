#!/bin/sh

files=".dockerignore \
	.git* \
	.travis.yml \
	CHANGELOG.rst \
	Dockerfile \
	README.rst \
	docker-compose.yml \
	docs \
	dpaste/tests \
	tox.ini"

for file in $files; do
	rm -rf ${APP_PATH}/${file}
done
