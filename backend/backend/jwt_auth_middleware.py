import urllib.parse
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from channels.db import database_sync_to_async
from rest_framework_simplejwt.backends import TokenBackend
from django.conf import settings


class TokenAuthMiddleware:
    """Middleware that takes a token from the query string or headers and authenticates the user for WebSocket connections."""
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        # get token from ?token= or Authorization header
        token = None
        query_string = scope.get('query_string', b'').decode()
        if query_string:
            qs = urllib.parse.parse_qs(query_string)
            token = qs.get('token', [None])[0]

        if not token:
            headers = {k.decode().lower(): v.decode() for k, v in scope.get('headers', [])}
            auth = headers.get('authorization')
            if auth and auth.lower().startswith('bearer '):
                token = auth.split(' ', 1)[1]

        scope['user'] = AnonymousUser()
        if token:
            try:
                tb = TokenBackend(algorithm=getattr(settings, 'SIMPLE_JWT', {}).get('ALGORITHM', 'HS256'),
                                  signing_key=getattr(settings, 'SIMPLE_JWT', {}).get('SIGNING_KEY', settings.SECRET_KEY))
                validated = tb.decode(token, verify=True)
                # SimpleJWT default claim is 'user_id'; support 'id' as fallback
                user_id = validated.get('user_id') or validated.get('id')
                User = get_user_model()
                user = await database_sync_to_async(User.objects.get)(id=user_id)
                scope['user'] = user
            except Exception:
                scope['user'] = AnonymousUser()

        return await self.inner(scope, receive, send)


def TokenAuthMiddlewareStack(inner):
    return TokenAuthMiddleware(inner)
