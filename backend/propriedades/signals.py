# Em propriedades/signals.py (CRIE ESTE ARQUIVO)

from django.db.models.signals import pre_save
from django.dispatch import receiver
from .models import Propriedade
from notificacoes.models import Notificacao # Importe seus modelos

@receiver(pre_save, sender=Propriedade)
def verificar_mudanca_de_preco(sender, instance, **kwargs):
    """
    Este Signal é chamado ANTES de um objeto Propriedade ser salvo.
    """
    
    # Se o 'pk' (id) for None, o objeto está sendo criado, não atualizado.
    # Então, não fazemos nada.
    if instance.pk is None:
        return

    try:
        # Pega a versão "antiga" do imóvel direto do banco de dados
        original = Propriedade.objects.get(pk=instance.pk)
    except Propriedade.DoesNotExist:
        return # Objeto não existe, não faz nada

    # Compara o preço antigo (do banco) com o novo (que está sendo salvo)
    # Vamos assumir que seu campo de preço se chama 'preco'
    if original.preco != instance.preco:
        
        # O PREÇO MUDOU!
        # Agora, encontramos todos os usuários que favoritaram este imóvel.
        # Assumindo que seu campo ManyToMany se chama 'favoritos'
        usuarios_que_favoritaram = instance.favoritos.all()
        
        # Criamos a mensagem
        mensagem = (
            f"Alerta de preço! O imóvel '{instance.titulo}' que você favoritou "
            f"teve o preço alterado de R$ {original.preco} para R$ {instance.preco}."
        )

        # Criamos uma notificação para cada usuário
        for usuario in usuarios_que_favoritaram:
            Notificacao.objects.create(
                usuario=usuario,
                imovel=instance,
                mensagem=mensagem
            )