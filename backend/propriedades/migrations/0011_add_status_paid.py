from django.db import migrations


def set_paid_status(apps, schema_editor):
    ContratoSolicitacao = apps.get_model('propriedades', 'ContratoSolicitacao')
    qs = ContratoSolicitacao.objects.filter(primeiro_aluguel_pago=True).exclude(status='paid')
    for c in qs:
        c.status = 'paid'
        c.save(update_fields=['status'])


def unset_paid_status(apps, schema_editor):
    # Attempt to revert 'paid' back to 'approved' for records this migration touched.
    ContratoSolicitacao = apps.get_model('propriedades', 'ContratoSolicitacao')
    qs = ContratoSolicitacao.objects.filter(status='paid')
    for c in qs:
        # only change if primeiro_aluguel_pago is False or leave as approved
        if not c.primeiro_aluguel_pago:
            c.status = 'approved'
            c.save(update_fields=['status'])


class Migration(migrations.Migration):

    dependencies = [
        ('propriedades', '0010_contratosolicitacao_mp_payment_id_and_more'),
    ]

    operations = [
        migrations.RunPython(set_paid_status, reverse_code=unset_paid_status),
    ]
