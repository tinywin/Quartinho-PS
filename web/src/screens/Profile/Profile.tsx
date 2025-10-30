import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import { API_BASE_URL, getAuthHeaders } from '../../utils/apiConfig';
import { getUserData, saveUserData } from '../../utils/auth';
import { Button } from '../../components/ui/button';

const Profile = (): JSX.Element => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [cpf, setCpf] = useState('');
  const [dataNascimento, setDataNascimento] = useState('');
  const [telefone, setTelefone] = useState('');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);

  useEffect(() => {
    const fetch = async () => {
      setLoading(true);
      try {
        const res = await axios.get(`${API_BASE_URL}/usuarios/me/`, { headers: getAuthHeaders() });
        const d = res.data || {};
        setUsername(d.username ?? '');
        setEmail(d.email ?? '');
        setCpf(d.cpf ?? '');
        setDataNascimento(d.data_nascimento ?? '');
        setTelefone(d.telefone ?? '');
        setAvatarPreview(d.avatar ?? null);
      } catch (err) {
        // if not authenticated or error, fallback to localStorage
        const local = getUserData();
        setUsername(local?.full_name || local?.username || '');
        setEmail(local?.email || '');
      } finally {
        setLoading(false);
      }
    };
    fetch();
  }, []);

  const onFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0] ?? null;
    setAvatarFile(f);
    if (f) setAvatarPreview(URL.createObjectURL(f));
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const form = new FormData();
      if (username) form.append('username', username);
      if (email) form.append('email', email);
      if (cpf) form.append('cpf', cpf);
      if (dataNascimento) form.append('data_nascimento', dataNascimento);
      if (telefone) form.append('telefone', telefone);
      if (avatarFile) form.append('avatar', avatarFile);

      const res = await axios.patch(`${API_BASE_URL}/usuarios/me/`, form, {
        headers: {
          ...getAuthHeaders(),
          'Content-Type': 'multipart/form-data',
        },
      });

      const d = res.data || {};
      // persist to localStorage for quick access
      try {
        saveUserData({ id: d.id, email: d.email, full_name: d.username, avatar: d.avatar, telefone: d.telefone });
      } catch (e) {
        // ignore
      }

      setSuccess('Perfil atualizado com sucesso');
      setAvatarPreview(d.avatar ?? avatarPreview);
      // short delay then navigate back
      setTimeout(() => {
        navigate('/properties');
      }, 900);
    } catch (err: any) {
      console.error('Erro ao atualizar perfil', err);
      setError('Não foi possível atualizar o perfil.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="p-6">Carregando...</div>;

  return (
    <div className="max-w-2xl mx-auto p-6 bg-white rounded mt-8">
      <h2 className="text-xl font-semibold mb-4">Meu Perfil</h2>
      {error && <div className="mb-4 text-red-600">{error}</div>}
      {success && <div className="mb-4 text-green-600">{success}</div>}

      <div className="flex items-center gap-4 mb-4">
        <div className="w-20 h-20 rounded-full overflow-hidden bg-gray-100">
          {avatarPreview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={avatarPreview} alt="avatar" className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-gray-500">U</div>
          )}
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Alterar foto</label>
          <input type="file" accept="image/*" onChange={onFileChange} />
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4">
        <div>
          <label className="block text-sm text-gray-700">Nome</label>
          <input value={username} onChange={(e) => setUsername(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">Email</label>
          <input value={email} onChange={(e) => setEmail(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">CPF</label>
          <input value={cpf} onChange={(e) => setCpf(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">Data de nascimento</label>
          <input type="date" value={dataNascimento} onChange={(e) => setDataNascimento(e.target.value)} className="w-full px-3 py-2 border rounded" />
        </div>
        <div>
          <label className="block text-sm text-gray-700">Telefone</label>
          <input type="tel" value={telefone} onChange={(e) => setTelefone(e.target.value)} className="w-full px-3 py-2 border rounded" placeholder="(11) 99999-9999" />
        </div>
      </div>

      <div className="mt-6 flex gap-3">
        <Button onClick={handleSave} className="bg-orange-500" disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</Button>
        <Button variant="secondary" onClick={() => navigate(-1)}>Cancelar</Button>
      </div>
    </div>
  );
};

export default Profile;
