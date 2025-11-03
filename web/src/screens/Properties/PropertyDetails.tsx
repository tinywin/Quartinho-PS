import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_BASE_URL, getAuthHeaders } from '../../utils/apiConfig';
import { Button } from '../../components/ui/button';
import { Star, MapPin, Heart, MessageSquare } from 'lucide-react';
import { MapContainer, TileLayer, Marker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import CommentsSection from './CommentsSection';

interface Property {
  id: number;
  titulo: string;
  descricao: string;
  fotos: Array<{ id: number; imagem: string; principal: boolean }>;
  preco?: number | string;
  endereco?: string;
  cidade?: string;
  quartos?: number;
  banheiros?: number;
  area?: number;
  mobiliado?: boolean;
  aceita_pets?: boolean;
  dono?: any;
  proprietario?: any;
  tags?: any[];
  favorito?: boolean;
  latitude?: number;
  longitude?: number;
}

const PropertyDetails = (): JSX.Element => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [property, setProperty] = useState<Property | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [currentPhoto, setCurrentPhoto] = useState(0);
  const [favorite, setFavorite] = useState(false);
  const [reviewsSummary, setReviewsSummary] = useState<{
    avg: number;
    count: number;
    avatars: string[];
  } | null>(null);
  const [mapPos, setMapPos] = useState<[number, number] | null>(null);

  // Fix leaflet default icon paths (same fix used in MapSelector)
  delete (L.Icon.Default.prototype as any)._getIconUrl;
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  });

  useEffect(() => {
    if (!id) return;

    const fetchReviewsSummary = async (propId: number) => {
      try {
        const res = await axios.get(`${API_BASE_URL}/propriedades/comentarios/?imovel=${propId}`);
        const data = res.data;
        const items = Array.isArray(data) ? data : (data.results ?? []);
        const notes = items.map((it: any) => Number(it.nota || it.rating || 0)).filter((n: number) => n > 0);
        const count = notes.length;
        const avg = count > 0 ? notes.reduce((a: number, b: number) => a + b, 0) / count : 0;

        const avatars: string[] = [];
        for (const it of items) {
          const usuario = it.usuario || it.autor || null;
          if (!usuario) continue;
          let avatar: string | null = null;
          if (typeof usuario !== 'string') {
            avatar = usuario.avatar || usuario.avatar_url || usuario.foto || usuario.image || null;
            if (avatar && typeof avatar === 'string' && !avatar.startsWith('http')) {
              avatar = `${API_BASE_URL}${avatar.startsWith('/') ? '' : '/'}${avatar}`;
            }
          }
          if (avatar) avatars.push(avatar);
          if (avatars.length >= 3) break;
        }

        setReviewsSummary({ avg, count, avatars });
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('Erro ao buscar resumo de avaliações', err);
      }
    };

    const fetchProperty = async () => {
      setLoading(true);
      try {
        const response = await axios.get(`${API_BASE_URL}/propriedades/propriedades/${id}/`, {
          headers: getAuthHeaders(),
        });
        setProperty(response.data);
        // set map position if backend provides coordinates
        const lat = response.data?.latitude ?? response.data?.lat ?? null;
        const lng = response.data?.longitude ?? response.data?.lng ?? null;
        if (lat != null && lng != null) {
          setMapPos([Number(lat), Number(lng)]);
        } else if (response.data?.endereco) {
          // try to geocode address via Nominatim
          try {
            const q = encodeURIComponent(response.data.endereco);
            const geo = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${q}`);
            const geoJson = await geo.json();
            if (Array.isArray(geoJson) && geoJson.length > 0) {
              setMapPos([Number(geoJson[0].lat), Number(geoJson[0].lon)]);
            }
          } catch (e) {
            // ignore geocoding errors
          }
        }
        if (response.data && (response.data.favorito === true || response.data.favorito === false)) {
          setFavorite(response.data.favorito === true);
        }

        // fetch reviews summary after we know id
        fetchReviewsSummary(Number(id));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('Erro ao buscar propriedade:', err);
        setError('Não foi possível carregar a propriedade.');
      } finally {
        setLoading(false);
      }
    };

    fetchProperty();
  }, [id]);

  const getImage = () => {
    const principal = property?.fotos?.find((f) => f.principal);
    return principal?.imagem || property?.fotos?.[0]?.imagem || '/placeholder-property.jpg';
  };

  const toggleFavorite = async () => {
    if (!property) return;
    try {
      // optimistic UI
      setFavorite((v) => !v);
      await axios.post(
        `${API_BASE_URL}/propriedades/propriedade/${property.id}/favoritar/`,
        {},
        { headers: getAuthHeaders() }
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Erro ao favoritar:', err);
      setFavorite((v) => !v); // revert
    }
  };

  const InfoChip = ({ label, value }: { label: string; value: string }) => (
    <div className="px-3 py-1 bg-gray-100 rounded-full text-sm text-gray-700 flex items-center gap-2">
      <span className="font-medium">{label}:</span>
      <span>{value}</span>
    </div>
  );

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
          <p className="text-gray-600">Carregando propriedade...</p>
        </div>
      </div>
    );
  }

  if (error || !property) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-600">{error || 'Propriedade não encontrada.'}</p>
          <button onClick={() => navigate('/properties')} className="mt-4 px-4 py-2 bg-orange-500 text-white rounded">Voltar</button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto p-0 bg-white rounded shadow mt-8">
        {/* Gallery */}
        <div className="relative">
          <div className="h-64 md:h-96 w-full overflow-hidden rounded-b-2xl">
            {property.fotos && property.fotos.length > 0 ? (
              <img src={property.fotos[currentPhoto].imagem || getImage()} alt={property.titulo} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full bg-gray-100 flex items-center justify-center">
                <div className="text-gray-400">Sem imagem</div>
              </div>
            )}
          </div>

          {/* Back button */}
          <button onClick={() => navigate(-1)} className="absolute top-4 left-4 bg-white p-2 rounded-full shadow">
            ←
          </button>

          {/* Favorite */}
          <button onClick={toggleFavorite} className="absolute top-4 right-4 bg-white p-2 rounded-full shadow">
            <Heart className={`w-5 h-5 ${favorite ? 'text-red-500' : 'text-gray-600'}`} />
          </button>

          {/* Photo navigation */}
          {property.fotos && property.fotos.length > 1 && (
            <div className="absolute bottom-3 left-1/2 transform -translate-x-1/2 flex gap-2">
              {property.fotos.map((_: any, idx: number) => (
                <button key={idx} onClick={() => setCurrentPhoto(idx)} className={`w-2 h-2 rounded-full ${idx === currentPhoto ? 'bg-white' : 'bg-white/50'}`} />
              ))}
            </div>
          )}
        </div>

        <div className="p-6">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="text-2xl md:text-3xl font-bold mb-2">{property.titulo}</h1>
                  
                  <div className="text-2xl font-bold text-[color:var(--price-purple,#CBACFF)] mb-2">R$ {property.preco} <span className="text-sm text-gray-500">/ mês</span></div>
            </div>
          </div>

          {/* Description */}
          <div className="text-gray-700 text-sm whitespace-pre-wrap mb-4">{property.descricao}</div>

          {/* Owner (pill) */}
          {(property.dono || property.proprietario) && (
            <div className="mb-4">
              <div className="flex items-center justify-between bg-purple-50 border border-purple-100 rounded-xl p-3">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-white overflow-hidden shadow-sm">
                    {(() => {
                      const dono = property.dono || property.proprietario;
                      const avatar = dono?.avatar || dono?.foto || dono?.avatar_url || null;
                      const avatarUrl = avatar && avatar.toString().startsWith('http') ? avatar.toString() : avatar ? `${API_BASE_URL}${avatar}` : null;
                      return avatarUrl ? <img src={avatarUrl} alt={dono?.full_name || dono?.nome || ''} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-purple-500">H</div>;
                    })()}
                  </div>
                  <div>
                      <div className="font-semibold text-gray-800">{(property.dono || property.proprietario)?.full_name || (property.dono || property.proprietario)?.nome || (property.dono || property.proprietario)?.username}</div>
                      <div className="text-sm text-gray-600">{(property.proprietario && (property.proprietario.nome_completo || property.proprietario.full_name || property.proprietario.username)) || (property.dono && (property.dono.nome_completo || property.dono.full_name || property.dono.username)) || ''}</div>
                  </div>
                </div>
                <button className="p-2 border border-purple-200 rounded text-purple-600 bg-white">
                  <MessageSquare className="w-5 h-5" />
                </button>
              </div>
            </div>
          )}
          {/* Action buttons below owner info (Eu quero! / Entrar em contato) */}
              <div className="mt-3 flex gap-3">
                {(() => {
                  const dono = property.dono || property.proprietario;
                  const ownerEmail = dono?.email || dono?.username || null;
                  const handleExpressInterest = () => {
                    // navigate to the request form so the user can submit name/cpf/phone and upload comprovante
                    if (property && property.id) {
                      navigate(`/properties/${property.id}/request`);
                    } else if (id) {
                      navigate(`/properties/${id}/request`);
                    } else {
                      window.alert('Imóvel não identificado.');
                    }
                  };

                  const handleContact = () => {
                    if (ownerEmail && ownerEmail.includes('@')) {
                      window.location.href = `mailto:${ownerEmail}`;
                    } else {
                      window.alert('Contato: email do proprietário não disponível.');
                    }
                  };

                  return (
                    <>
                      <button onClick={handleExpressInterest} className="flex-1 px-4 py-2 rounded-full border border-purple-400 text-purple-700 bg-white hover:bg-purple-50">
                        Eu quero!
                      </button>
                      <button onClick={handleContact} className="flex-1 px-4 py-2 rounded-full bg-purple-600 text-white hover:brightness-105">
                        Entrar em contato
                      </button>
                    </>
                  );
                })()}
              </div>

          {/* Address */}
          {(property.endereco || property.cidade) && (
            <div className="flex flex-col gap-2 mt-4 text-gray-700">
              <div className="flex items-center gap-2 text-purple-600">
                <MapPin className="w-4 h-4" />
                <div className="text-sm">{property.endereco ? `${property.endereco}` : ''}</div>
              </div>
              {property.cidade && (
                <div className="flex items-center gap-2 text-purple-600 text-sm">
                  <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z" fill="currentColor"/></svg>
                  <div className="capitalize">{String(property.cidade)}</div>
                </div>
              )}
            </div>
          )}

          {/* Chips */}
          <div className="flex flex-wrap gap-2 mt-4">
            {property.quartos != null && <InfoChip label="Quartos" value={String(property.quartos)} />}
            {property.banheiros != null && <InfoChip label="Banheiros" value={String(property.banheiros)} />}
            {property.area != null && <InfoChip label="Área" value={`${property.area} m²`} />}
            {property.mobiliado != null && <InfoChip label="Mobiliado" value={property.mobiliado ? 'Sim' : 'Não'} />}
            {property.aceita_pets != null && <InfoChip label="Aceita pets" value={property.aceita_pets ? 'Sim' : 'Não'} />}
          </div>

          {/* Tags */}
          {property.tags && Array.isArray(property.tags) && property.tags.length > 0 && (
            <div className="mt-6">
              <div className="font-semibold mb-2">Características adicionais</div>
              <div className="flex flex-wrap gap-2">
                {property.tags.map((t: any, i: number) => (
                  <div key={i} className="px-3 py-1 bg-purple-50 text-purple-700 rounded">{String(t)}</div>
                ))}
              </div>
            </div>
          )}

          {/* Map preview showing where the property is located (moved above reviews) */}
          {mapPos && (
            <div className="mt-6 rounded-2xl overflow-hidden border border-gray-200">
              <MapContainer center={mapPos} zoom={15} style={{ height: 220, width: '100%' }}>
                <TileLayer
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />
                <Marker position={mapPos} />
              </MapContainer>
            </div>
          )}

          {/* Reviews summary - moved below tags and above comments */}
          {reviewsSummary && (
            <div className="mt-6">
              <div className="bg-pink-100 rounded-2xl p-3 flex items-center gap-4 max-w-md">
                <div className="w-12 h-12 rounded-xl bg-pink-300 flex items-center justify-center">
                  <Star className="w-6 h-6 text-yellow-400" />
                </div>

                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <div className="flex items-center gap-1 text-yellow-400">
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Star key={i} className={`w-4 h-4 ${i < Math.round(reviewsSummary.avg) ? 'text-yellow-400' : 'text-yellow-100'}`} />
                      ))}
                    </div>
                    <div className="text-xl font-bold">{reviewsSummary.avg.toFixed(1)}</div>
                  </div>
                  <div className="text-sm text-gray-600">De {reviewsSummary.count} usuários</div>
                </div>

                <div className="flex -space-x-2">
                  {reviewsSummary.avatars.map((a, i) => (
                    <img key={i} src={a} alt={`avatar-${i}`} className="w-8 h-8 rounded-full border-2 border-white shadow-sm" />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Comments */}
          {property.id && <CommentsSection propertyId={property.id} />}

          <div className="mt-6">
            <Button onClick={() => navigate('/properties')} className="bg-orange-500 text-white">Voltar</Button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PropertyDetails;
