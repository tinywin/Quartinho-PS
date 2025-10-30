// Utilitários para login social com Google e Facebook
import axios from 'axios';
import { API_BASE_URL } from '../utils/apiConfig';
import { saveTokens, saveUserData } from './auth';

// Obtém ID do cliente do Google do ambiente
const GOOGLE_CLIENT_ID = (import.meta as any).env?.VITE_GOOGLE_CLIENT_ID || '';
const FACEBOOK_APP_ID = (import.meta as any).env?.VITE_FACEBOOK_APP_ID || '';

export const loginWithGoogle = async (): Promise<void> => {
  if (!GOOGLE_CLIENT_ID) {
    throw new Error('VITE_GOOGLE_CLIENT_ID não configurado. Defina em web/.env: VITE_GOOGLE_CLIENT_ID=SEU_CLIENT_ID_DO_GOOGLE e reinicie com npm run dev.');
  }

  // Carregar SDK se necessário
  await new Promise<void>((resolve, reject) => {
    const g = (window as any).google?.accounts?.id;
    if (g) return resolve();
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Falha ao carregar Google SDK'));
    document.head.appendChild(script);
  });

  const idToken = await new Promise<string>((resolve, reject) => {
    try {
      const google = (window as any).google.accounts.id;
      google.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: (resp: any) => {
          const cred = resp?.credential;
          if (!cred) {
            reject(new Error('Credencial Google não recebida'));
            return;
          }
          resolve(cred);
        },
      });
      // Mostra o prompt One Tap
      google.prompt((notification: any) => {
        if (notification?.isNotDisplayed() || notification?.isSkippedMoment()) {
          // Usuário fechou ou não exibiu, falhar graciosamente
          reject(new Error('Login Google não concluído'));
        }
      });
    } catch (e) {
      reject(e);
    }
  });

  const response = await axios.post(`${API_BASE_URL}/usuarios/social/google/`, { id_token: idToken });
  const data = response.data;
  const tokens = data?.tokens || { access: data?.access, refresh: data?.refresh };
  const user = data?.user;
  if (!tokens?.access) throw new Error('Access token não retornado');

  // Salva nos formatos novos e antigos para compatibilidade
  saveTokens(tokens.access, tokens.refresh);
  localStorage.setItem('access_token', tokens.access);
  localStorage.setItem('refresh_token', tokens.refresh || '');
  saveUserData(user);
  localStorage.setItem('user_data', JSON.stringify(user));
};

export const loginWithFacebook = async (): Promise<void> => {
  if (!FACEBOOK_APP_ID) {
    throw new Error('VITE_FACEBOOK_APP_ID não configurado. Defina em web/.env: VITE_FACEBOOK_APP_ID=SEU_APP_ID_DO_FACEBOOK e reinicie com npm run dev.');
  }

  // Carregar SDK se necessário e inicializar
  await new Promise<void>((resolve, reject) => {
    const FB = (window as any).FB;
    if (FB && FB.init) return resolve();
    const script = document.createElement('script');
    script.src = 'https://connect.facebook.net/en_US/sdk.js';
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Falha ao carregar Facebook SDK'));
    document.head.appendChild(script);
  });

  await new Promise<void>((resolve) => {
    const FB = (window as any).FB;
    FB.init({
      appId: FACEBOOK_APP_ID,
      cookie: true,
      xfbml: false,
      version: 'v19.0',
    });
    resolve();
  });

  const accessToken: string = await new Promise((resolve, reject) => {
    const FB = (window as any).FB;
    FB.login(
      (response: any) => {
        try {
          const t = response?.authResponse?.accessToken;
          if (!t) return reject(new Error('Access token Facebook não recebido'));
          resolve(t);
        } catch (e) {
          reject(e);
        }
      },
      { scope: 'email' }
    );
  });

  const response = await axios.post(`${API_BASE_URL}/usuarios/social/facebook/`, { access_token: accessToken });
  const data = response.data;
  const tokens = data?.tokens || { access: data?.access, refresh: data?.refresh };
  const user = data?.user;
  if (!tokens?.access) throw new Error('Access token não retornado');

  // Salva nos formatos novos e antigos para compatibilidade
  saveTokens(tokens.access, tokens.refresh);
  localStorage.setItem('access_token', tokens.access);
  localStorage.setItem('refresh_token', tokens.refresh || '');
  saveUserData(user);
  localStorage.setItem('user_data', JSON.stringify(user));
};