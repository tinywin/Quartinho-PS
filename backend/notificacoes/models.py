# Em propriedades/models.py (ou em um novo app)


from propriedades.models import Propriedade
from django.db import models
from django.conf import settings # Importa as configurações


class Notificacao(models.Model):
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notificacoes')
    
    # O imóvel que gerou a notificação
    imovel = models.ForeignKey('propriedades.Propriedade', on_delete=models.CASCADE, null=True, blank=True)

    mensagem = models.TextField()
    
    # Para sabermos se o usuário já leu
    lida = models.BooleanField(default=False)
    
    data_criacao = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Notificação para {self.usuario.username}: {self.mensagem[:30]}...'

    class Meta:
        ordering = ['-data_criacao']
        verbose_name_plural = "Notificações"