# Quartinho-PS Mobile

Este é o aplicativo Flutter do Quartinho-PS, que consome a API Django do backend.
Agora o host do backend pode ser configurado via `--dart-define=BACKEND_HOST=...`, sem editar código.

## Pré-requisitos

- Flutter instalado ([guia oficial](https://docs.flutter.dev/get-started/install))
- Backend Django rodando na mesma rede, com IP acessível pelo celular
- Celular e computador conectados na mesma rede Wi-Fi

## Passos para rodar o app

1. **Descubra o IP do seu computador**
   - No terminal, rode:  
     ```bash
     ip addr show
     ```
   - Procure por um IP do tipo `192.168.x.x` ou `10.0.x.x`.

2. **Configure o host do backend (sem editar código)**
   - Use `--dart-define=BACKEND_HOST`:
     - Emulador Android: `flutter run -d emulator-5554 --dart-define=BACKEND_HOST=http://10.0.2.2:8000`
     - Celular físico (mesma rede): `flutter run --dart-define=BACKEND_HOST=http://SEU_IP:8000`
     - Web (Flutter Web): `flutter run -d chrome --dart-define=BACKEND_HOST=http://127.0.0.1:8000`

3. **Conecte o celular via USB ou use emulador**
   - Para Android: ative a depuração USB e aceite a conexão.
   - Para iOS: use um Mac e siga as permissões do Xcode.

4. **Dê permissão de internet ao app**
   - No Android, confira se há a linha abaixo em `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     ```

5. **Rode o backend Django**
   - No terminal do backend, execute:
     ```bash
     python manage.py runserver 0.0.0.0:8000
     ```
   - O backend ficará acessível em `http://SEU_IP:8000`.

6. **Rode o app Flutter**
   - No terminal do projeto mobile, execute:
     ```bash
     flutter pub get
     flutter run -d emulator-5554 --dart-define=BACKEND_HOST=http://10.0.2.2:8000
     ```
   - Troque o dispositivo ou o host conforme necessário.

## Observações

- O backend precisa estar rodando e acessível pelo IP configurado.
- Se não conseguir acessar, teste no navegador do celular:  
  `http://SEU_IP:8000/api/`
- Em Android Emulator, use `http://10.0.2.2:8000`.
- Em celular físico, use o IP da sua máquina: `http://SEU_IP:8000`.

---

Se tiver dúvidas, consulte a documentação do Flutter ou peça ajuda ao time!