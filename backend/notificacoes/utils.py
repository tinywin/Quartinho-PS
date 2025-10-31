import logging
from django.conf import settings

logger = logging.getLogger(__name__)

def try_init_firebase():
    try:
        import firebase_admin
        from firebase_admin import credentials
        if not firebase_admin._apps:
            cred_path = getattr(settings, 'FIREBASE_CREDENTIALS', None)
            cred_json = getattr(settings, 'FIREBASE_CREDENTIALS_JSON', None)
            if cred_path:
                cred = credentials.Certificate(cred_path)
            elif cred_json:
                cred = credentials.Certificate(cred_json)
            else:
                logger.warning('No Firebase credentials configured')
                return None
            firebase_admin.initialize_app(cred)
        return firebase_admin
    except Exception as e:
        logger.exception('Failed to init firebase: %s', e)
        return None

def send_fcm_notification_to_registration(registration_id, title, body, data=None):
    firebase_admin = try_init_firebase()
    if not firebase_admin:
        return False
    try:
        from firebase_admin import messaging
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=registration_id,
            data=data or {},
        )
        resp = messaging.send(message)
        logger.info('FCM sent: %s', resp)
        return True
    except Exception:
        logger.exception('Failed to send FCM')
        return False

def send_fcm_to_user(user, title, body, data=None):
    # best-effort: loop through device registrations
    try:
        from .models import Device
        devices = Device.objects.filter(usuario=user)
        for d in devices:
            send_fcm_notification_to_registration(d.registration_id, title, body, data)
    except Exception:
        logger.exception('Failed to send fcm to user')