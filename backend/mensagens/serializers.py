from rest_framework import serializers
from .models import Message, Conversation
from usuarios.serializers import UsuarioSerializer


class MessageSerializer(serializers.ModelSerializer):
    sender = UsuarioSerializer(read_only=True)
    recipient = UsuarioSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ['id', 'conversation', 'sender', 'recipient', 'text', 'type', 'data', 'created_at']


class ConversationSerializer(serializers.ModelSerializer):
    participants = UsuarioSerializer(many=True, read_only=True)

    class Meta:
        model = Conversation
        fields = ['id', 'participants', 'created_at']
