FROM python:3.7.5-alpine as builder

ENV DPASTE_VERSION 3.2

RUN apk add --no-cache \
		curl \
		gcc \
		git \
		libffi-dev \
		musl-dev \
		npm \
		postgresql-dev \
	&& pip3 install pipenv

WORKDIR /dpaste

RUN curl -o dpaste.tar.gz -L https://github.com/bartTC/dpaste/archive/v${DPASTE_VERSION}.tar.gz \
	&& tar -xf dpaste.tar.gz --strip-components 1 \
	&& rm -f dpaste.tar.gz \
	&& mkdir db

RUN ash -c "PIPENV_VENV_IN_PROJECT=1 pipenv install django~=2.1.14 jsx-lexer~=0.0.7 pymysql psycopg2-binary"

RUN	npm install	\
	&& npm run build

COPY settings/ dpaste/settings/

RUN echo "SECRET_KEY = '$(tr -dc 'a-z0-9!@#$%^&*(-_=+)' < /dev/urandom | head -c50)'" >> dpaste/settings/local.py

FROM alpine:3.10

RUN apk add --no-cache \
		python3==3.7.5-r1 \
		postgresql-dev
	
ENV PYTHONPATH="/app/.venv/lib/python3.7/site-packages/"

COPY --from=builder /dpaste /app
COPY /scripts/ /app/

WORKDIR /app

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["python3", "./manage.py", "runserver", "0.0.0.0:8000"]
