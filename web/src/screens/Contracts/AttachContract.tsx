import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { API_BASE_URL, getAuthFileHeaders, getAuthHeaders } from '../../utils/apiConfig';
import { Button } from '../../components/ui/button';

const AttachContract = (): JSX.Element => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [contract, setContract] = useState<any | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    const fetch = async () => {
      try {
        const res = await axios.get(`${API_BASE_URL}/propriedades/contratos/${id}/`, { headers: getAuthHeaders() });
        setContract(res.data);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('Erro ao buscar contrato:', err);
        setError('Não foi possível carregar a solicitação.');
      } finally {
        setLoading(false);
      }
    };
    fetch();
  }, [id]);

  const handleSubmit = async () => {
    if (!id) return;
    if (!file) {
      setError('Selecione um arquivo antes de enviar.');
      return;
    }
    setSubmitting(true);
    try {
      const fd = new FormData();
      fd.append('contrato_final', file);
  await axios.post(`${API_BASE_URL}/propriedades/contratos/${id}/upload_contrato/`, fd, { headers: getAuthFileHeaders() });
      // success -> go back to contracts list
      navigate('/contratos');
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao enviar contrato final:', err);
      setError('Erro ao enviar arquivo.');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Carregando...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-3xl mx-auto px-4 py-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-4">Anexar contrato</h1>
        {error && <div className="bg-red-50 text-red-600 p-3 rounded mb-4">{error}</div>}

        <div className="bg-white border rounded-lg p-6">
          <p className="text-sm text-gray-600 mb-4">Solicitação: <strong>{contract?.imovel?.titulo ?? '—'}</strong></p>
          <p className="text-sm text-gray-600 mb-4">Solicitante: {contract?.solicitante?.nome_completo ?? contract?.solicitante?.username ?? '—'}</p>

          <label className="block text-sm font-medium text-gray-700 mb-2">Arquivo do contrato (PDF ou imagem)</label>
          <input type="file" accept="application/pdf,image/*" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />

          <div className="mt-6 flex gap-2">
            <Button onClick={handleSubmit} className="bg-orange-500 hover:bg-orange-600" disabled={submitting}>{submitting ? 'Enviando...' : 'Enviar contrato'}</Button>
            <Button variant="secondary" onClick={() => navigate('/contratos')}>Cancelar</Button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AttachContract;
