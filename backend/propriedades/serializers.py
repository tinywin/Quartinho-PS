from rest_framework import serializers
from .models import Propriedade, FotoPropriedade, Comentario
from usuarios.serializers import UsuarioSerializer

class FotoPropriedadeSerializer(serializers.ModelSerializer):
    class Meta:
        model = FotoPropriedade
        fields = ['id', 'imagem', 'principal']

class PropriedadeSerializer(serializers.ModelSerializer):
    fotos = FotoPropriedadeSerializer(many=True, read_only=True)
    proprietario = UsuarioSerializer(read_only=True)
    endereco = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)
    comentarios = serializers.SerializerMethodField()
    favorito = serializers.SerializerMethodField()
    
    class Meta:
        model = Propriedade
        fields = [
            'id', 'proprietario', 'titulo', 'descricao', 'tipo', 'preco',
            'endereco', 'cidade', 'estado', 'cep', 'quartos', 'banheiros',
            'area', 'mobiliado', 'aceita_pets', 'internet', 'estacionamento',
            'data_criacao', 'data_atualizacao', 'fotos'
            , 'comentarios',
            'favorito',
        ]
        read_only_fields = ['id', 'data_criacao', 'data_atualizacao', 'proprietario']
    
    def create(self, validated_data):
        return Propriedade.objects.create(**validated_data)
    
    def get_comentarios(self, obj):
        qs = obj.comentarios.all()
        # pass context so ComentarioSerializer can build absolute avatar URLs
        context = self.context if hasattr(self, 'context') else {}
        return ComentarioSerializer(qs, many=True, context=context).data

    def get_favorito(self, obj):
        # retorna True se o usuário na request favoritou este imóvel
        request = self.context.get('request') if self.context else None
        if request is None:
            return False
        user = getattr(request, 'user', None)
        if user is None or not user.is_authenticated:
            return False
        return obj.favoritos.filter(pk=user.pk).exists()

class ComentarioSerializer(serializers.ModelSerializer):
    autor = UsuarioSerializer(read_only=True)
    usuario = serializers.SerializerMethodField()

    class Meta:
        model = Comentario
        fields = ['id', 'imovel', 'autor', 'usuario', 'texto', 'nota', 'data_criacao', 'data_atualizacao']
        read_only_fields = ['autor', 'data_criacao', 'data_atualizacao']

    def get_usuario(self, obj):
        user = obj.autor
        if not user:
            return None

        # try to resolve avatar to a URL/string; avoid returning file objects or bytes
        avatar_val = None
        avatar_field = getattr(user, 'avatar', None)
        try:
            if avatar_field:
                # If avatar is a FileField/ImageField, prefer absolute URL when request context is available
                request = self.context.get('request') if self.context else None
                if hasattr(avatar_field, 'url') and request is not None:
                    avatar_val = request.build_absolute_uri(avatar_field.url)
                elif hasattr(avatar_field, 'url'):
                    avatar_val = avatar_field.url
                else:
                    avatar_val = str(avatar_field)
        except Exception:
            avatar_val = None

        return {
            'id': user.id,
            'nome_completo': getattr(user, 'full_name', None) or getattr(user, 'username', None),
            'first_name': getattr(user, 'first_name', None),
            'username': getattr(user, 'username', None),
            'email': getattr(user, 'email', None),
            'avatar': avatar_val,
        }