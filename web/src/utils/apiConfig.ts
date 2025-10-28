// Configuração da API baseada em .env (VITE_API_BASE_URL)
// Fallback para 127.0.0.1 evita problemas quando 'localhost' resolve para IPv6 (::1)
export const API_BASE_URL = (import.meta as any)?.env?.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

import axios from 'axios';

// Util para obter token considerando chaves novas e antigas
const getToken = (): string | null => {
  // preferir chave nova
  const t1 = localStorage.getItem('accessToken');
  if (t1) return t1;
  // fallback para chave antiga usada em algumas telas
  const t2 = localStorage.getItem('access_token');
  return t2 || null;
};

// Função para obter headers com autenticação
export const getAuthHeaders = () => {
  const accessToken = getToken();
  return {
    'Content-Type': 'application/json',
    'Authorization': accessToken ? `Bearer ${accessToken}` : ''
  };
};

// Função para obter headers para upload de arquivos com autenticação
export const getAuthFileHeaders = () => {
  const accessToken = getToken();
  return {
    'Authorization': accessToken ? `Bearer ${accessToken}` : ''
  };
};

// Instância Axios com baseURL e interceptors para Auth/Refresh
export const http = axios.create({
  baseURL: API_BASE_URL,
});

http.interceptors.request.use((config) => {
  const token = getToken();
  if (token) {
    config.headers = config.headers || {};
    (config.headers as any)['Authorization'] = `Bearer ${token}`;
  }
  return config;
});

http.interceptors.response.use(
  (resp) => resp,
  async (error) => {
    const status = error?.response?.status;
    const originalRequest = error.config;
    // Tenta refresh no 401
    if (status === 401 && !originalRequest?._retry) {
      originalRequest._retry = true;
      try {
        const refreshToken = localStorage.getItem('refreshToken') || localStorage.getItem('refresh_token');
        if (!refreshToken) throw new Error('Sem refresh token');
        const refreshResp = await axios.post(`${API_BASE_URL}/usuarios/token/refresh/`, { refresh: refreshToken });
        const newAccess = refreshResp?.data?.access;
        if (!newAccess) throw new Error('Refresh sem access');
        // Salva em chaves novas e antigas para compatibilidade
        localStorage.setItem('accessToken', newAccess);
        localStorage.setItem('access_token', newAccess);
        // Atualiza header e re-tenta
        originalRequest.headers = originalRequest.headers || {};
        originalRequest.headers['Authorization'] = `Bearer ${newAccess}`;
        return http(originalRequest);
      } catch (e) {
        // Falha em refresh: limpar e redirecionar para login
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('userData');
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('user_data');
        try { window.location.href = '/email-login'; } catch {}
        return Promise.reject(error);
      }
    }
    return Promise.reject(error);
  }
);