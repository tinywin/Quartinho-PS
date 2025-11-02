from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import PropriedadeViewSet, ComentarioViewSet, ContratoSolicitacaoViewSet
from . import views

router = DefaultRouter()
router.register(r'propriedades', PropriedadeViewSet)
router.register(r'comentarios', ComentarioViewSet)
router.register(r'contratos', ContratoSolicitacaoViewSet)

urlpatterns = [
    path('', include(router.urls)),
    # Payment webhooks removed
    path('propriedade/<int:propriedade_id>/favoritar/', views.favoritar_propriedade, name='favoritar_propriedade'),
    path('favoritos/', views.lista_favoritos, name='lista_favoritos'),    
]