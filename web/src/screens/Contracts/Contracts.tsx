import { Button } from "../../components/ui/button";
import { useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import axios from 'axios';
import { API_BASE_URL, getAuthHeaders, getAuthFileHeaders } from '../../utils/apiConfig';
import { getUserData } from '../../utils/auth';

type Contract = any;

const Contracts = (): JSX.Element => {
  const navigate = useNavigate();
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentUser, setCurrentUser] = useState<any | null>(null);
  const [actionLoadingId, setActionLoadingId] = useState<number | null>(null);
  const [openId, setOpenId] = useState<number | null>(null);
  const [uploadSignedFiles, setUploadSignedFiles] = useState<Record<number, File | null>>({});
  const [uploadingSignedId, setUploadingSignedId] = useState<number | null>(null);

  useEffect(() => {
    const ud = getUserData();
    setCurrentUser(ud ?? null);
    fetchContracts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchContracts = async () => {
    setLoading(true);
    try {
      const res = await axios.get(`${API_BASE_URL}/propriedades/contratos/`, { headers: getAuthHeaders() });
      const data = res.data;
      let items: Contract[] = [];
      if (Array.isArray(data)) items = data;
      else if (data && Array.isArray(data.results)) items = data.results;
      else if (data && Array.isArray(data.data)) items = data.data;
      else if (data) items = [data];
      setContracts(items);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao buscar contratos:', err);
      setError('Não foi possível carregar contratos.');
    } finally {
      setLoading(false);
    }
  };

  const handleSetStatus = async (id: number, status: 'approved' | 'rejected') => {
    setActionLoadingId(id);
    try {
      const body: any = { status };
      const res = await axios.post(`${API_BASE_URL}/propriedades/contratos/${id}/set_status/`, body, { headers: getAuthHeaders() });
      const updated: Contract = res.data;
      setContracts((prev) => prev.map(c => c.id === updated.id ? updated : c));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao atualizar status:', err);
      setError('Erro ao atualizar status do contrato.');
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleToggleOpen = (id: number) => {
    setOpenId((prev) => (prev === id ? null : id));
  };

  const isOwner = (contract: Contract) => {
    try {
      const imovel = contract.imovel;
      if (!imovel) return false;
      const proprietario = imovel.proprietario;
      // proprietario can be an object with id or a primitive id
      if (proprietario == null) return false;
      if (typeof proprietario === 'object') return proprietario.id === currentUser?.id;
      return Number(proprietario) === Number(currentUser?.id);
    } catch (e) {
      return false;
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Carregando contratos...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 py-6">
        <h1 className="text-2xl font-bold text-gray-900 mb-4">Contratos</h1>
        <p className="text-gray-600 mb-6">Solicitações de contrato relacionadas aos seus imóveis.</p>

        {error && (
          <div className="bg-red-50 text-red-600 p-4 rounded-lg mb-6">{error}</div>
        )}

        {contracts.length === 0 ? (
          <div className="bg-white border rounded-lg p-6">
            <p className="text-gray-500">Nenhuma solicitação encontrada.</p>
            <div className="mt-4">
              <Button onClick={() => navigate(-1)} className="bg-orange-500 hover:bg-orange-600">Voltar</Button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {contracts.map((c) => (
              <div key={c.id} className="bg-white border rounded-lg p-4">
                <div className="flex items-start justify-between cursor-pointer" onClick={() => handleToggleOpen(c.id)}>
                  <div>
                    <h3 className="text-lg font-semibold">{c.imovel?.titulo ?? `Imóvel #${c.imovel ?? ''}`}</h3>
                    <p className="text-sm text-gray-600">Solicitante: {c.solicitante?.nome_completo ?? c.solicitante?.username ?? '—'}</p>
                    <p className="text-sm text-gray-600">Nome fornecido: {c.nome_completo}</p>
                    <p className="text-sm text-gray-600">CPF: {c.cpf}</p>
                    {c.telefone && <p className="text-sm text-gray-600">Telefone: {c.telefone}</p>}
                    {c.comprovante && (
                      <p className="text-sm mt-2">
                        <a href={c.comprovante} target="_blank" rel="noreferrer" className="text-orange-600 hover:underline">Ver comprovante</a>
                      </p>
                    )}
                  </div>

                  <div className="text-right">
                    <div className="mb-2">
                      <span className={`px-2 py-1 rounded-full text-sm ${c.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : c.status === 'approved' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                        {c.status}
                      </span>
                    </div>
                    {/* show payment status to the property owner (also useful for simulated flows) */}
                    {isOwner(c) && c.primeiro_aluguel_pago && (
                      <div className="text-sm text-green-700 font-medium">Pagamento confirmado (simulado)</div>
                    )}
                    <div className="text-xs text-gray-500">{new Date(c.data_criacao).toLocaleString()}</div>
                  </div>
                </div>

                {/* expanded area */}
                {openId === c.id && (
                  <div className="mt-4">
                    {/* Show contrato_final to owner and to the solicitante when available and approved */}
                    {c.status === 'approved' && c.contrato_final && (isOwner(c) || c.solicitante?.id === currentUser?.id) && (
                      <div className="mb-4">
                        <p className="text-sm text-gray-600">Contrato enviado pelo proprietário: <a href={c.contrato_final} target="_blank" rel="noreferrer" className="text-orange-600 hover:underline">ver contrato</a></p>
                      </div>
                    )}

                    {/* Show contrato_assinado to the owner when the solicitante uploaded it */}
                    {c.contrato_assinado && isOwner(c) && (
                      <div className="mb-4">
                        <p className="text-sm text-gray-600">Contrato assinado enviado pelo solicitante: <a href={c.contrato_assinado} target="_blank" rel="noreferrer" className="text-orange-600 hover:underline">ver contrato assinado</a></p>
                      </div>
                    )}
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        {isOwner(c) ? (
                          <>
                            <Button
                              onClick={() => handleSetStatus(c.id, 'approved')}
                              className="bg-green-500 hover:bg-green-600"
                              disabled={actionLoadingId === c.id || c.status === 'approved'}
                            >
                              {actionLoadingId === c.id ? 'Enviando...' : 'Marcar como viável'}
                            </Button>
                            <Button
                              onClick={() => handleSetStatus(c.id, 'rejected')}
                              className="bg-red-500 hover:bg-red-600"
                              disabled={actionLoadingId === c.id || c.status === 'rejected'}
                            >
                              {actionLoadingId === c.id ? 'Enviando...' : 'Marcar como não viável'}
                            </Button>
                          </>
                        ) : (
                          <span className="text-sm text-gray-500">Apenas o proprietário pode alterar o status</span>
                        )}
                      </div>
                      <Button onClick={() => navigate(`/properties/${c.imovel?.id ?? ''}`)} variant="secondary">Ver imóvel</Button>
                    </div>

                    {/* Upload area: only owner and when status is 'approved' */}
                    {isOwner(c) && c.status === 'approved' && (
                      <div className="mt-4 border-t pt-4">
                        <Button
                          onClick={() => navigate(`/contratos/${c.id}/anexar`)}
                          className="bg-orange-500 hover:bg-orange-600"
                        >
                          Anexar contrato
                        </Button>
                        {c.contrato_final && (
                          <p className="text-sm text-gray-600 mt-2">Contrato anexado: <a href={c.contrato_final} target="_blank" rel="noreferrer" className="text-orange-600 hover:underline">ver arquivo</a></p>
                        )}
                      </div>
                    )}
                    {/* Allow the solicitante to upload the signed contract when approved and contrato_final exists */}
                    {c.status === 'approved' && c.contrato_final && c.solicitante?.id === currentUser?.id && (
                      <div className="mt-4 border-t pt-4">
                        {c.contrato_assinado ? (
                          <p className="text-sm text-gray-600">Você já enviou o contrato assinado: <a href={c.contrato_assinado} target="_blank" rel="noreferrer" className="text-orange-600 hover:underline">ver contrato assinado</a></p>
                        ) : (
                          <>
                            <label className="block text-sm font-medium text-gray-700 mb-2">Enviar contrato assinado</label>
                            <input type="file" accept="application/pdf,image/*" onChange={(e) => setUploadSignedFiles(prev => ({ ...prev, [c.id]: e.target.files?.[0] ?? null }))} />
                            <div className="mt-3">
                              <Button
                                onClick={async () => {
                                  const file = uploadSignedFiles[c.id];
                                  if (!file) { setError('Selecione um arquivo antes de enviar.'); return; }
                                  setUploadingSignedId(c.id);
                                  try {
                                    const fd = new FormData();
                                    fd.append('contrato_assinado', file);
                                    const res = await axios.post(`${API_BASE_URL}/propriedades/contratos/${c.id}/upload_contrato_assinado/`, fd, { headers: getAuthFileHeaders() });
                                    const updated: Contract = res.data;
                                    setContracts((prev) => prev.map(pc => pc.id === updated.id ? updated : pc));
                                    // clear the file input state
                                    setUploadSignedFiles(prev => ({ ...prev, [c.id]: null }));
                                  } catch (err) {
                                    // eslint-disable-next-line no-console
                                    console.error('Erro ao enviar contrato assinado:', err);
                                    setError('Erro ao enviar contrato assinado.');
                                  } finally {
                                    setUploadingSignedId(null);
                                  }
                                }}
                                className="bg-blue-600 hover:bg-blue-700"
                                disabled={uploadingSignedId === c.id}
                              >
                                {uploadingSignedId === c.id ? 'Enviando...' : 'Enviar contrato assinado'}
                              </Button>
                            </div>
                          </>
                        )}
                      </div>
                    )}
                    {/* If the signed contract exists and first rent not paid, allow solicitante to go to payment page */}
                    {c.contrato_assinado && c.solicitante?.id === currentUser?.id && !c.primeiro_aluguel_pago && (
                      <div className="mt-3">
                        <Button onClick={() => navigate(`/contratos/${c.id}/pagar`)} className="bg-indigo-600 hover:bg-indigo-700">Pagar primeiro aluguel</Button>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default Contracts;
