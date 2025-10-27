from django.urls import path
from .views import MessageListCreateView

urlpatterns = [
    path('mensagens/', MessageListCreateView.as_view(), name='mensagens-list-create'),
]
