Perfeito 🔥 — aqui está o arquivo **já convertido para Markdown (`README.md`)**, formatado, bonito e pronto pra colar direto no VS Code (com preview automático).

---

# 📱 Quartinho-PS Mobile

Aplicativo **Flutter** do **Quartinho-PS**, que consome a API Django e usa **WebSockets via Daphne** para chat em tempo real.

Agora o backend pode ser configurado dinamicamente com:

```bash
--dart-define=BACKEND_HOST=http://SEU_IP:8000
```

sem precisar editar o código.

---

## 🧩 Pré-requisitos

* **Flutter SDK** instalado ([guia oficial](https://docs.flutter.dev/get-started/install))
* **Backend Django** rodando com **Daphne**
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

Use `--dart-define=BACKEND_HOST` para informar o IP/porta.

| Ambiente                         | Comando                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------ |
| **Android Emulador**             | `flutter run -d emulator-5554 --dart-define=BACKEND_HOST=http://10.0.2.2:8000` |
| **Celular Físico (mesmo Wi-Fi)** | `flutter run --dart-define=BACKEND_HOST=http://192.168.15.101:8000`            |
| **Web (Chrome)**                 | `flutter run -d chrome --dart-define=BACKEND_HOST=http://127.0.0.1:8000`       |

---

### 3️⃣ Conecte o dispositivo

* **Android:** ative a **Depuração USB** e permita a conexão.
* **iOS:** use um **Mac com Xcode**.

---

### 4️⃣ Verifique permissão de internet (Android)

No arquivo `android/app/src/main/AndroidManifest.xml`, confirme a linha:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

### 5️⃣ Rode o backend com **Daphne (ASGI)**

Agora o chat usa **WebSockets**, então o servidor deve rodar com **Daphne**, não com `runserver`.

```bash
cd backend
.venv\Scripts\Activate.ps1
daphne -b 0.0.0.0 -p 8000 backend.asgi:application
```

> ⚠️ Se usar `python manage.py runserver`, o chat **não funcionará** (WebSocket falhará).

---

### 6️⃣ Execute o app Flutter

```bash
cd mobile
flutter pub get
flutter run -d emulator-5554 --dart-define=BACKEND_HOST=http://10.0.2.2:8000
```

Troque o dispositivo ou o IP conforme necessário.

---

## 💬 WebSocket (Chat)

* O app converte automaticamente `http://` → `ws://`
* Endpoint usado:

  ```
  /ws/chat/?token=JWT_TOKEN
  ```
* O backend **precisa estar com Daphne ativo**

Se ocorrer erro `"Connection reset by peer"`:

* ✅ Verifique se o Daphne está rodando
* ✅ Confirme o IP correto em `--dart-define`
* ✅ Celular e PC estão na **mesma rede Wi-Fi**
* ✅ Firewall do Windows não bloqueia a porta 8000

---

## 🧠 Dicas úteis

* Teste o backend direto no navegador do celular:

  ```
  http://192.168.15.101:8000/api/
  ```
* **Emulador Android:** use `http://10.0.2.2:8000`
* **Celular físico:** use o IP LAN (`192.168.15.101`)
* No Django `settings.py`, mantenha:

  ```python
  ALLOWED_HOSTS = ['*']
  CORS_ALLOW_ALL_ORIGINS = True
  ```

---

## 🐛 Erros comuns

| Erro                              | Causa                            | Solução                                                       |
| --------------------------------- | -------------------------------- | ------------------------------------------------------------- |
| ❌ *“WebSocket connection failed”* | Servidor rodando com `runserver` | Rode com `daphne -b 0.0.0.0 -p 8000 backend.asgi:application` |
| ❌ *“Connection refused”*          | IP incorreto no Flutter          | Corrija `--dart-define=BACKEND_HOST=http://SEU_IP:8000`       |
| ❌ *“User not authenticated”*      | Token JWT inválido               | Refazer login e obter novo token                              |
| ❌ *“DisallowedHost”*              | IP não está em `ALLOWED_HOSTS`   | Adicione `'*'` no settings durante desenvolvimento            |

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
flutter run --dart-define=BACKEND_HOST=http://192.168.15.101:8000
```

---
