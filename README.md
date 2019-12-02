# Docker dpaste

[dpaste](https://github.com/bartTC/dpaste) pastebin running in an Alpine container

## Usage

```
docker run --name dpaste -d -p 8000:8000 moonbuggy2000/dpaste
```

### Environment variables

Environment variables can be specified with the `-e` flag or in `docker-compose.yml`. Available environment variables are:

* ``DB_TYPE`` - accepts `sqlite` (default), `mysql` or `postgres`
* ``DB_HOST`` - databse server hostname or IP
* ``DB_NAME`` - database name
* ``DB_USER`` - database user name
* ``DB_PASSWORD`` - database user password
* ``EXPIRE_DEFAULT`` - default expiry time of snippets in seconds (defaults to 1 month)
* ``SECRET_KEY`` - secret key for signing and hashing
* ``ADMIN_NAME`` - name of the administrator
* ``ADMIN_EMAIL`` - email address of the administrator
* ``DEBUG`` - accepts `True` or `False` (currently defaults to `True`)

None of these environment varaibles are required, although `SECRET_KEY` is a good idea.

#### EXPIRE_DEFAULT

Accepted values for this variable are:

* ``3600`` - 1 hour
* ``86400`` - 1 day
* ``604800`` - 1 week
* ``2678400`` - 1 month (default)

#### DEBUG

When debugging is enabled any errors are displayed client-side, in the web broswer. Assuming the container is configured correctly, this will only be evident on 404 pages.

This currently defaults to `True` because there is some issue with included CSS and JavaScript files when it is disabled. Since the impact of leaving debugging on is minimal I've not yet put the time into troubleshooting these problems.

### Persisting Data

If you wish to manually configure settings you can create a volume at `/app/dpaste/settings/`.

If you're using the SQLite database you'll want to persist the database file by mounting either the folder or the file at `/app/db/database.sqlite3`.
