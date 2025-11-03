# Como Limpar Dados Locais - Quartinho

## 🗄️ Dados do Backend
✅ **CONCLUÍDO** - Executado script `backend/scripts/wipe_data.py`
- Usuários apagados: 1
- Propriedades apagadas: 0
- Imóveis apagados: 0

## 🌐 Dados do Web (Navegador)

### Opção 1: Limpar via DevTools (Recomendado)
1. Abra o navegador e acesse `http://localhost:5174/` (quando o servidor estiver rodando)
2. Pressione `F12` para abrir o DevTools
3. Vá na aba **Application** (Chrome) ou **Storage** (Firefox)
4. No painel esquerdo, clique em **Local Storage** → `http://localhost:5174`
5. Clique com botão direito e selecione **Clear** ou delete as chaves:
   - `accessToken` / `access_token`
   - `refreshToken` / `refresh_token` 
   - `userData` / `user_data`
6. Repita para **Session Storage** se houver dados

### Opção 2: Limpar via Console
1. Abra o DevTools (`F12`)
2. Vá na aba **Console**
3. Execute os comandos:
```javascript
// Limpar localStorage
localStorage.removeItem('accessToken');
localStorage.removeItem('access_token');
localStorage.removeItem('refreshToken');
localStorage.removeItem('refresh_token');
localStorage.removeItem('userData');
localStorage.removeItem('user_data');

// Limpar sessionStorage
sessionStorage.clear();

// Verificar se foi limpo
console.log('localStorage keys:', Object.keys(localStorage));
console.log('sessionStorage keys:', Object.keys(sessionStorage));
```

## 📱 Dados do Mobile (Android Emulator)

### Opção 1: Limpar dados do app via Android
1. No emulador, vá em **Settings** → **Apps**
2. Encontre o app **Quartinho** na lista
3. Toque no app → **Storage** → **Clear Data** ou **Clear Storage**
4. Confirme a ação

### Opção 2: Desinstalar e reinstalar
1. No emulador, mantenha pressionado o ícone do app Quartinho
2. Arraste para **Uninstall** ou toque em **App info** → **Uninstall**
3. Na próxima execução com `flutter run`, o app será reinstalado limpo

### Opção 3: Wipe do emulador (mais drástico)
1. Feche o emulador
2. Execute: `flutter emulators --launch Pixel_3 -wipe-data`
3. Isso apagará TODOS os dados do emulador (não apenas do app)

## 🔄 Próxima Execução Limpa

Após limpar os dados:

### Web
```bash
cd web
npm run dev
# Acesse http://localhost:5174/
# Faça novo cadastro/login
```

### Mobile  
```bash
cd mobile
flutter emulators --launch Pixel_3
flutter run -d emulator-5554 --dart-define=BACKEND_HOST=http://10.0.2.2:8000
# Faça novo cadastro/login no app
```

### Backend (se necessário reiniciar)
```bash
cd backend
python manage.py runserver
# Servidor em http://127.0.0.1:8000/
```

---
**Nota:** Os dados do backend já foram limpos automaticamente. Você só precisa limpar os dados locais do navegador e do app mobile conforme as instruções acima.