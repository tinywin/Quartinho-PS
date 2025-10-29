from django.apps import AppConfig


class PropriedadesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'propriedades'
    
    def ready(self):
            # Importa o módulo de signals quando o app estiver pronto
            import propriedades.signals