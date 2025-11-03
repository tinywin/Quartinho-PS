import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_BASE_URL, getAuthHeaders } from '../../utils/apiConfig';
import { Button } from '../../components/ui/button';
import { buildPixQr } from '../../utils/pix';

type Tab = 'card' | 'pix';

const PayFirstRent = (): JSX.Element => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [contract, setContract] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [paid, setPaid] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>('card');

  // Card form state
  const [cardName, setCardName] = useState('');
  const [cardNumber, setCardNumber] = useState('');
  const [cardExpiry, setCardExpiry] = useState('');
  const [cardCvv, setCardCvv] = useState('');

  // PIX simulation state
  const [pixKey, setPixKey] = useState('');
  const [copied, setCopied] = useState(false);
  const [qrPayload, setQrPayload] = useState<string | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [qrLoading, setQrLoading] = useState(false);

  useEffect(() => {
    if (!id) return;
    const fetch = async () => {
      try {
        const res = await axios.get(`${API_BASE_URL}/propriedades/contratos/${id}/`, { headers: getAuthHeaders() });
        setContract(res.data);
        // generate a fake pix key for simulation
        setPixKey(`pix:${res.data.id}@quartinho-pix.simulado`);
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

  // generate PIX QR when PIX tab is active and contract available
  useEffect(() => {
    let cancelled = false;
    const gen = async () => {
      if (tab !== 'pix' || !contract) return;
      setQrLoading(true);
      try {
        const txidCandidate = `c${contract.id}-${Date.now()}`;
        const txid = txidCandidate.slice(0, 25);
        const merchantName = contract.imovel?.proprietario?.nome_completo || contract.imovel?.proprietario?.username || 'QUARTINHO';
        const merchantCity = (contract.imovel?.endereco && contract.imovel.endereco.cidade) || contract.imovel?.cidade || 'CIDADE';
        const amount = contract.imovel?.preco;
        const { payload, qrDataUrl } = await buildPixQr({ pixKey, merchantName, merchantCity, amount, txid });
        if (!cancelled) {
          setQrPayload(payload);
          setQrDataUrl(qrDataUrl);
        }
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('Erro ao gerar QR PIX', e);
      } finally {
        if (!cancelled) setQrLoading(false);
      }
    };
    gen();
    return () => { cancelled = true; };
  }, [tab, contract, pixKey]);

  const formatCurrency = (v: any) => v ? new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v)) : '—';

  const simulateSuccess = async () => {
    setProcessing(true);
    try {
      // Simulate network/payment delay
      await new Promise((r) => setTimeout(r, 1200));
      // Try to update backend record marking primeiro_aluguel_pago=true. If it fails, fall back to local state only.
      try {
        if (id) {
          // use dedicated backend endpoint to confirm payment
          await axios.post(`${API_BASE_URL}/propriedades/contratos/${id}/confirm_payment/`, {}, { headers: getAuthHeaders() });
        }
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn('Não foi possível confirmar pagamento via backend (fallback local)', e);
      }
      // show a short success message while we confirm the backend recorded the payment
      setSuccessMessage('Pagamento processado. Aguardando confirmação no servidor...');

      // poll the backend a few times to confirm the payment flag was set
      const waitForBackendConfirmation = async (): Promise<boolean> => {
        const attempts = 6;
        const delayMs = 800;
        for (let i = 0; i < attempts; i += 1) {
          try {
            if (!id) break;
            const res = await axios.get(`${API_BASE_URL}/propriedades/contratos/${id}/`, { headers: getAuthHeaders() });
            const confirmed = res.data?.primeiro_aluguel_pago;
            if (confirmed === true || confirmed === 'true' || confirmed === 1 || confirmed === '1') return true;
            if (typeof confirmed === 'string' && confirmed.toLowerCase() === 'true') return true;
          } catch (e) {
            // ignore and retry
          }
          // eslint-disable-next-line no-await-in-loop
          await new Promise((r) => setTimeout(r, delayMs));
        }
        return false;
      };

      const confirmed = await waitForBackendConfirmation();
      setPaid(true);
      if (confirmed) {
        setSuccessMessage('Pagamento confirmado pelo servidor. Redirecionando...');
        setTimeout(() => navigate('/contratos', { state: { refetch: true, message: 'Pagamento confirmado' } }), 700);
      } else {
        setSuccessMessage('Pagamento registrado localmente. Redirecionando...');
        setTimeout(() => navigate('/contratos', { state: { refetch: true, message: 'Pagamento registrado localmente' } }), 700);
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Pagamento simulado falhou', e);
      setError('Erro ao processar pagamento.');
    } finally {
      setProcessing(false);
    }
  };

  const handleCardPay = async (ev?: React.FormEvent) => {
    ev?.preventDefault();
    setError(null);
    if (!cardName || !cardNumber || !cardExpiry || !cardCvv) return setError('Preencha todos os dados do cartão.');
    // simple validation
    if (cardNumber.replace(/\s+/g,'').length < 13) return setError('Número de cartão inválido.');
    // If you prefer real payments, use Stripe Checkout button below. This action simulates a payment.
    await simulateSuccess();
  };

  // Stripe integration removed — no client-side checkout function.

  const handlePixCopy = async () => {
    try {
      await navigator.clipboard.writeText(pixKey);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch (e) {
      // ignore
    }
  };

  const handleCopyPayload = async () => {
    try {
      if (!qrPayload) return;
      await navigator.clipboard.writeText(qrPayload);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch (e) {
      // ignore
    }
  };

  const handlePixPaid = async () => {
    setError(null);
    await simulateSuccess();
  };

  const handleMercadoPagoCheckout = async () => {
    if (!id) return setError('ID do contrato ausente.');
    setProcessing(true);
    try {
      const res = await axios.post(
        `${API_BASE_URL}/propriedades/contratos/${id}/create_mercado_pago_preference/`,
        {},
        { headers: getAuthHeaders() }
      );
      const initPoint = res.data?.init_point;
      if (initPoint) {
        window.location.href = initPoint;
      } else {
        setError('Não foi possível iniciar o pagamento (Mercado Pago).');
      }
    } catch (e: any) {
      // eslint-disable-next-line no-console
      console.error('Erro ao iniciar Mercado Pago Checkout', e);
      setError(e?.response?.data?.detail || e?.response?.data?.error || 'Erro ao iniciar o pagamento.');
    } finally {
      setProcessing(false);
    }
  };

  if (loading) return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
        <p className="text-gray-600">Carregando...</p>
      </div>
    </div>
  );

  return (
    <div className="max-w-3xl mx-auto p-6 bg-white rounded mt-8">
      <h2 className="text-xl font-semibold mb-4">Pagamento do Primeiro Aluguel</h2>
      {error && <div className="mb-4 text-red-600">{error}</div>}
      {successMessage && <div className="mb-4 p-3 bg-green-50 text-green-800 rounded">{successMessage}</div>}
      {!contract ? (
        <div>Nenhuma solicitação encontrada.</div>
      ) : (
        <div>
          <p className="text-sm text-gray-700 mb-2">Imóvel: <strong>{contract.imovel?.titulo ?? '—'}</strong></p>
          <p className="text-sm text-gray-700 mb-2">Valor: <strong>{formatCurrency(contract.imovel?.preco)}</strong></p>
          <p className="text-sm text-gray-700 mb-4">Solicitante: {contract.solicitante?.nome_completo ?? contract.solicitante?.username}</p>

          {contract.primeiro_aluguel_pago || paid ? (
            <div className="p-4 bg-green-50 text-green-800 rounded">Pagamento do primeiro aluguel confirmado.</div>
          ) : (
            <div>
              <div className="flex gap-3 mb-4">
                <button onClick={() => setTab('card')} className={`px-4 py-2 rounded ${tab==='card' ? 'bg-orange-500 text-white' : 'bg-gray-100'}`}>Cartão</button>
                <button onClick={() => setTab('pix')} className={`px-4 py-2 rounded ${tab==='pix' ? 'bg-orange-500 text-white' : 'bg-gray-100'}`}>PIX</button>
              </div>

              {tab === 'card' && (
                <form onSubmit={handleCardPay} className="space-y-3">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="md:col-span-2">
                      <label className="block text-sm text-gray-700 mb-2">Número do cartão</label>
                      <input
                        value={cardNumber}
                        onChange={(e) => {
                          // format as 4-digit groups
                          const raw = (e.target.value || '').replace(/\D/g, '').slice(0,19);
                          const parts = raw.match(/.{1,4}/g) || [];
                          setCardNumber(parts.join(' '));
                        }}
                        className="w-full px-4 py-3 border rounded-lg text-lg tracking-widest placeholder-gray-400"
                        placeholder="1234 1234 1234 1234"
                      />
                    </div>
                    <div className="hidden md:block">
                      <div className="w-full h-full flex items-center justify-center bg-gray-50 rounded-lg shadow-sm">
                        {/* card visual placeholder */}
                        <div className="w-36 h-20 bg-white rounded shadow-inner"></div>
                      </div>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-700 mb-2">Nome do titular</label>
                    <input value={cardName} onChange={(e) => setCardName(e.target.value)} className="w-full px-3 py-2 border rounded" placeholder="Ex.: Maria Lopes" />
                    <p className="text-xs text-gray-500 mt-1">Conforme aparece no cartão.</p>
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3 items-end">
                    <div className="col-span-1 md:col-span-1">
                      <label className="block text-sm text-gray-700 mb-2">Vencimento</label>
                      <input
                        value={cardExpiry}
                        onChange={(e) => {
                          const raw = (e.target.value || '').replace(/\D/g, '').slice(0,4);
                          if (raw.length >= 3) {
                            setCardExpiry(raw.slice(0,2) + '/' + raw.slice(2));
                          } else {
                            setCardExpiry(raw);
                          }
                        }}
                        className="w-full px-3 py-2 border rounded"
                        placeholder="MM/AA"
                      />
                    </div>

                    <div className="col-span-1 md:col-span-1">
                      <label className="block text-sm text-gray-700 mb-2">Código de segurança</label>
                      <input
                        value={cardCvv}
                        onChange={(e) => setCardCvv((e.target.value || '').replace(/\D/g, '').slice(0,4))}
                        className="w-full px-3 py-2 border rounded"
                        placeholder="Ex.: 123"
                      />
                    </div>

                    <div className="col-span-2 md:col-span-2">
                      <label className="block text-sm text-gray-700 mb-2">Documento do titular</label>
                      <div className="flex gap-2">
                        <select className="px-3 py-2 border rounded-l bg-white">
                          <option>CPF</option>
                        </select>
                        <input
                          className="flex-1 px-3 py-2 border rounded-r"
                          placeholder="999.999.999-99"
                          value={''}
                          onChange={() => { /* optional: implement cpf mask */ }}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="flex gap-3">
                    <Button className="bg-indigo-600 hover:bg-indigo-700" type="submit" disabled={processing}>{processing ? 'Processando...' : 'Pagar com cartão (simulado)'}</Button>
                    {/* Stripe checkout disabled in this build */}
                    <Button variant="secondary" onClick={() => navigate(-1)}>Cancelar</Button>
                  </div>
                </form>
              )}

              {tab === 'pix' && (
                <div className="space-y-3">
                  <p className="text-sm text-gray-700">Pagamento via PIX</p>
                  {qrLoading ? (
                    <div className="flex items-center gap-3">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div>
                      <div className="text-sm text-gray-600">Gerando QR code...</div>
                    </div>
                  ) : qrDataUrl ? (
                    <div className="flex flex-col items-start gap-3">
                      <img src={qrDataUrl} alt="PIX QR" className="w-48 h-48 bg-white p-2 rounded shadow" />
                      <div className="w-full">
                        <p className="text-sm text-gray-700">Payload PIX (para leitura / cópia):</p>
                        <div className="flex items-center gap-3">
                          <code className="bg-gray-100 px-3 py-2 rounded break-all max-w-full overflow-auto">{qrPayload}</code>
                          <Button onClick={handleCopyPayload} className="bg-gray-200">{copied ? 'Copiado' : 'Copiar payload'}</Button>
                        </div>
                      </div>

                      <div className="w-full">
                        <p className="text-sm text-gray-700">Chave PIX para pagamento:</p>
                        <div className="flex items-center gap-3">
                          <code className="bg-gray-100 px-3 py-2 rounded break-all">{pixKey}</code>
                          <Button onClick={handlePixCopy} className="bg-gray-200">{copied ? 'Copiado' : 'Copiar chave'}</Button>
                        </div>
                      </div>

                      <p className="text-sm text-gray-500">Após efetuar o transferência via PIX, clique em "Já paguei (simular)" para confirmar.</p>
                      <div className="flex gap-3">
                        <Button className="bg-indigo-600 hover:bg-indigo-700" onClick={handlePixPaid} disabled={processing}>{processing ? 'Processando...' : 'Já paguei (simular)'}</Button>
                        <Button className="bg-amber-600 hover:bg-amber-700" onClick={handleMercadoPagoCheckout} disabled={processing}>{processing ? 'Processando...' : 'Pagar com Mercado Pago'}</Button>
                        <Button variant="secondary" onClick={() => navigate(-1)}>Cancelar</Button>
                      </div>
                    </div>
                  ) : (
                    <div>Não foi possível gerar o QR. Tente recarregar a página.</div>
                  )}
                </div>
              )}

            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default PayFirstRent;
