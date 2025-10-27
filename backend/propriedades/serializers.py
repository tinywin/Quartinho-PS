from rest_framework import serializers
from .models import Propriedade, FotoPropriedade, Comentario
from usuarios.serializers import UsuarioSerializer
from .models import ContratoSolicitacao

class ContratoSolicitacaoSerializer(serializers.ModelSerializer):
    solicitante = UsuarioSerializer(read_only=True)
    comprovante = serializers.FileField(required=False, allow_null=True)
    contrato_final = serializers.FileField(required=False, allow_null=True)
    contrato_assinado = serializers.FileField(required=False, allow_null=True)

    class Meta:
        model = ContratoSolicitacao
        fields = ['id', 'imovel', 'solicitante', 'nome_completo', 'cpf', 'telefone', 'comprovante', 'contrato_final', 'contrato_assinado', 'status', 'resposta_do_proprietario', 'data_criacao', 'data_atualizacao']
        read_only_fields = ['id', 'solicitante', 'status', 'data_criacao', 'data_atualizacao']

    def create(self, validated_data):
        request = self.context.get('request')
        if request and getattr(request, 'user', None):
            validated_data['solicitante'] = request.user
        return super().create(validated_data)

    def to_representation(self, instance):
        """Return a representation where `imovel` is a nested object (not only the PK)
        and `comprovante` is an absolute URL when possible. This keeps input as the
        existing `imovel` PK (so mobile code that sends `imovel` as an id continues
        to work) while giving clients richer output for display to owners.
        """
        rep = super().to_representation(instance)
        try:
            # nest the imovel using PropriedadeSerializer (defined later in this module)
            # pass context so serializers can build absolute URLs if request is present
            rep['imovel'] = PropriedadeSerializer(instance.imovel, context=self.context).data
        except Exception:
            # if something goes wrong, keep the original PK value
            rep['imovel'] = rep.get('imovel')

        # Turn file field into an absolute URL when possible
        try:
            request = self.context.get('request') if self.context else None
            if instance.comprovante:
                if hasattr(instance.comprovante, 'url'):
                    url = instance.comprovante.url
                    if request is not None:
                        rep['comprovante'] = request.build_absolute_uri(url)
                    else:
                        rep['comprovante'] = url
            # contrato_final -> absolute URL when present
            if instance.contrato_final:
                if hasattr(instance.contrato_final, 'url'):
                    cfurl = instance.contrato_final.url
                    if request is not None:
                        rep['contrato_final'] = request.build_absolute_uri(cfurl)
                    else:
                        rep['contrato_final'] = cfurl
            # contrato_assinado -> absolute URL when present
            if instance.contrato_assinado:
                if hasattr(instance.contrato_assinado, 'url'):
                    caurl = instance.contrato_assinado.url
                    if request is not None:
                        rep['contrato_assinado'] = request.build_absolute_uri(caurl)
                    else:
                        rep['contrato_assinado'] = caurl
        except Exception:
            # keep whatever representation DRF produced
            pass

        return rep

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