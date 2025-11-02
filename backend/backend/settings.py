"""
Django settings for backend project.
Adaptado para Django + Channels + Flutter LAN/WebSocket.
"""
import redis
from pathlib import Path
import os
try:
    # Load .env from backend/.env for local development if present (optional)
    # This makes it convenient to keep secrets out of the repository while
    # allowing a developer to create a local backend/.env file with keys.
    from dotenv import load_dotenv
    load_dotenv(os.path.join(Path(__file__).resolve().parent.parent, '.env'))
except Exception:
    # python-dotenv is optional; if not installed the environment will still
    # be read from the real environment variables.
    pass
from datetime import timedelta

# Caminho base do projeto
BASE_DIR = Path(__file__).resolve().parent.parent

# ⚙️ Configurações básicas
SECRET_KEY = 'django-insecure-ii$v7zx8ajt@tcqz^4k!de*yufmc)0!09um8m=c*2=1k87ctdr'
DEBUG = True

# 🌍 Permitir acesso via LAN (ex: 192.168.15.101)
ALLOWED_HOSTS = ['*']  # Em dev, permite todos. Em produção, use domínio fixo.

# 📦 Aplicativos instalados
INSTALLED_APPS = [
    # Apps do projeto
    'usuarios',
    'propriedades.apps.PropriedadesConfig',
    'notificacoes',
    'mensagens',

    # Django e libs essenciais
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # REST e autenticação
    'rest_framework',
    'rest_framework_simplejwt',

    # CORS
    'corsheaders',

    # Channels (WebSocket)
    'channels',
]

# 🧩 Middlewares
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',

    # CORS precisa vir antes do CommonMiddleware
    'corsheaders.middleware.CorsMiddleware',

    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# 🌐 URL principal
ROOT_URLCONF = 'backend.urls'

# ⚙️ Configuração do Channels (ASGI)
ASGI_APPLICATION = 'backend.asgi.application'

# Channels sem Redis (modo DEV)
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer"
    },
}

# Template padrão
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# Fallback para WSGI (não usado com Channels, mas necessário p/ admin)
WSGI_APPLICATION = 'backend.wsgi.application'

# 💾 Banco de dados (SQLite para dev)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# 👥 Modelo customizado de usuário
AUTH_USER_MODEL = 'usuarios.Usuario'

# 🔒 Validação de senhas
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# 🌎 Internacionalização
LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
USE_I18N = True
USE_TZ = True

# 🖼️ Arquivos estáticos e de mídia
STATIC_URL = '/static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ⚙️ Configuração do Django REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    )
}

# 🔑 Configuração do JWT (SimpleJWT)
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# 🔥 Firebase (opcional, desativado por padrão)
FIREBASE_CREDENTIALS = None
FIREBASE_CREDENTIALS_JSON = None

# Payment provider keys removed (Mercado Pago / Stripe) — configure providers separately if needed.
# Stripe settings have been removed from this deployment. Configure payment
# providers in a dedicated integration module if needed.

# Mercado Pago access token (optional). Configure in environment for local/dev if you use Mercado Pago.
MERCADO_PAGO_ACCESS_TOKEN = os.getenv('MERCADO_PAGO_ACCESS_TOKEN', None)
# Frontend URL used to build success/cancel URLs for hosted pages (adjust if your frontend runs elsewhere)
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:5173')

# Secret token that can be used by external payment webhooks to authorize
# server-to-server requests that should mark payments as confirmed. If set,
# a webhook can POST to the dedicated confirm_payment action with {'secret': ...}
# to update the contract payment status. Keep this secret out of source control.
PAYMENT_WEBHOOK_SECRET = os.getenv('PAYMENT_WEBHOOK_SECRET', None)

# 🧠 Autenticação customizada
AUTHENTICATION_BACKENDS = [
    'usuarios.auth_backend.EmailOrUsernameModelBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# 🌐 CORS (permite acesso do Flutter Web e Mobile)
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_METHODS = ['DELETE', 'GET', 'OPTIONS', 'PATCH', 'POST', 'PUT']
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

# 🧩 CSRF Trusted Origins — permite requests da LAN e emuladores
CSRF_TRUSTED_ORIGINS = [
    'http://localhost:8000',
    'http://127.0.0.1:8000',
    'http://0.0.0.0:8000',
    'http://192.168.15.101:8000',
]