import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { API_BASE_URL, getAuthFileHeaders } from '../../utils/apiConfig';
import { Button } from '../../components/ui/button';

const RequestContract = (): JSX.Element => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [nomeCompleto, setNomeCompleto] = useState('');
  const [cpf, setCpf] = useState('');
  const [telefone, setTelefone] = useState('');
  const [comprovante, setComprovante] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    // try to prefill name/cpf from userData in localStorage
    try {
      const raw = localStorage.getItem('userData') || localStorage.getItem('user_data');
      if (raw) {
        const u = JSON.parse(raw);
        setNomeCompleto(u?.full_name || u?.username || '');
        if (u?.cpf) setCpf(u.cpf);
      }
    } catch (e) {
      // ignore
    }
  }, []);

  const onFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0] ?? null;
    setComprovante(f);
  };

  const handleSubmit = async (ev?: React.FormEvent) => {
    ev?.preventDefault();
    setError(null);
    setSuccess(null);
    if (!id) return setError('Imóvel não especificado.');
    if (!nomeCompleto || !cpf || !telefone) return setError('Preencha nome, CPF e telefone.');

    const form = new FormData();
    form.append('imovel', id);
    form.append('nome_completo', nomeCompleto);
    form.append('cpf', cpf);
    form.append('telefone', telefone);
    if (comprovante) form.append('comprovante', comprovante);

    try {
      setLoading(true);
      await axios.post(`${API_BASE_URL}/propriedades/contratos/`, form, {
        headers: getAuthFileHeaders(),
      });
      setSuccess('Solicitação enviada com sucesso. O proprietário será notificado.');
      // redirect to property details after short delay
      setTimeout(() => navigate(`/properties/${id}`), 1200);
    } catch (err: any) {
      console.error('Erro ao criar solicitação de contrato', err);
      setError(err?.response?.data?.detail || 'Erro ao enviar solicitação.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6 bg-white rounded mt-8">
      <h2 className="text-xl font-semibold mb-4">Solicitação de Contrato</h2>
      <p className="text-sm text-gray-600 mb-4">Preencha seus dados e anexe um comprovante de renda para enviar a solicitação ao proprietário.</p>

      {error && <div className="mb-4 text-red-600">{error}</div>}
      {success && <div className="mb-4 text-green-600">{success}</div>}

      <form onSubmit={handleSubmit} className="grid grid-cols-1 gap-4">
        <div>
          <label className="block text-sm text-gray-700">Nome completo</label>
          <input value={nomeCompleto} onChange={(e) => setNomeCompleto(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">CPF</label>
          <input value={cpf} onChange={(e) => setCpf(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">Telefone</label>
          <input value={telefone} onChange={(e) => setTelefone(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">Comprovante de renda (opcional)</label>
          <input type="file" accept="application/pdf,image/*" onChange={onFileChange} />
        </div>

        <div className="flex gap-3">
          <Button className="bg-purple-600 text-white" type="submit" disabled={loading}>{loading ? 'Enviando...' : 'Enviar solicitação'}</Button>
          <Button variant="secondary" onClick={() => navigate(-1)}>Cancelar</Button>
        </div>
      </form>
    </div>
  );
};

export default RequestContract;
