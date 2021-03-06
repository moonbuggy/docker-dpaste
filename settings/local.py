from dpaste.settings.base import *

ADMINS = (
)
MANAGERS = ADMINS

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': 'db/database.sqlite3',
    }
}

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

#INSTALLED_APPS += ('sslserver',)

# Optionally run the runserver as `manage.py runsslserver` to locally
# test correct cookie and csp behavior.
if not 'runsslserver' in sys.argv:
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False

from dpaste.apps import dpasteAppConfig
from django.utils.translation import ugettext_lazy as _

class ProductionDpasteAppConfig(dpasteAppConfig):
	SLUG_LENGTH = 8
	LEXER_DEFAULT = 'js'
	EXPIRE_CHOICES = (
		('onetime', _(u'One Time Snippet')),
		(3600, _(u'Expire in one hour')),
		(3600 * 24, _('Expire in one day')),
		(3600 * 24 * 7, _('Expire in one week')),
		(3600 * 24 * 31, _('Expire in one month')),
		('never', _('Never')),
	)
	EXPIRE_DEFAULT = 2678400

INSTALLED_APPS.remove('dpaste.apps.dpasteAppConfig')
INSTALLED_APPS.append('dpaste.settings.local.ProductionDpasteAppConfig')

DEBUG = False
