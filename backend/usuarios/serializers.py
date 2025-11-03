from rest_framework import serializers
from .models import Usuario
from django.contrib.auth.hashers import make_password
from django.contrib.auth import authenticate

class UsuarioSerializer(serializers.ModelSerializer):
    nome_completo = serializers.CharField(source='username')  # mapeia username
    nome = serializers.CharField(source='username', read_only=True)  # Alias para compatibilidade com Flutter
    password = serializers.CharField(write_only=True)
    avatar = serializers.ImageField(read_only=True)
    foto_perfil = serializers.ImageField(source='avatar', read_only=True)  # Alias para Flutter
    
    class Meta:
        model = Usuario
        fields = ['id', 'nome_completo', 'nome', 'data_nascimento', 'cpf', 'email', 'avatar', 'foto_perfil', 'telefone', 'password']
        read_only_fields = ['id']

    def create(self, validated_data):
        # Hashear a senha
        validated_data['password'] = make_password(validated_data['password'])
        return super().create(validated_data)

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()

    def validate(self, data):
        user = authenticate(email=data['email'], password=data['password'])
        if not user:
            raise serializers.ValidationError("Credenciais inválidas")
        if not user.is_active:
            raise serializers.ValidationError("Usuário desativado")
        return {'user': user}

class UserPreferenceSerializer(serializers.Serializer):
    preference_type = serializers.ChoiceField(choices=['roommate', 'room'])
    user = serializers.PrimaryKeyRelatedField(queryset=Usuario.objects.all(), required=False)

