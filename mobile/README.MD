# 📱 Quartinho-PS Mobile

Bem-vindo(a)! 👋
Este é o aplicativo **Flutter** do **Quartinho-PS**, que consome a API Django e usa **WebSockets via Daphne** para chat em tempo real.

Agora o backend pode ser configurado dinamicamente com:

```bash
--dart-define=BACKEND_HOST=http://SEU_IP:8000
```

sem precisar editar o código.

---

## 🚨 **ATENÇÃO: ARQUIVO ESSENCIAL**

> ⚠️ **Verifique sempre o arquivo:**
> **`mobile/lib/core/constants.dart`**

📍 Esse arquivo define **qual URL o app usa para o backend** (API + WebSocket).
Ele detecta automaticamente se está no **emulador, navegador ou celular físico**, mas:

* Se algo der errado na conexão, **confira se o IP e a porta estão corretos**;
* É nele que ficam as constantes `_hostLan`, `_hostAndroidEmu`, `_hostWeb` etc.

💡 **Dica:**
Se mudar de rede Wi-Fi ou usar outro computador, atualize o IP lá ou use `--dart-define`.

---

## 🧩 Pré-requisitos

* **Flutter SDK** ([guia oficial](https://docs.flutter.dev/get-started/install))
* **Backend Django rodando com Daphne**
* Celular e computador conectados na **mesma rede Wi-Fi**

---

## ⚙️ Passos para rodar o app

### 1️⃣ Descubra o IP da sua máquina

No PowerShell (Windows):

```bash
ipconfig
```

Procure o campo (exemplo):

```
Endereço IPv4 . . . . . . . . . . . : 192.168.xx.xxx
```

---

### 2️⃣ Configure o host do backend (sem editar código)

Use `--dart-define=BACKEND_HOST` para informar o IP/porta:

| Ambiente                   | Comando                                                                  |
| -------------------------- | ------------------------------------------------------------------------ |
| **Android Emulador**       | `flutter run --dart-define=BACKEND_HOST=http://10.0.2.2:8000`            |
| **Celular Físico (Wi-Fi)** | `flutter run --dart-define=BACKEND_HOST=http://192.168.xx.xxx:8000`      |
| **Web (Chrome)**           | `flutter run -d chrome --dart-define=BACKEND_HOST=http://127.0.0.1:8000` |

> 💡 Você não precisa usar `-d emulator-5554` se o Flutter já detectar o dispositivo automaticamente.

---

### 3️⃣ Conecte o dispositivo

* **Android:** ative a **Depuração USB** e aceite a conexão.
* **iOS:** use um **Mac com Xcode**.

---

### 4️⃣ Permissão de internet (Android)

Em `android/app/src/main/AndroidManifest.xml`, confirme:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

### 5️⃣ Rode o backend com **Daphne (ASGI)**

O chat usa WebSockets — por isso **não use `runserver`**.

```bash
cd backend
.venv\Scripts\Activate.ps1
daphne -b 0.0.0.0 -p 8000 backend.asgi:application
```

> ⚠️ Se rodar com `python manage.py runserver`, o chat **não funcionará** (WebSocket falhará).

---

### 6️⃣ Execute o app Flutter

```bash
cd mobile
flutter pub get
flutter run
```

Troque o IP conforme necessário se estiver em celular físico.

---

## 💬 WebSocket (Chat)

* O app converte automaticamente `http://` → `ws://`
* Endpoint usado:

  ```
  /ws/chat/?token=JWT_TOKEN
  ```
* O backend **precisa estar rodando com Daphne**

Se ocorrer `"Connection reset by peer"`:

* ✅ Verifique se o Daphne está ativo
* ✅ Confirme o IP em `--dart-define`
* ✅ Celular e PC estão na **mesma rede**
* ✅ Firewall não bloqueia a porta 8000

---

## 🧠 Dicas úteis

* Teste o backend direto no celular:

  ```
  http://192.168.xx.xxx:8000/api/
  ```
* **Emulador Android:** `http://10.0.2.2:8000`
* **Celular físico:** `http://192.168.xx.xxx:8000`
* No Django `settings.py`:

  ```python
  ALLOWED_HOSTS = ['*']
  CORS_ALLOW_ALL_ORIGINS = True
  ```

---

## 🐛 Erros comuns

| Erro                              | Causa                          | Solução                                                       |
| --------------------------------- | ------------------------------ | ------------------------------------------------------------- |
| ❌ *“WebSocket connection failed”* | Usando `runserver`             | Rode com `daphne -b 0.0.0.0 -p 8000 backend.asgi:application` |
| ❌ *“Connection refused”*          | IP errado no Flutter           | Corrija `--dart-define=BACKEND_HOST=http://SEU_IP:8000`       |
| ❌ *“User not authenticated”*      | Token JWT inválido             | Refazer login                                                 |
| ❌ *“DisallowedHost”*              | IP não está em `ALLOWED_HOSTS` | Adicione `'*'` no settings                                    |

---

## 🚀 Execução Rápida (TL;DR)

```bash
# Backend
cd backend
.venv\Scripts\Activate.ps1
daphne -b 0.0.0.0 -p 8000 backend.asgi:application

# Mobile
cd mobile
flutter pub get
flutter run --dart-define=BACKEND_HOST=http://192.168.xx.xxx:8000
```
