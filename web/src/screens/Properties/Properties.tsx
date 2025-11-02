import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Search, MapPin, Heart, Star, Bed, Bath, Car, Wifi, Bell } from "lucide-react";
import { Button } from "../../components/ui/button";
import axios from "axios";
import { API_BASE_URL, getAuthHeaders } from "../../utils/apiConfig";
import { getUserData, clearAuth } from "../../utils/auth";

interface Property {
  id: number;
  proprietario: number;
  titulo: string;
  descricao: string;
  tipo: string;
  preco: number;
  endereco: string;
  cidade: string;
  estado: string;
  quartos: number;
  banheiros: number;
  area?: number;
  mobiliado: boolean;
  aceita_pets: boolean;
  internet: boolean;
  estacionamento: boolean;
  fotos: Array<{
    id: number;
    imagem: string;
    principal: boolean;
  }>;
  // possible rating fields returned by API
  nota_media?: number;
  rating?: number;
  avg_rating?: number;
  media?: number;
}

interface Notification {
  id: number;
  mensagem: string;
  lida: boolean;
  data_criacao: string;
  imovel?: number; // ID do imóvel
}

export const Properties = (): JSX.Element => {
  // debug: confirmar montagem do componente
  // eslint-disable-next-line no-console
  console.log('[DEBUG] Properties mounted');
  const navigate = useNavigate();
  const [properties, setProperties] = useState<Property[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [filters, setFilters] = useState({
    tipo: "",
    preco_min: "",
    preco_max: "",
    cidade: "",
    q: ""
  });
  const [onlyMine, setOnlyMine] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<number | null>(null);
  const [currentUser, setCurrentUser] = useState<any | null>(null);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [avatarError, setAvatarError] = useState(false);
  const userMenuRef = useRef<HTMLDivElement | null>(null);
  const [onlyFavorites, setOnlyFavorites] = useState(false);
  const [favoriteIds, setFavoriteIds] = useState<Set<number>>(new Set());
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loadingNotifications, setLoadingNotifications] = useState(false);
  const notificationMenuRef = useRef<HTMLDivElement | null>(null);


  useEffect(() => {
    const ud = getUserData();
    setCurrentUserId(ud?.id ?? null);
    setCurrentUser(ud ?? null);
    // buscar apenas os IDs de favoritos no mount
    fetchFavorites();
  // apenas na montagem
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // busca propriedades quando filtros/flags mudam
  useEffect(() => {
    if (onlyFavorites) {
      fetchFavoriteProperties();
    } else {
      fetchProperties();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters, onlyMine, onlyFavorites]);

  // fetch current user from backend to ensure we have the latest profile (including avatar url)
  useEffect(() => {
    const fetchCurrentUser = async () => {
      try {
        const res = await axios.get(`${API_BASE_URL}/usuarios/me/`, { headers: getAuthHeaders() });
        const data = res.data;
        if (data) {
          setCurrentUser(data);
          setCurrentUserId(data.id ?? currentUserId);
          setAvatarError(false);
        }
      } catch (err) {
        // ignore: if unauthenticated or endpoint not present, fallback to local stored user
        // eslint-disable-next-line no-console
        console.debug('Could not fetch current user profile', err);
      }
    };

    fetchCurrentUser();
    fetchUnreadCount();
    // only run once on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // close menu when clicking outside
  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (!showUserMenu) return;
      if (userMenuRef.current && !userMenuRef.current.contains(e.target as Node)) {
        setShowUserMenu(false);
      }
      if (notificationMenuRef.current && !notificationMenuRef.current.contains(e.target as Node)) {
        setShowNotifications(false);
      }      
    };
    document.addEventListener('click', onDocClick);
    return () => document.removeEventListener('click', onDocClick);
  }, [showUserMenu, showNotifications]);

  const getUserAvatar = (u: any) => {
    if (!u) return null;
    // possible shapes: string URL, relative path, object with url property
    const raw = u.avatar ?? u.avatar_url ?? u.foto ?? u.avatarUrl ?? u.picture ?? u.image ?? null;
    if (!raw) return null;

    // If avatar is object like { url: '...' } or { imagem: '...' }
    if (typeof raw === 'object') {
      const r = raw.url ?? raw.url_imagem ?? raw.imagem ?? raw.path ?? raw.filename ?? null;
      if (typeof r === 'string') {
        if (/^https?:\/\//i.test(r) || r.startsWith('data:')) return r;
        if (r.startsWith('/')) return `${API_BASE_URL.replace(/\/$/, '')}${r}`;
        return r;
      }
      return null;
    }

    // If it's a string
    if (typeof raw === 'string') {
      // already absolute
      if (/^https?:\/\//i.test(raw) || raw.startsWith('data:')) return raw;
      // relative path from backend (starts with /media or /)
      if (raw.startsWith('/')) return `${API_BASE_URL.replace(/\/$/, '')}${raw}`;
      // otherwise return as-is
      return raw;
    }

    return null;
  };

  const getUserInitials = (u: any) => {
    if (!u) return '';
    const name = u.nome || u.name || u.full_name || u.first_name || u.username || '';
    const parts = name.trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) return '';
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  };

  const fetchProperties = async () => {
    try {
      const url = onlyMine
        ? `${API_BASE_URL}/propriedades/propriedades/minhas_propriedades/`
        : `${API_BASE_URL}/propriedades/propriedades/`;

      const cleanParams = Object.fromEntries(
        Object.entries(filters).filter(([_, v]) => v !== "" && v !== null && v !== undefined)
      );

      const response = await axios.get(url, {
        headers: getAuthHeaders(),
        params: onlyMine ? undefined : cleanParams,
      });

      // Normaliza diferentes formatos de resposta (array direto ou paginação DRF)
      const data = response.data;
      let items: Property[] = [];
      if (Array.isArray(data)) {
        items = data;
      } else if (data && Array.isArray(data.results)) {
        items = data.results;
      } else if (data && Array.isArray(data.data)) {
        items = data.data;
      } else {
        // Se não for nenhum dos formatos esperados, loga para facilitar debug
        // eslint-disable-next-line no-console
        console.warn('[Properties] resposta da API inesperada ao buscar propriedades:', data);
        items = [];
      }

      setProperties(items);
    } catch (error) {
      console.error("Erro ao buscar propriedades:", error);
      setError("Não foi possível carregar as propriedades. Tente novamente.");
    } finally {
      setLoading(false);
    }
  };

const fetchUnreadCount = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/notificacoes/contagem_nao_lida/`, {
        headers: getAuthHeaders(),
      });
      setUnreadCount(response.data.count || 0);
    } catch (error) {
      console.error("Erro ao buscar contagem de notificações:", error);
    }
  };

  /**
   * Busca a lista completa de notificações.
   */
  const fetchNotifications = async () => {
    setLoadingNotifications(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/notificacoes/`, {
        headers: getAuthHeaders(),
      });
      // A API retorna a lista direto ou dentro de 'results'
      const data = response.data;
      if (Array.isArray(data)) {
        setNotifications(data);
      } else if (data && Array.isArray(data.results)) {
        setNotifications(data.results);
      }
    } catch (error) {
      console.error("Erro ao buscar notificações:", error);
    } finally {
      setLoadingNotifications(false);
    }
  };

  /**
   * Marca todas as notificações como lidas no backend.
   */
  const markAllAsRead = async () => {
    try {
      await axios.post(
        `${API_BASE_URL}/notificacoes/marcar_todas_como_lidas/`,
        {},
        { headers: getAuthHeaders() }
      );
      // Atualiza o estado local
      setUnreadCount(0);
      setNotifications((prev) => prev.map(n => ({ ...n, lida: true })));
    } catch (error) {
      console.error("Erro ao marcar notificações como lidas:", error);
    }
  };

  /**
   * Ação de clique no ícone de sino.
   */
  const handleBellClick = () => {
    // Fecha o outro menu se estiver aberto
    setShowUserMenu(false);
    
    // Se está fechando o menu, não faz nada
    if (showNotifications) {
      setShowNotifications(false);
      return;
    }

    // Se está abrindo o menu
    setShowNotifications(true);
    fetchNotifications(); // Busca a lista
    
    // Se tinha notificações não lidas, marca todas como lidas
    if (unreadCount > 0) {
      markAllAsRead();
    }
  };

  /**
   * Helper para formatar a data da notificação.
   */
  const formatNotificationDate = (dateString: string) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };


  const handleSearch = () => {
    setFilters(prev => ({ ...prev, q: searchTerm, cidade: "" }));
  };

  // debounce searchTerm -> update filters after a short delay to avoid too many requests
  const searchTimeout = useRef<number | null>(null);
  useEffect(() => {
    if (searchTimeout.current) window.clearTimeout(searchTimeout.current);
    searchTimeout.current = window.setTimeout(() => {
      setFilters(prev => ({ ...prev, q: searchTerm }));
    }, 350);
    return () => {
      if (searchTimeout.current) window.clearTimeout(searchTimeout.current);
    };
  }, [searchTerm]);

  const handleFilterChange = (key: string, value: string) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(price);
  };

  const getPropertyRating = (p: Property) => {
    // try common fields from API
    const raw = (p as any).nota_media ?? (p as any).avg_rating ?? (p as any).rating ?? (p as any).nota ?? (p as any).media ?? null;
    if (raw != null) {
      const n = Number(raw);
      if (!Number.isNaN(n)) return n;
    }
    // fallback: if the property embedded comments exist, compute average
    const comments = (p as any).comentarios ?? (p as any).comentarios_list ?? null;
    if (Array.isArray(comments) && comments.length > 0) {
      const notes = comments.map((c: any) => Number(c.nota ?? c.rating ?? 0)).filter((v: number) => v > 0);
      if (notes.length > 0) return notes.reduce((a: number, b: number) => a + b, 0) / notes.length;
    }
    return null;
  };

  const getPropertyImage = (property: Property) => {
    const principalPhoto = property.fotos?.find(foto => foto.principal);
    const raw = principalPhoto?.imagem || property.fotos?.[0]?.imagem || '/placeholder-property.jpg';
    if (typeof raw !== 'string') return '/placeholder-property.jpg';
    // absolute URLs or data URIs
    if (/^https?:\/\//i.test(raw) || raw.startsWith('data:')) return raw;
    // relative paths from backend start with /
    if (raw.startsWith('/')) return `${API_BASE_URL.replace(/\/$/, '')}${raw}`;
    // otherwise prefix with API base
    return `${API_BASE_URL.replace(/\/$/, '')}/${raw}`;
  };

  const fetchFavorites = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/propriedades/favoritos/`, {
        headers: getAuthHeaders(),
      });
      const data = response.data;
      let items: Property[] = [];
      if (Array.isArray(data)) {
        items = data;
      } else if (data && Array.isArray(data.results)) {
        items = data.results;
      }

      const ids = items.map((prop: Property) => prop.id);
      setFavoriteIds(new Set(ids));
    } catch (error) {
      console.error("Erro ao buscar IDs de favoritos:", error);
    }
  };

  const fetchFavoriteProperties = async () => {
    setLoading(true);
    try {
      const response = await axios.get(`${API_BASE_URL}/propriedades/favoritos/`, {
        headers: getAuthHeaders(),
      });
      const data = response.data;
      let items: Property[] = [];
      if (Array.isArray(data)) {
        items = data;
      } else if (data && Array.isArray(data.results)) {
        items = data.results;
      }
      setProperties(items);
    } catch (error) {
      console.error("Erro ao buscar propriedades favoritas:", error);
      setError("Não foi possível carregar seus favoritos.");
    } finally {
      setLoading(false);
    }
  };

  const handleToggleFavorite = async (propertyId: number) => {
    const newFavoriteIds = new Set(favoriteIds);
    if (newFavoriteIds.has(propertyId)) {
      newFavoriteIds.delete(propertyId);
    } else {
      newFavoriteIds.add(propertyId);
    }
    setFavoriteIds(newFavoriteIds);

    try {
      await axios.post(
        `${API_BASE_URL}/propriedades/propriedade/${propertyId}/favoritar/`,
        {},
        { headers: getAuthHeaders() }
      );
    } catch (error) {
      console.error("Erro ao favoritar propriedade:", error);
      // Se der erro, reverte o estado para o original
      fetchFavorites(); 
      setError("Não foi possível atualizar seus favoritos.");
    }
  };


  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Carregando propriedades...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-6">
            Encontre seu quarto ideal
          </h1>

          {/* Actions */}
          <div className="flex items-center gap-3 mb-4">
            <Button onClick={() => navigate('/add-property')} className="bg-orange-500 hover:bg-orange-600 px-4">
              Adicionar imóvel
            </Button>
            <Button
              variant={onlyMine ? 'default' : 'secondary'}
              onClick={() => setOnlyMine((v) => !v)}
              className="px-4"
            >
              {onlyMine ? 'Exibindo só minhas' : 'Minhas propriedades'}
            </Button>

            <Button
                variant={onlyFavorites ? 'default' : 'secondary'}
                onClick={() => {
                  setOnlyFavorites((v) => !v);
                  setOnlyMine(false);
                }}
                className="px-4"
              >
                Meus Favoritos
              </Button>

            <div className="ml-auto" />

<div ref={notificationMenuRef} className="relative">
              <button
                onClick={(e) => { e.stopPropagation(); handleBellClick(); }}
                className="p-2 rounded-full text-gray-600 hover:bg-gray-100 focus:outline-none relative"
                aria-label="Notificações"
              >
                <Bell className="w-6 h-6" />
                {unreadCount > 0 && (
                  <span className="absolute top-0 right-0 block h-5 w-5 rounded-full bg-red-500 text-white text-xs flex items-center justify-center font-bold ring-2 ring-white">
                    {unreadCount}
                  </span>
                )}
              </button>

              {/* Dropdown de Notificações */}
              {showNotifications && (
                <div className="absolute right-0 mt-2 w-80 md:w-96 bg-white border rounded-lg shadow-lg z-50 max-h-96 overflow-y-auto">
                  <div className="p-4 border-b">
                    <h3 className="text-lg font-semibold text-gray-900">Notificações</h3>
                  </div>
                  {loadingNotifications ? (
                    <div className="p-6 text-center text-gray-500">
                      Carregando...
                    </div>
                  ) : notifications.length === 0 ? (
                    <div className="p-6 text-center text-gray-500">
                      Nenhuma notificação ainda.
                    </div>
                  ) : (
                    <div className="divide-y">
                      {notifications.map((notif) => (
                        <div key={notif.id} className={`p-4 hover:bg-gray-50 ${!notif.lida ? 'bg-orange-50' : ''}`}>
                          <p className="text-sm text-gray-700">
                            {notif.mensagem}
                          </p>
                          <span className="text-xs text-gray-500 mt-1 block">
                            {formatNotificationDate(notif.data_criacao)}
                          </span>
                          {/* Opcional: Link para o imóvel */}
                          {notif.imovel && (
                            <button
                              onClick={() => navigate(`/properties/${notif.imovel}`)}
                              className="text-sm text-orange-600 hover:underline mt-2"
                            >
                              Ver imóvel
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>            

            <div ref={userMenuRef} className="relative">
              <button
                onClick={(e) => { e.stopPropagation(); setShowUserMenu((v) => !v); setShowNotifications(false) }}
                className="flex items-center focus:outline-none"
              >
                {(() => {
                  const avatar = getUserAvatar(currentUser);
                  if (avatar && !avatarError) {
                    return (
                      <img
                        src={avatar}
                        alt={currentUser?.nome || 'Usuário'}
                        onError={() => setAvatarError(true)}
                        className="w-10 h-10 rounded-full object-cover"
                      />
                    );
                  }
                  return (
                    <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-sm font-medium text-gray-700">
                      {getUserInitials(currentUser) || 'U'}
                    </div>
                  );
                })()}
              </button>

              {showUserMenu && (
                <div className="absolute right-0 mt-2 w-48 bg-white border rounded shadow z-50">
                  <button
                    onClick={() => { setShowUserMenu(false); navigate('/profile'); }}
                    className="w-full text-left px-4 py-2 hover:bg-gray-100"
                  >
                    Perfil
                  </button>
                  <button
                    onClick={() => { setShowUserMenu(false); navigate('/contratos'); }}
                    className="w-full text-left px-4 py-2 hover:bg-gray-100"
                  >
                    Contratos
                  </button>
                  <button
                    onClick={() => { setShowUserMenu(false); clearAuth(); navigate('/email-login'); }}
                    className="w-full text-left px-4 py-2 hover:bg-gray-100"
                  >
                    Sair
                  </button>
                </div>
              )}
            </div>
          </div>
          
          {/* Search Bar */}
          <div className="flex gap-4 mb-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Buscar por cidade..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              />
            </div>
            <Button 
              onClick={handleSearch}
              className="bg-orange-500 hover:bg-orange-600 px-6"
            >
              Buscar
            </Button>
          </div>

          {/* Filters */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Tipo de Imóvel
              </label>
              <select
                value={filters.tipo}
                onChange={(e) => handleFilterChange('tipo', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              >
                <option value="">Todos os tipos</option>
                <option value="apartamento">Apartamento</option>
                <option value="casa">Casa</option>
                <option value="kitnet">Kitnet</option>
                <option value="republica">República</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Preço Mínimo
              </label>
              <input
                type="number"
                placeholder="R$ 0"
                value={filters.preco_min}
                onChange={(e) => handleFilterChange('preco_min', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Preço Máximo
              </label>
              <input
                type="number"
                placeholder="R$ 10.000"
                value={filters.preco_max}
                onChange={(e) => handleFilterChange('preco_max', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Cidade
              </label>
              <input
                type="text"
                placeholder="Digite a cidade"
                value={filters.cidade}
                onChange={(e) => handleFilterChange('cidade', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        {error && (
          <div className="bg-red-50 text-red-600 p-4 rounded-lg mb-6">
            {error}
          </div>
        )}

        {properties.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-gray-400 mb-4">
              <Search className="w-16 h-16 mx-auto" />
            </div>
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              Nenhuma propriedade encontrada
            </h3>
            <p className="text-gray-600">
              Tente ajustar seus filtros de busca ou verifique novamente mais tarde.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {properties.map((property) => (
              <div key={property.id} className="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-lg transition-shadow">
                {/* Property Image */}
                <div className="relative h-48">
                  <img
                    src={getPropertyImage(property)}
                    alt={property.titulo}
                    loading="lazy"
                    className="w-full h-full object-cover"
                  />

                  <button 
                      onClick={() => handleToggleFavorite(property.id)}
                      aria-label={`Favoritar ${property.titulo}`}
                      className="absolute top-3 right-3 p-2 bg-white rounded-full shadow-md hover:bg-gray-50"
                    >
                      <Heart 
                        className={`w-4 h-4 transition-colors ${
                          favoriteIds.has(property.id) 
                            ? 'text-red-500 fill-current'
                            : 'text-gray-600'           
                        }`}
                      />
                    </button>

                    <div className="absolute bottom-3 left-3 bg-white px-2 py-1 rounded-md text-sm font-medium">
                    {property.tipo}
                  </div>
                </div>

                {/* Property Info */}
                <div className="p-4">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-semibold text-lg text-gray-900 truncate">
                      {property.titulo}
                    </h3>
                    <div className="flex items-center">
                        {(() => {
                          const r = getPropertyRating(property);
                          return (
                            <>
                              <Star className={`w-4 h-4 ${r ? 'text-yellow-400' : 'text-gray-300'}`} />
                              <span className="text-sm text-gray-600 ml-1">{r ? r.toFixed(1) : '—'}</span>
                            </>
                          );
                        })()}
                    </div>
                  </div>

                  {/* Owner actions */}
                  {currentUserId && property.proprietario === currentUserId && (
                    <div className="flex items-center gap-2 mb-3">
                      <Button
                        variant="secondary"
                        className="px-3"
                        onClick={() => navigate(`/add-property?edit=${property.id}`)}
                      >
                        Editar
                      </Button>
                      <Button
                        variant="destructive"
                        className="px-3"
                        onClick={async () => {
                          try {
                            await axios.delete(`${API_BASE_URL}/propriedades/propriedades/${property.id}/`, {
                              headers: getAuthHeaders(),
                            });
                            setProperties((prev) => prev.filter((p) => p.id !== property.id));
                          } catch (err) {
                            console.error('Erro ao excluir propriedade:', err);
                            setError('Não foi possível excluir a propriedade.');
                          }
                        }}
                      >
                        Excluir
                      </Button>
                    </div>
                  )}

                  <div className="flex items-center text-gray-600 mb-3">
                    <MapPin className="w-4 h-4 mr-1" />
                    <span className="text-sm truncate">{property.cidade}, {property.estado}</span>
                  </div>

                  <p className="text-gray-600 text-sm mb-4 line-clamp-2">
                    {property.descricao}
                  </p>

                  {/* Amenities */}
                  <div className="flex items-center gap-4 mb-4 text-sm text-gray-600">
                    <div className="flex items-center">
                      <Bed className="w-4 h-4 mr-1" />
                      <span>{property.quartos}</span>
                    </div>
                    <div className="flex items-center">
                      <Bath className="w-4 h-4 mr-1" />
                      <span>{property.banheiros}</span>
                    </div>
                    {property.estacionamento && (
                      <div className="flex items-center">
                        <Car className="w-4 h-4 mr-1" />
                      </div>
                    )}
                    {property.internet && (
                      <div className="flex items-center">
                        <Wifi className="w-4 h-4 mr-1" />
                      </div>
                    )}
                  </div>

                  {/* Tags */}
                  <div className="flex flex-wrap gap-2 mb-4">
                    {property.mobiliado && (
                      <span className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full">
                        Mobiliado
                      </span>
                    )}
                    {property.aceita_pets && (
                      <span className="px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">
                        Pet Friendly
                      </span>
                    )}
                  </div>

                  {/* Price and Action */}
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-2xl font-bold text-gray-900">
                        {formatPrice(property.preco)}
                      </span>
                      <span className="text-gray-600 text-sm">/mês</span>
                    </div>
                    <Button className="bg-orange-500 hover:bg-orange-600" onClick={() => navigate(`/properties/${property.id}`)}>
                      Ver detalhes
                    </Button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};