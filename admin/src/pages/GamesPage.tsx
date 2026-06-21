import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api';

interface Game {
  id: string;
  gameName: string;
  isFeatured: boolean;
  scheduledStartTime: string;
  ticketPriceCents: number;
  maxTicketCount: number;
  soldTicketCount: number;
  availableTickets: number;
  maxTicketsPerUser: number;
  commissionPercentage: number;
  prizePoolCents: number;
  state: string;
}

export default function GamesPage() {
  const [games, setGames] = useState<Game[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [editingGame, setEditingGame] = useState<Game | null>(null);
  const [editForm, setEditForm] = useState({ gameName: '', isFeatured: false, scheduledStartTime: '', ticketPriceCents: 0, maxTicketCount: 0, maxTicketsPerUser: 6, commissionPercentage: 0 });

  useEffect(() => {
    fetchGames();
  }, []);

  const fetchGames = async () => {
    try {
      const res = await api.get('/admin/games');
      setGames(res.data.data);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to fetch games');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (gameId: string) => {
    if (!window.confirm('Are you sure you want to delete this game?')) return;
    try {
      await api.delete(`/admin/games/${gameId}`);
      setGames(games.filter(g => g.id !== gameId));
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to delete game');
    }
  };

  const handleEdit = (game: Game) => {
    setEditingGame(game);
    setEditForm({
      gameName: game.gameName ?? '',
      isFeatured: game.isFeatured,
      scheduledStartTime: new Date(game.scheduledStartTime).toISOString().slice(0, 16),
      ticketPriceCents: game.ticketPriceCents,
      maxTicketCount: game.maxTicketCount,
      maxTicketsPerUser: game.maxTicketsPerUser ?? 6,
      commissionPercentage: game.commissionPercentage,
    });
  };
 
  const handleSaveEdit = async () => {
    if (!editingGame) return;
    try {
      await api.patch(`/admin/games/${editingGame.id}`, {
        gameName: editForm.gameName,
        isFeatured: editForm.isFeatured,
        scheduledStartTime: new Date(editForm.scheduledStartTime).toISOString(),
        ticketPriceCents: editForm.ticketPriceCents,
        maxTicketCount: editForm.maxTicketCount,
        maxTicketsPerUser: editForm.maxTicketsPerUser,
        commissionPercentage: editForm.commissionPercentage,
      });
      setEditingGame(null);
      fetchGames();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to update game');
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-800">Games</h2>
        <Link
          to="/games/create"
          className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium"
        >
          + Create Game
        </Link>
      </div>

      {error && <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">{error}</div>}

      {loading ? (
        <div className="text-center py-12 text-gray-500">Loading games...</div>
      ) : games.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <p className="text-lg">No games yet</p>
          <p className="text-sm mt-2">Create your first game to get started!</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Game</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Start Time</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Price</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Tickets</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Pool</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">State</th>
                <th className="text-left px-6 py-3 text-sm font-semibold text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {games.map((game) => (
                <tr key={game.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 font-medium text-gray-800">
                    <div className="flex items-center gap-2">
                      {game.isFeatured && <span title="Featured">⭐</span>}
                      <span title={game.id}>{game.gameName}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-gray-600">{new Date(game.scheduledStartTime).toLocaleString()}</td>
                  <td className="px-6 py-4 text-gray-600">₹{(game.ticketPriceCents / 100).toFixed(0)}</td>
                  <td className="px-6 py-4 text-gray-600">
                    <div>{game.soldTicketCount}/{game.maxTicketCount}</div>
                    <div className="text-xs text-gray-400">Limit: {game.maxTicketsPerUser ?? 6}/user</div>
                  </td>
                  <td className="px-6 py-4 text-gray-600">₹{(game.prizePoolCents / 100).toFixed(0)}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded-full text-xs font-semibold uppercase tracking-wider ${
                      game.state === 'upcoming' ? 'bg-blue-100 text-blue-700' :
                      game.state === 'live' ? 'bg-rose-100 text-rose-700 animate-pulse font-bold' :
                      game.state === 'completed' ? 'bg-emerald-100 text-emerald-700' :
                      game.state === 'cancelled' ? 'bg-gray-100 text-gray-600' :
                      'bg-gray-100 text-gray-700'
                    }`}>
                      {game.state}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2 items-center">
                      {(game.state === 'upcoming' || game.state === 'live') && (
                        <Link
                          to={`/games/${game.id}/host`}
                          className="px-3 py-1 text-xs bg-emerald-50 text-emerald-600 rounded-lg hover:bg-emerald-100 font-medium transition-colors"
                        >
                          Host Live
                        </Link>
                      )}
                      <button
                        onClick={() => handleEdit(game)}
                        className="px-3 py-1 text-xs bg-indigo-50 text-indigo-600 rounded-lg hover:bg-indigo-100 font-medium transition-colors"
                        disabled={game.state !== 'upcoming'}
                        title={game.state !== 'upcoming' ? 'Only upcoming games can be edited' : 'Edit game'}
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(game.id)}
                        className="px-3 py-1 text-xs bg-red-50 text-red-600 rounded-lg hover:bg-red-100 font-medium transition-colors"
                        disabled={game.soldTicketCount > 0}
                        title={game.soldTicketCount > 0 ? 'Cannot delete: tickets sold' : 'Delete game'}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Edit Modal */}
      {editingGame && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl">
            <h3 className="text-lg font-bold mb-4">Edit Game</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Game Name</label>
                <input
                  type="text"
                  value={editForm.gameName}
                  onChange={(e) => setEditForm({ ...editForm, gameName: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  placeholder="e.g. Sunday Mega Housie"
                  maxLength={100}
                />
              </div>

              {/* Featured Toggle */}
              <div
                onClick={() => setEditForm({ ...editForm, isFeatured: !editForm.isFeatured })}
                className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-all ${
                  editForm.isFeatured ? 'border-amber-400 bg-amber-50' : 'border-gray-200 bg-gray-50 hover:border-gray-300'
                }`}
              >
                <span className="text-lg">{editForm.isFeatured ? '⭐' : '☆'}</span>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-gray-800">Featured Game</p>
                  <p className="text-xs text-gray-500">Shown in the highlighted banner at the top of the app</p>
                </div>
                <div className={`w-10 h-5 rounded-full relative transition-colors ${
                  editForm.isFeatured ? 'bg-amber-400' : 'bg-gray-300'
                }`}>
                  <div className={`absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all ${
                    editForm.isFeatured ? 'left-5' : 'left-0.5'
                  }`} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
                <input
                  type="datetime-local"
                  value={editForm.scheduledStartTime}
                  onChange={(e) => setEditForm({ ...editForm, scheduledStartTime: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Ticket Price (₹)</label>
                <input
                  type="number"
                  value={editForm.ticketPriceCents / 100}
                  onChange={(e) => setEditForm({ ...editForm, ticketPriceCents: Number(e.target.value) * 100 })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Max Tickets</label>
                <input
                  type="number"
                  value={editForm.maxTicketCount}
                  onChange={(e) => setEditForm({ ...editForm, maxTicketCount: Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Max Tickets Per User</label>
                <input
                  type="number"
                  value={editForm.maxTicketsPerUser}
                  onChange={(e) => setEditForm({ ...editForm, maxTicketsPerUser: Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  min={1}
                  max={10}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Commission %</label>
                <input
                  type="number"
                  value={editForm.commissionPercentage}
                  onChange={(e) => setEditForm({ ...editForm, commissionPercentage: Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setEditingGame(null)} className="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200">Cancel</button>
              <button onClick={handleSaveEdit} className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">Save Changes</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
