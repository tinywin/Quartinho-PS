import { ArrowLeft, MailIcon } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "../../components/ui/button";
import { useState } from "react";
import axios from "axios";
import { API_BASE_URL } from "../../utils/apiConfig";
import { loginWithGoogle, loginWithFacebook } from "../../utils/socialAuth";

export const EmailLogin = (): JSX.Element => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [socialLoading, setSocialLoading] = useState<{ google: boolean; facebook: boolean }>({ google: false, facebook: false });
  const navigate = useNavigate();
  
  // Avisos de configuração: variáveis de ambiente do Vite
  const isGoogleConfigured = !!((import.meta as any).env?.VITE_GOOGLE_CLIENT_ID);
  const isFacebookConfigured = !!((import.meta as any).env?.VITE_FACEBOOK_APP_ID);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      // Fazer requisição para o endpoint de login
      const response = await axios.post(`${API_BASE_URL}/usuarios/login/`, {
        email,
        password
      });

      console.log("Resposta completa do login:", response.data);

      // Verificar se a resposta tem a estrutura esperada
      if (!response.data) {
        throw new Error("Resposta vazia do servidor");
      }

      // Adaptar para a estrutura atual do backend (tokens diretos)
      let tokens, user;
      
      if (response.data.tokens) {
        // Estrutura esperada: { tokens: { access, refresh }, user }
        tokens = response.data.tokens;
        user = response.data.user;
      } else if (response.data.access && response.data.refresh) {
        // Estrutura atual do backend: { access, refresh, user }
        tokens = {
          access: response.data.access,
          refresh: response.data.refresh
        };
        user = response.data.user;
      } else {
        throw new Error("Estrutura de resposta inválida");
      }

      // Verificar se access token existe
      if (!tokens.access) {
        console.error("Access token não encontrado:", tokens);
        throw new Error("Access token não encontrado");
      }

      // Salvar tokens no localStorage
      localStorage.setItem("access_token", tokens.access);
      localStorage.setItem("refresh_token", tokens.refresh || "");
      localStorage.setItem("user_data", JSON.stringify(user));

      navigate("/user-preference");
    } catch (err: any) {
      console.error("Erro no login:", err);
      setError(err?.message || "Falha no login");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogle = async () => {
    setError("");
    setSocialLoading((s) => ({ ...s, google: true }));
    try {
      await loginWithGoogle();
      navigate("/user-preference");
    } catch (e: any) {
      console.error("Erro no login Google:", e);
      setError(e?.message || "Falha no login com Google");
    } finally {
      setSocialLoading((s) => ({ ...s, google: false }));
    }
  };

  const handleFacebook = async () => {
    setError("");
    setSocialLoading((s) => ({ ...s, facebook: true }));
    try {
      await loginWithFacebook();
      navigate("/user-preference");
    } catch (e: any) {
      console.error("Erro no login Facebook:", e);
      setError(e?.message || "Falha no login com Facebook");
    } finally {
      setSocialLoading((s) => ({ ...s, facebook: false }));
    }
  };

  return (
    <div className="bg-white min-h-screen w-full flex flex-col">
      {/* Header with back button */}
      <div className="flex items-center p-6">
        <Link to="/" className="flex items-center text-gray-600 hover:text-gray-800 transition-colors">
          <ArrowLeft className="w-6 h-6 mr-2" />
          <span className="text-sm font-medium">Voltar</span>
        </Link>
      </div>

      {/* Main content */}
      <div className="flex-1 flex items-center justify-center p-6">
        <div className="w-full max-w-md">
          {/* Header */}
          <div className="text-center mb-8">
            <MailIcon className="w-16 h-16 mx-auto mb-4 text-orange-500" />
            <h1 className="text-2xl lg:text-3xl font-bold text-gray-800 mb-2">
              Entre com seu e-mail
            </h1>
            <p className="text-gray-600">
              Digite seu e-mail para continuar sua busca por um quartinho
            </p>
          </div>

          {/* Form */}
          <form onSubmit={handleLogin} className="space-y-6">
            {error && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                {error}
              </div>
            )}
            
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                E-mail
              </label>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Digite seu e-mail"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                Senha
              </label>
              <input
                type="password"
                id="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Digite sua senha"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <Button 
              type="submit" 
              className="w-full bg-orange-500 hover:bg-orange-600 rounded-full h-12 transition-colors duration-200"
              disabled={loading}
            >
              <span className="font-bold text-white">
                {loading ? "Entrando..." : "Continuar"}
              </span>
            </Button>
          </form>

          {/* Additional options */}
          <div className="mt-8 text-center">
            <p className="text-sm text-gray-600 mb-4">
              Ou continue com suas redes sociais
            </p>
            
            {/* Painel de aviso de configuração */}
            {(!isGoogleConfigured || !isFacebookConfigured) && (
              <div className="bg-yellow-50 text-yellow-700 p-3 rounded-lg text-sm mb-4 text-left">
                <p className="font-medium mb-1">Configuração necessária para login social:</p>
                {!isGoogleConfigured && (
                  <p className="mb-1">• Defina <code>VITE_GOOGLE_CLIENT_ID</code> em <code>web/.env</code>:<br />
                  Exemplo: <code>VITE_GOOGLE_CLIENT_ID=SEU_CLIENT_ID_DO_GOOGLE</code></p>
                )}
                {!isFacebookConfigured && (
                  <p>• Defina <code>VITE_FACEBOOK_APP_ID</code> em <code>web/.env</code>:<br />
                  Exemplo: <code>VITE_FACEBOOK_APP_ID=SEU_APP_ID_DO_FACEBOOK</code></p>
                )}
                <p className="mt-2">Após configurar, reinicie o servidor com <code>npm run dev</code>.</p>
              </div>
            )}
            
            <div className="flex gap-4">
              <Button
                onClick={handleGoogle}
                variant="secondary"
                className="flex-1 h-12 bg-gray-50 hover:bg-gray-100 rounded-lg border border-gray-200 transition-colors duration-200"
                disabled={socialLoading.google || !isGoogleConfigured}
              >
                <img
                  className="w-5 h-5 mr-2"
                  alt="Google"
                  src="/logo---google---normal.png"
                />
                <span className="text-sm font-medium">{socialLoading.google ? 'Conectando...' : 'Google'}</span>
              </Button>
              
              <Button
                onClick={handleFacebook}
                variant="secondary"
                className="flex-1 h-12 bg-gray-50 hover:bg-gray-100 rounded-lg border border-gray-200 transition-colors duration-200"
                disabled={socialLoading.facebook || !isFacebookConfigured}
              >
                <img
                  className="w-5 h-5 mr-2"
                  alt="Facebook"
                  src="/logo---facebook---normal.png"
                />
                <span className="text-sm font-medium">{socialLoading.facebook ? 'Conectando...' : 'Facebook'}</span>
              </Button>
            </div>
          </div>

          {/* Footer */}
          <div className="text-center mt-12">
            <p className="text-sm text-gray-600">
              Ainda não tem uma conta?{" "}
              <Link to="/register" className="font-bold text-orange-500 hover:text-orange-600 transition-colors duration-200">
                Cadastre-se aqui
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};