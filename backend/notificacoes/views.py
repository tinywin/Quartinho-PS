from django.shortcuts import render


from rest_framework import viewsets, permissions, status
from .models import Notificacao
from .serializers import NotificacaoSerializer
from rest_framework.decorators import action
from rest_framework.response import Response

class NotificacaoViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Este endpoint lista e recupera as notificações
    APENAS para o usuário autenticado.
    """
    serializer_class = NotificacaoSerializer
    permission_classes = [permissions.IsAuthenticated] # Exige que o usuário esteja logado

    def get_queryset(self):
        # Filtra o queryset para retornar apenas
        # notificações do usuário logado
        return Notificacao.objects.filter(usuario=self.request.user)
    
    @action(detail=False, methods=['get'])
    def contagem_nao_lida(self, request):
        """
        Retorna apenas a contagem de notificações não lidas
        para o usuário logado.
        """
        # Pega o queryset (que já está filtrado pelo get_queryset)
        queryset = self.get_queryset()
        
        # Filtra mais uma vez por 'lida=False' e pega a contagem
        contagem = queryset.filter(lida=False).count()
        
        # Retorna um JSON simples
        return Response({'count': contagem})
    
    @action(detail=False, methods=['post']) # Usamos POST porque altera dados
    def marcar_todas_como_lidas(self, request):
        """
        Marca todas as notificações não lidas do usuário como lidas.
        """
        # Pega o queryset (já filtrado para o usuário logado)
        queryset = self.get_queryset()
        
        # Filtra pelas não lidas e atualiza o campo 'lida' para True
        queryset.filter(lida=False).update(lida=True)
        
        # Retorna uma resposta de sucesso sem conteúdo
        return Response(status=status.HTTP_204_NO_CONTENT)    
