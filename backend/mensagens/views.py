from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Message, Conversation
from .serializers import MessageSerializer, ConversationSerializer
from usuarios.models import Usuario


class MessageListCreateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MessageSerializer

    def get(self, request):
        other_id = request.query_params.get('with_user')
        if not other_id:
            return Response({'detail': 'with_user parameter required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            other = Usuario.objects.get(id=other_id)
        except Usuario.DoesNotExist:
            return Response({'detail': 'user not found'}, status=status.HTTP_404_NOT_FOUND)

        # try to find conversation between the two users
        conv = Conversation.objects.filter(participants=request.user).filter(participants=other).first()
        if conv:
            messages = conv.messages.all()
        else:
            # also include direct messages by sender/recipient when no conversation exists
            messages = Message.objects.filter(sender=request.user, recipient=other) | Message.objects.filter(sender=other, recipient=request.user)
            messages = messages.order_by('created_at')

        serializer = MessageSerializer(messages, many=True)
        return Response(serializer.data)

    def post(self, request):
        to_id = request.data.get('to')
        text = request.data.get('text')
        if not to_id or not text:
            return Response({'detail': 'to and text required'}, status=status.HTTP_400_BAD_REQUEST)
        other = get_object_or_404(Usuario, id=to_id)

        # find or create conversation
        conv = Conversation.objects.filter(participants=request.user).filter(participants=other).first()
        if not conv:
            conv = Conversation.objects.create()
            conv.participants.add(request.user)
            conv.participants.add(other)

        msg = Message.objects.create(conversation=conv, sender=request.user, recipient=other, text=text)
        serializer = MessageSerializer(msg)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
