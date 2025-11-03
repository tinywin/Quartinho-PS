from django.urls import path
from .views import MessageListCreateView, ConversationListView, ConversationDetailUpdateView

urlpatterns = [
    path('mensagens/', MessageListCreateView.as_view(), name='mensagens-list-create'),
    path('conversations/', ConversationListView.as_view(), name='conversations-list'),
    path('conversations/<int:pk>/', ConversationDetailUpdateView.as_view(), name='conversations-detail-update'),
]
