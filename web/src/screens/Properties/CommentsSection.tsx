import { useEffect, useState } from 'react';
import axios from 'axios';
import { API_BASE_URL, getAuthHeaders } from '../../utils/apiConfig';
import { Star, Trash2 } from 'lucide-react';

interface Comment {
  id: number;
  usuario: { id?: number; full_name?: string; username?: string; email?: string } | string;
  nota?: number;
  texto?: string;
  criado_em?: string;
  // alguns backends usam este nome
  data_criacao?: string;
  data_criacao_iso?: string;
}

// Formata tempo relativo em português, similar ao mobile:
// "agora", "há 20 segundos", "há 5 minutos", "há 3 horas", "há 2 dias", "há 2 semanas" ou fallback para dd/mm/yyyy
const formatRelativeTime = (iso?: string) => {
  if (!iso) return '';
  try {
    const dt = new Date(iso);
    const ts = dt.getTime();
    if (Number.isNaN(ts)) return '';
    const now = Date.now();
    const diffSeconds = Math.floor((now - ts) / 1000);
    if (diffSeconds < 10) return 'agora';
    if (diffSeconds < 60) return `há ${diffSeconds} segundos`;
    const diffMinutes = Math.floor(diffSeconds / 60);
    if (diffMinutes < 60) return `há ${diffMinutes} minutos`;
    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) return `há ${diffHours} horas`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `há ${diffDays} dias`;
    if (diffDays < 30) return `há ${Math.floor(diffDays / 7)} semanas`;
    // fallback para data completa
    const dd = dt.getDate().toString().padStart(2, '0');
    const mm = (dt.getMonth() + 1).toString().padStart(2, '0');
    const yy = dt.getFullYear();
    return `${dd}/${mm}/${yy}`;
  } catch (e) {
    return '';
  }
};

const CommentsSection = ({ propertyId }: { propertyId: number }) => {
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(true);
  const [text, setText] = useState('');
  const [rating, setRating] = useState(5);
  const [currentUserId, setCurrentUserId] = useState<number | null>(null);

  const fetchComments = async () => {
    setLoading(true);
    try {
      const res = await axios.get(`${API_BASE_URL}/propriedades/comentarios/?imovel=${propertyId}`);
      const data = res.data;
      const items = Array.isArray(data) ? data : (data.results ?? []);
      setComments(items);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao buscar comentarios', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchComments();
    // try to fetch current user (to show delete button for own comments)
    const fetchCurrentUser = async () => {
      try {
        const res = await axios.get(`${API_BASE_URL}/usuarios/me/`, { headers: getAuthHeaders() });
        if (res && res.data && res.data.id) setCurrentUserId(res.data.id);
      } catch (err) {
        // fallback: some deployments use a nested path
        try {
          const res2 = await axios.get(`${API_BASE_URL}/usuarios/usuarios/me/`, { headers: getAuthHeaders() });
          if (res2 && res2.data && res2.data.id) setCurrentUserId(res2.data.id);
        } catch (e) {
          // ignore - user may be anonymous
        }
      }
    };

    fetchCurrentUser();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propertyId]);

  const submitComment = async () => {
    try {
      const payload = { imovel: propertyId, nota: rating, texto: text };
  await axios.post(`${API_BASE_URL}/propriedades/comentarios/`, payload, { headers: getAuthHeaders() });
      // refresh
      setText('');
      setRating(5);
      fetchComments();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao enviar comentario', err);
    }
  };

  const deleteComment = async (id: number) => {
    // confirm
    // eslint-disable-next-line no-restricted-globals
    if (!confirm('Deseja realmente apagar este comentário?')) return;
    try {
      await axios.delete(`${API_BASE_URL}/propriedades/comentarios/${id}/`, { headers: getAuthHeaders() });
      fetchComments();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao apagar comentario', err);
    }
  };

  return (
    <div className="mt-6">
      <h3 className="font-semibold mb-3">Comentários</h3>
      <div className="space-y-3">
        {loading ? (
          <div className="text-gray-500">Carregando comentários...</div>
        ) : (
          comments.map((c) => (
            <div key={c.id} className="bg-gray-50 p-3 rounded-lg">
              <div className="flex items-center justify-between">
                <div className="font-semibold">
                  {(() => {
                    if (!c.usuario) return 'Usuário';
                    if (typeof c.usuario === 'string') return c.usuario;
                    return c.usuario.full_name || c.usuario.username || c.usuario.email || 'Usuário';
                  })()}
                </div>
                <div className="flex items-center gap-3">
                  {/* tentar vários campos que o backend pode enviar */}
                  <div className="text-sm text-gray-500">{formatRelativeTime(c.criado_em ?? (c as any).data_criacao ?? (c as any).data_criacao_iso)}</div>
                  {typeof c.usuario !== 'string' && c.usuario && c.usuario.id && currentUserId === c.usuario.id && (
                    <button onClick={() => deleteComment(c.id)} className="text-red-500 p-1 rounded hover:bg-red-50" title="Apagar comentário">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-1 text-yellow-400 text-sm mt-1">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Star key={i} className={`w-4 h-4 ${i < (c.nota ?? 0) ? 'text-yellow-400' : 'text-gray-300'}`} />
                ))}
              </div>
              <div className="text-sm text-gray-700 mt-2">{c.texto}</div>
            </div>
          ))
        )}
      </div>

      <div className="mt-4">
        <div className="text-sm font-medium mb-1">Sua nota:</div>
        <div className="flex items-center gap-1 mb-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <button key={i} onClick={() => setRating(i + 1)} className="p-1">
              <Star className={`w-5 h-5 ${i < rating ? 'text-yellow-400' : 'text-gray-300'}`} />
            </button>
          ))}
        </div>
        <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder="Adicione um comentário..." className="w-full border p-2 rounded mb-2" />
        <div className="flex justify-end">
          <button onClick={submitComment} className="px-4 py-2 bg-orange-500 text-white rounded">Enviar</button>
        </div>
      </div>
    </div>
  );
};

export default CommentsSection;
