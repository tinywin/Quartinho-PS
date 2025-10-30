# Quartinho Web (Vite)

## Desenvolvimento

- Instale dependências: `npm install`
- Crie `.env` baseado em `web/.env.example`:
  - `VITE_API_BASE_URL=http://127.0.0.1:8000`
  - `VITE_GOOGLE_CLIENT_ID=...` (opcional)
  - `VITE_FACEBOOK_APP_ID=...` (opcional)
- Rode: `npm run dev`. Acesse `http://localhost:5174/`.

## Configuração de API e autenticação

- O base URL da API é lido de `VITE_API_BASE_URL` no `.env`.
- Há uma instância Axios com interceptors que:
  - Anexão automática de `Authorization: Bearer <accessToken>`.
  - Refresh do token em `401` usando `/usuarios/token/refresh/`.
  - Limpa sessão e redireciona para `/email-login` se o refresh falhar.
- Chaves de armazenamento adotadas: `accessToken`, `refreshToken`, `userData` (mantemos compatibilidade com `access_token`, `refresh_token`, `user_data`).

## Login social

- Configure `VITE_GOOGLE_CLIENT_ID` e/ou `VITE_FACEBOOK_APP_ID` no `.env`.
- Reinicie o servidor após alterar `.env`.

## Notas

- Algumas telas antigas podem usar `axios` direto; a instância global `http` está disponível em `src/utils/apiConfig.ts` para migração gradual.
