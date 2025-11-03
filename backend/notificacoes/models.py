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


class Device(models.Model):
    """Device registration to receive push notifications via FCM."""
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='devices')
    registration_id = models.CharField(max_length=512)
    platform = models.CharField(max_length=32, null=True, blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('usuario', 'registration_id')

    def __str__(self):
        return f'Device {self.usuario_id} - {self.platform}'