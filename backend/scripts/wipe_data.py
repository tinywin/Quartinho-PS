import os
import sys

# Garantir que o diretório do projeto e o pacote 'backend' estejam no PYTHONPATH
# Diretórios relevantes
SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
OUTER_BACKEND_DIR = os.path.dirname(SCRIPTS_DIR)  # .../Quartinho-PS/backend
PROJECT_ROOT = os.path.dirname(OUTER_BACKEND_DIR)  # .../Quartinho-PS
INNER_BACKEND_PKG_DIR = os.path.join(OUTER_BACKEND_DIR, 'backend')  # .../Quartinho-PS/backend/backend

# Inserir ambos para garantir import resolvido
for p in [PROJECT_ROOT, OUTER_BACKEND_DIR, INNER_BACKEND_PKG_DIR]:
    if p not in sys.path:
        sys.path.insert(0, p)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

try:
    import django
    django.setup()
except Exception as e:
    print(f"[ERRO] Falha ao inicializar Django: {e}")
    sys.exit(1)

from django.contrib.auth import get_user_model

try:
    from imoveis.models import Imovel
except Exception:
    Imovel = None

try:
    from propriedades.models import Propriedade
except Exception:
    Propriedade = None


def main():
    User = get_user_model()

    # Contagens iniciais
    user_count = User.objects.count()
    imovel_count = Imovel.objects.count() if Imovel else 0
    prop_count = Propriedade.objects.count() if Propriedade else 0

    print(f"[INFO] Usuários existentes: {user_count}")
    print(f"[INFO] Imóveis (imoveis.Imovel) existentes: {imovel_count}")
    print(f"[INFO] Propriedades (propriedades.Propriedade) existentes: {prop_count}")

    # Apagar imóveis e propriedades primeiro para evitar FK
    if Imovel:
        deleted = Imovel.objects.all().delete()
        print(f"[OK] Imóveis apagados: {deleted}")
    else:
        print("[WARN] Modelo Imovel não disponível")

    if Propriedade:
        deleted = Propriedade.objects.all().delete()
        print(f"[OK] Propriedades apagadas: {deleted}")
    else:
        print("[WARN] Modelo Propriedade não disponível")

    # Apagar usuários
    deleted = User.objects.all().delete()
    print(f"[OK] Usuários apagados: {deleted}")

    # Contagens finais
    user_count_after = User.objects.count()
    imovel_count_after = Imovel.objects.count() if Imovel else 0
    prop_count_after = Propriedade.objects.count() if Propriedade else 0

    print(f"[RESUMO] Usuários após: {user_count_after}")
    print(f"[RESUMO] Imóveis após: {imovel_count_after}")
    print(f"[RESUMO] Propriedades após: {prop_count_after}")


if __name__ == '__main__':
    main()