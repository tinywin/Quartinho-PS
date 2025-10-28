import React, { useState } from "react";
import axios from "axios";
import { Link, useNavigate } from "react-router-dom";
import { API_BASE_URL } from "../../utils/apiConfig";

// Mantém os mocks temporários para evitar quebra de UI local
const Button = ({ children, onClick, className = "", type = "button", disabled = false }: any) => (
  <button type={type} onClick={onClick} disabled={disabled} className={`px-4 py-2 rounded ${className}`}>
    {children}
  </button>
);

const Register = () => {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const checkEmailExists = async (email: string) => {
    try {
      const response = await axios.post(`${API_BASE_URL}/usuarios/check-email/`, { email });
      return response.data.exists;
    } catch (error) {
      console.error("Erro ao verificar email:", error);
      return false;
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setLoading(true);

    if (password !== confirmPassword) {
      setErrorMessage("As senhas não coincidem.");
      setLoading(false);
      return;
    }

    try {
      const emailExists = await checkEmailExists(email);
      if (emailExists) {
        setErrorMessage("Este e-mail já está cadastrado.");
        setLoading(false);
        return;
      }

      const response = await axios.post(`${API_BASE_URL}/usuarios/usercreate/`, {
        nome_completo: name,
        email,
        password
      });

      if (response.status === 201 || response.status === 200) {
        navigate("/email-login");
      } else {
        setErrorMessage("Falha ao criar conta. Tente novamente.");
      }
    } catch (error: any) {
      console.error("Erro ao registrar:", error);
      // Mensagens amigáveis com base nos erros do backend
      if (axios.isAxiosError(error)) {
        const status = error.response?.status;
        const data = error.response?.data as any;
        if (status === 400 && data) {
          const nonField = Array.isArray(data?.non_field_errors) ? data.non_field_errors[0] : undefined;
          const emailMsg = Array.isArray(data?.email) ? data.email[0] : (typeof data?.email === 'string' ? data.email : undefined);
          const senhaMsg = Array.isArray(data?.password) ? data.password[0] : (typeof data?.password === 'string' ? data.password : undefined);
          const nomeMsg = Array.isArray(data?.nome_completo) ? data.nome_completo[0] : (typeof data?.nome_completo === 'string' ? data.nome_completo : undefined);
          const detailMsg = typeof data?.detail === 'string' ? data.detail : undefined;

          setErrorMessage(
            nonField ||
            emailMsg ||
            senhaMsg ||
            nomeMsg ||
            detailMsg ||
            "Dados inválidos. Verifique nome, e-mail e senha."
          );
        } else if (status === 409) {
          setErrorMessage("Este e-mail já está cadastrado.");
        } else if (status === 500) {
          setErrorMessage("Erro no servidor ao criar conta. Tente novamente.");
        } else {
          setErrorMessage("Não foi possível criar a conta. Tente novamente.");
        }
      } else {
        setErrorMessage(error?.message || "Erro ao criar conta.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white">
      <div className="flex items-center p-6">
        <Link to="/" className="flex items-center text-gray-600 hover:text-gray-800 transition-colors">
          <span className="text-sm font-medium">Voltar</span>
        </Link>
      </div>

      <div className="flex-1 flex items-center justify-center p-6">
        <div className="w-full max-w-md">
          <div className="text-center mb-8">
            <h1 className="text-2xl lg:text-3xl font-bold text-gray-800 mb-2">Crie sua conta</h1>
            <p className="text-gray-600">Cadastre-se para continuar sua busca por um quartinho</p>
          </div>

          <form onSubmit={handleRegister} className="space-y-6">
            {errorMessage && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                {errorMessage}
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Nome</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Digite seu nome"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">E-mail</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Digite seu e-mail"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Senha</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Digite sua senha"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Confirmar Senha</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Confirme sua senha"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none transition-colors"
                required
              />
            </div>

            <Button
              type="submit"
              className="w-full bg-orange-500 hover:bg-orange-600 rounded-full h-12 transition-colors duration-200"
              disabled={loading}
            >
              <span className="font-bold text-white">{loading ? "Criando..." : "Criar conta"}</span>
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Register;
export { Register };
