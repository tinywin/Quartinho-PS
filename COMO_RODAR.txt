# 🏠 COMO RODAR – Quartinho-PS

Guia rápido e completo para rodar o projeto: **Backend** (Django), **Web** (React) e **Mobile** (Flutter).

---

## 📋 Pré-requisitos

- **Windows** com PowerShell
- **Python 3.10+** com pip
- **Node.js 18+** com npm  
- **Flutter SDK** 3.35.4+
- **Visual Studio Build Tools** (opcional, só para Flutter Desktop)

---

## 🔧 Backend (Django)

### 📦 Setup Inicial (faça uma vez)

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser  # opcional
```

### 🚀 Rodando o Servidor

Escolha baseado no que você está desenvolvendo:

| Desenvolvimento | Comando | Quando usar |
|----------------|---------|-------------|
| **Web (React)** | `python manage.py runserver 0.0.0.0:8000` | API REST simples |
| **Mobile (Flutter)** | `daphne -b 0.0.0.0 -p 8000 backend.asgi:application` | Precisa de WebSocket (chat) |

### 🌐 URLs Disponíveis

- **Local**: `http://127.0.0.1:8000`
- **Rede (celular físico)**: `http://SEU_IP:8000` (ex: `192.168.15.101:8000`)

### 💡 Dicas

- Use `ALLOWED_HOSTS = ['*']` para desenvolvimento
- Configure `CORS_ALLOW_ALL_ORIGINS = True`
- Adicione hosts em `CSRF_TRUSTED_ORIGINS`

---

## 🌐 Web (React + Vite)

### 📦 Setup e Execução

```powershell
cd web
npm install
npm run dev
```

### 🌐 Acesso

- Geralmente: `http://localhost:5173`
- Vite escolhe porta automática se 5173 estiver ocupada

### ⚙️ Configuração da API

- Arquivo: `web/src/utils/apiConfig.ts`
- Base: `API_BASE_URL = "http://127.0.0.1:8000"`
- Use `127.0.0.1` (não `localhost`) para evitar problemas de IPv6 no Windows

---

## 📱 Mobile (Flutter)

### 📦 Setup Inicial

```powershell
cd mobile
flutter pub get
```

### 🚀 Executar

| Plataforma | Comando |
|-----------|---------|
| **Web (Edge)** | `flutter run -d edge` |
| **Web (Chrome)** | `flutter run -d chrome` |
| **Windows Desktop** | `flutter run -d windows` |
| **Android Emulador** | `flutter run -d emulator-5554` |
| **Android Físico** | `flutter run` (com USB conectado) |

### 🌐 Configuração de Host

Arquivo: `mobile/lib/core/constants.dart`

| Plataforma | URL Backend |
|-----------|-------------|
| Web/Desktop | `http://127.0.0.1:8000` |
| Android Emulador | `http://10.0.2.2:8000` |
| Android/iOS Físico | `http://SEU_IP_LAN:8000` |

**Modo Emulador**:
```powershell
flutter run -d emulator-5554 --dart-define=IS_EMULATOR=true
```

### 💬 WebSocket (Chat)

- Converte automaticamente: `http://` → `ws://` e `https://` → `wss://`
- Endpoint: `/ws/chat/?token=JWT_TOKEN`
- **Importante**: Backend deve rodar com Daphne, não `runserver`

### ⚡ Comandos durante execução (Hot Reload)

Quando o Flutter estiver rodando (`flutter run`), você pode usar:

- **`r`** → Hot Reload (rápido) - Atualiza apenas o código modificado
- **`R`** → Hot Restart (completo) - Reinicia o app do zero, mantém o estado
- **`q`** → Quit - Encerra a execução

💡 Use `r` para mudanças de UI e `R` quando adicionar novos arquivos ou mudar dependências.

---

## 🗺️ Google Maps (Opcional)

### Web (React)

```bash
npm i @react-google-maps/api
```

Arquivo `.env`:
```
VITE_GOOGLE_MAPS_API_KEY=SUA_KEY_AQUI
```

### Mobile (Flutter)

**pubspec.yaml**:
```yaml
dependencies:
  google_maps_flutter: ^2.7.0
```

