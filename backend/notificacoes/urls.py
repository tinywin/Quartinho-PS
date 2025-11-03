from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import NotificacaoViewSet, RegisterDeviceView

router = DefaultRouter()
router.register(r'', NotificacaoViewSet, basename='notificacao')

urlpatterns = [
    path('', include(router.urls)),
    path('register-device/', RegisterDeviceView.as_view(), name='register-device'),
]