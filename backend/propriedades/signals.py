from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
from django.conf import settings
import logging

from .models import ContratoSolicitacao

logger = logging.getLogger(__name__)


@receiver(pre_save, sender=ContratoSolicitacao)
def contratos_pre_save(sender, instance, **kwargs):
    """Store previous important fields on the instance so post_save can
    detect what changed.
    """
    if not instance.pk:
        # new instance, nothing to read
        instance._old_status = None
        instance._old_contrato_final = False
        instance._old_contrato_assinado = False
        instance._old_comprovante = False
        instance._old_primeiro_aluguel_pago = False
        return
    try:
        old = ContratoSolicitacao.objects.get(pk=instance.pk)
        instance._old_status = old.status
        instance._old_contrato_final = bool(old.contrato_final)
        instance._old_contrato_assinado = bool(old.contrato_assinado)
        instance._old_comprovante = bool(old.comprovante)
        instance._old_primeiro_aluguel_pago = bool(old.primeiro_aluguel_pago)
    except ContratoSolicitacao.DoesNotExist:
        instance._old_status = None
        instance._old_contrato_final = False
        instance._old_contrato_assinado = False
        instance._old_comprovante = False
        instance._old_primeiro_aluguel_pago = False


@receiver(post_save, sender=ContratoSolicitacao)
def contratos_post_save(sender, instance, created, **kwargs):
    """Create in-app notification records and attempt to send FCM when
    relevant contract events happen:
      - new request created -> notify property owner (and confirm to requester)
      - status changed (approved/rejected) -> notify requester
      - contrato_final attached by owner -> notify requester
      - contrato_assinado attached by requester -> notify owner
    """
    try:
        from notificacoes.models import Notificacao
        from notificacoes.utils import send_fcm_to_user
    except Exception:
        Notificacao = None
        send_fcm_to_user = None

    # helper to create local notification + fcm
    def notify(user, message, imovel=None, data=None, title='Quartinho'):
        try:
            if Notificacao is not None:
                Notificacao.objects.create(usuario=user, mensagem=message, imovel=imovel)
        except Exception:
            logger.exception('Failed to create Notificacao record')
        try:
            if send_fcm_to_user is not None:
                send_fcm_to_user(user, title, message, data=data)
        except Exception:
            logger.exception('Failed to send FCM')

    # New contract created
    if created:
        try:
            owner = instance.imovel.proprietario
            msg = f'Novo pedido de contrato para "{instance.imovel.titulo}" por {getattr(instance.solicitante, "nome_completo", str(instance.solicitante))}'
            notify(owner, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id}, title='Novo pedido de contrato')
        except Exception:
            logger.exception('Error notifying owner about new contrato')
        try:
            # confirm to requester
            requester = instance.solicitante
            msg = f'Seu pedido de contrato para "{instance.imovel.titulo}" foi enviado ao proprietário.'
            notify(requester, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id}, title='Pedido enviado')
        except Exception:
            logger.exception('Error notifying requester about created contrato')
        return

    # Not created: detect changes
    # Status change
    old_status = getattr(instance, '_old_status', None)
    if old_status is not None and instance.status != old_status:
        try:
            requester = instance.solicitante
            if instance.status == 'approved':
                msg = f'Seu pedido de contrato #{instance.id} foi aprovado pelo proprietário.'
                notify(requester, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'status': 'approved'}, title='Contrato aprovado')
            elif instance.status == 'rejected':
                msg = f'Seu pedido de contrato #{instance.id} foi recusado pelo proprietário.'
                notify(requester, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'status': 'rejected'}, title='Contrato recusado')
        except Exception:
            logger.exception('Error notifying requester about status change')

    # contrato_final attached
    old_final = getattr(instance, '_old_contrato_final', False)
    if not old_final and bool(instance.contrato_final):
        try:
            requester = instance.solicitante
            msg = f'O proprietário anexou o contrato final para sua solicitação #{instance.id}.'
            notify(requester, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'event': 'contrato_final'}, title='Contrato final anexado')
        except Exception:
            logger.exception('Error notifying requester about contrato_final')

    # contrato_assinado attached by requester
    old_signed = getattr(instance, '_old_contrato_assinado', False)
    if not old_signed and bool(instance.contrato_assinado):
        try:
            owner = instance.imovel.proprietario
            msg = f'O solicitante enviou o contrato assinado para a solicitação #{instance.id}.'
            notify(owner, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'event': 'contrato_assinado'}, title='Contrato assinado enviado')
        except Exception:
            logger.exception('Error notifying owner about contrato_assinado')

    # comprovante attached (in case someone adds later)
    old_comp = getattr(instance, '_old_comprovante', False)
    if not old_comp and bool(instance.comprovante):
        # notify owner that a comprovante was added (if not the owner)
        try:
            owner = instance.imovel.proprietario
            msg = f'Foi enviado um comprovante para a solicitação #{instance.id}.'
            notify(owner, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'event': 'comprovante'}, title='Comprovante enviado')
        except Exception:
            logger.exception('Error notifying owner about comprovante')

    # primeiro_aluguel_pago changed -> notify owner
    old_paid = getattr(instance, '_old_primeiro_aluguel_pago', False)
    if not old_paid and bool(instance.primeiro_aluguel_pago):
        try:
            owner = instance.imovel.proprietario
            msg = f'O solicitante pagou o primeiro aluguel para a solicitação #{instance.id}.'
            notify(owner, msg, imovel=instance.imovel, data={'type': 'contrato', 'contrato_id': instance.id, 'event': 'primeiro_aluguel_pago'}, title='Pagamento recebido')
        except Exception:
            logger.exception('Error notifying owner about primeiro_aluguel_pago')
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