**Android** (`AndroidManifest.xml`):
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="SUA_KEY_ANDROID" />
```

**iOS** (`AppDelegate.swift`):
```swift
import GoogleMaps
GMSServices.provideAPIKey("SUA_KEY_IOS")
```

---

## 🐛 Troubleshooting

### Backend não conecta
- ✅ Verifique se está rodando em `127.0.0.1:8000`
- ✅ Confirme CORS habilitado
- ✅ Veja console para erros

### WebSocket falha ("not upgraded")
- ✅ Use `daphne` em vez de `runserver`
- ✅ URL deve ser `ws://` (não `http://`)
- ✅ Token JWT válido no query string

### Flutter não encontra backend
- ✅ Emulador Android: use `10.0.2.2:8000`
- ✅ Celular físico: use IP da LAN (mesmo WiFi)
- ✅ Verifique `mobile/lib/core/constants.dart`

### Chat não mostra nome
- ✅ Rode migrations: `python manage.py migrate`
- ✅ Verifique se `UsuarioSerializer` retorna campo `nome`
- ✅ Reinicie Daphne após mudanças no código

---

## ⚡ Comandos Úteis

### Reset do Banco de Dados

```powershell
cd backend
Remove-Item db.sqlite3
python manage.py migrate
python manage.py createsuperuser
```

### Daphne com Auto-reload

```powershell
pip install watchdog
watchmedo auto-restart --directory=./ --pattern=*.py --recursive -- daphne -b 0.0.0.0 -p 8000 backend.asgi:application
```

### Limpar Cache Flutter

```powershell
cd mobile
flutter clean
flutter pub get
```

### Limpar Cache Web

```powershell
cd web
Remove-Item node_modules -Recurse -Force
Remove-Item package-lock.json
npm install
```

### Testar WebSocket Manualmente

```powershell
npm install -g wscat
wscat -c "ws://127.0.0.1:8000/ws/chat/?token=SEU_TOKEN"
```

Enviar mensagem:
```json
{"type":"message","to":2,"text":"Olá!"}
```

### Hot Reload Flutter (durante `flutter run`)

- `r` → Hot reload (rápido)
- `R` → Hot restart (completo)
- `q` → Quit

### Django Shell - Ver Conversas

```powershell
python manage.py shell
```

```python
from mensagens.models import Conversation, Message

# Listar todas as conversas
for c in Conversation.objects.all():
    print(f"ID: {c.id}, Participantes: {[u.email for u in c.participants.all()]}")

# Ver mensagens de uma conversa
conv = Conversation.objects.first()
for m in conv.messages.all():
    print(f"{m.sender.username}: {m.text}")
```

---

## 🔒 Segurança

### Google Maps Keys
- ⚠️ Restrinja keys no Google Cloud Console
- ⚠️ Use diferentes keys para dev/prod
- ⚠️ Nunca commite keys em repositórios públicos

### Django Settings (Produção)
- ⚠️ `DEBUG = False`
- ⚠️ `ALLOWED_HOSTS` específicos
- ⚠️ `SECRET_KEY` em variável de ambiente
- ⚠️ CORS restrito a domínios específicos

---

## 📚 Estrutura do Projeto

```
Quartinho-PS/
├── backend/          # Django + DRF + Channels
│   ├── manage.py
│   ├── backend/      # Settings, URLs, ASGI
│   ├── usuarios/     # Auth, usuários
│   ├── propriedades/ # Imóveis
│   ├── mensagens/    # Chat, WebSocket
│   └── notificacoes/ # Push notifications
├── web/              # React + Vite + TypeScript
│   ├── src/
│   └── package.json
└── mobile/           # Flutter (Android, iOS, Web, Desktop)
    ├── lib/
    ├── android/
    ├── ios/
    └── pubspec.yaml
```

---

## 🎯 Quick Start (TL;DR)

### Primeira vez

```powershell
# Backend
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
daphne -b 0.0.0.0 -p 8000 backend.asgi:application

# Web (nova janela)
cd web
npm install
npm run dev

# Mobile (nova janela)
cd mobile
flutter pub get
flutter run -d edge
```

### Dias seguintes

```powershell
# Backend
cd backend
.venv\Scripts\Activate.ps1
daphne -b 0.0.0.0 -p 8000 backend.asgi:application

# Web
cd web
npm run dev

# Mobile
cd mobile
flutter run
```

---
