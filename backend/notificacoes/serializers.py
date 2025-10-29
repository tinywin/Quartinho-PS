from rest_framework import serializers
from .models import Notificacao

class NotificacaoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notificacao
        fields = [
            'id', 
            'usuario', 
            'imovel', 
            'mensagem', 
            'lida', 
            'data_criacao'
        ]