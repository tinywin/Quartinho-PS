from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Message, Conversation
from .serializers import MessageSerializer, ConversationSerializer
from notificacoes.utils import send_fcm_to_user
from usuarios.models import Usuario
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync


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
        msg_type = request.data.get('message_type') or 'text'
        data = request.data.get('data') or None
        if not to_id:
            return Response({'detail': 'to required'}, status=status.HTTP_400_BAD_REQUEST)
        if msg_type == 'text' and not text:
            return Response({'detail': 'text required for message_type=text'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Validação extra: se for tipo 'imovel', verificar se o imóvel existe
        if msg_type == 'imovel' and isinstance(data, dict):
            imovel_id = data.get('imovel_id')
            if imovel_id:
                try:
                    from propriedades.models import Propriedade
                    if not Propriedade.objects.filter(id=imovel_id).exists():
                        return Response({'detail': 'Imóvel não encontrado'}, status=status.HTTP_404_NOT_FOUND)
                except Exception:
                    pass  # Se o modelo não existir, continuar normalmente
        
        other = get_object_or_404(Usuario, id=to_id)

        # find or create conversation
        conv = Conversation.objects.filter(participants=request.user).filter(participants=other).first()
        if not conv:
            conv = Conversation.objects.create()
            conv.participants.add(request.user)
            conv.participants.add(other)

        msg = Message.objects.create(
            conversation=conv,
            sender=request.user,
            recipient=other,
            text=text or '',
            type=msg_type,
            data=data,
        )
        # create notification record and try to send push (best-effort)
        try:
            from notificacoes.models import Notificacao
            Notificacao.objects.create(usuario=other, mensagem=f'{request.user} te enviou uma mensagem')
        except Exception:
            pass
        try:
            body = 'enviou uma mensagem'
            if msg_type == 'imovel':
                body = 'enviou um imóvel'
            payload = {'type': 'chat', 'conversation': conv.id, 'from_user': request.user.id}
            if msg_type == 'imovel' and isinstance(data, dict) and data.get('imovel_id'):
                payload['imovel'] = data.get('imovel_id')
            send_fcm_to_user(
                other,
                'Nova mensagem',
                f'{getattr(request.user, "nome", str(request.user))} {body}',
                data=payload
            )
        except Exception:
            pass
        serializer = MessageSerializer(msg)
        # Notificar via WebSocket (se destinatário estiver conectado)
        try:
            channel_layer = get_channel_layer()
            if channel_layer is not None:
                async_to_sync(channel_layer.group_send)(
                    f'user_{other.id}',
                    { 'type': 'chat.message', 'message': serializer.data }
                )
        except Exception:
            pass

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class ConversationListView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # list conversations for the user (exclude deleted)
        convs = Conversation.objects.filter(participants=request.user).exclude(deleted_by=request.user).order_by('-created_at')
        data = []
        from usuarios.serializers import UsuarioSerializer
        for c in convs:
            last = c.messages.last()
            # Serializar participantes usando UsuarioSerializer
            participants_data = UsuarioSerializer(c.participants.all(), many=True).data
            data.append({
                'id': c.id,
                'participants': participants_data,
                'last_message': last.text if last else None,
                'updated_at': last.created_at.isoformat() if last else c.created_at.isoformat(),
                'muted': c.muted_by.filter(id=request.user.id).exists(),
            })
        return Response(data)


class ConversationDetailUpdateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        conv = get_object_or_404(Conversation, id=pk, participants=request.user)
        muted = request.data.get('muted')
        deleted = request.data.get('deleted')

        if muted is not None:
            if bool(muted):
                conv.muted_by.add(request.user)
            else:
                conv.muted_by.remove(request.user)
        if deleted is not None and bool(deleted):
            conv.deleted_by.add(request.user)
        return Response({'id': conv.id, 'muted': conv.muted_by.filter(id=request.user.id).exists()})
