import { useEffect, useState, useCallback } from 'react';
import api from '../api';

interface User {
  id: string;
  email: string;
  mobile: string;
  displayName: string;
}

interface Game {
  id: string;
  gameName: string;
  scheduledStartTime: string;
  prizePoolCents: number;
  soldTicketCount: number;
  state: string;
}

export default function NotificationsPage() {
  const [target, setTarget] = useState<'all' | 'user' | 'game'>('all');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');

  // User target state
  const [userSearch, setUserSearch] = useState('');
  const [users, setUsers] = useState<User[]>([]);
  const [searchingUsers, setSearchingUsers] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  // Game target state
  const [games, setGames] = useState<Game[]>([]);
  const [loadingGames, setLoadingGames] = useState(false);
  const [selectedGameId, setSelectedGameId] = useState('');

  // Submit / Request states
  const [submitting, setSubmitting] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  // Fetch games when component mounts or target changes to 'game'
  useEffect(() => {
    if (target === 'game') {
      const fetchGames = async () => {
        setLoadingGames(true);
        setErrorMessage('');
        try {
          const res = await api.get('/admin/games');
          // Filter to show upcoming and live games since completed/cancelled won't have notification utility
          const activeGames = res.data.data.filter(
            (g: Game) => g.state === 'upcoming' || g.state === 'live'
          );
          setGames(activeGames);
          if (activeGames.length > 0) {
            setSelectedGameId(activeGames[0].id);
          } else {
            setSelectedGameId('');
          }
        } catch (err: any) {
          setErrorMessage(err.response?.data?.message || 'Failed to fetch games list');
        } finally {
          setLoadingGames(false);
        }
      };
      fetchGames();
    }
  }, [target]);

  // Search users helper
  const handleUserSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setUsers([]);
      return;
    }
    setSearchingUsers(true);
    setErrorMessage('');
    try {
      const res = await api.get('/admin/users', {
        params: { search: query, limit: 10 },
      });
      setUsers(res.data.data);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Failed to search users');
    } finally {
      setSearchingUsers(false);
    }
  }, []);

  // Handle user search input keystroke
  useEffect(() => {
    const delayDebounce = setTimeout(() => {
      if (target === 'user') {
        handleUserSearch(userSearch);
      }
    }, 400);

    return () => clearTimeout(delayDebounce);
  }, [userSearch, target, handleUserSearch]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSuccessMessage('');
    setErrorMessage('');

    // Validation
    if (!title.trim()) {
      setErrorMessage('Please enter a notification title.');
      return;
    }
    if (!body.trim()) {
      setErrorMessage('Please enter a notification body.');
      return;
    }
    if (target === 'user' && !selectedUser) {
      setErrorMessage('Please select a target user.');
      return;
    }
    if (target === 'game' && !selectedGameId) {
      setErrorMessage('Please select a target game.');
      return;
    }

    setSubmitting(true);
    try {
      const payload: Record<string, any> = {
        target,
        title: title.trim(),
        body: body.trim(),
      };

      if (target === 'user' && selectedUser) {
        payload.userId = selectedUser.id;
      } else if (target === 'game') {
        payload.gameId = selectedGameId;
      }

      const res = await api.post('/admin/notifications', payload);
      setSuccessMessage(
        `${res.data.message} Notified ${res.data.recipientCount} recipient(s).`
      );

      // Reset form fields
      setTitle('');
      setBody('');
      setSelectedUser(null);
      setUserSearch('');
      setUsers([]);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Failed to send notification');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto py-4">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            <span>🔔</span> Custom Notifications
          </h2>
          <p className="text-sm text-gray-500 mt-1">
            Send real-time system messages and push notifications to players.
          </p>
        </div>
      </div>

      {successMessage && (
        <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 px-4 py-4 rounded-xl mb-6 shadow-sm flex items-start gap-3">
          <span className="text-lg">✅</span>
          <div>
            <p className="font-semibold">Sent Successfully</p>
            <p className="text-sm opacity-90">{successMessage}</p>
          </div>
        </div>
      )}

      {errorMessage && (
        <div className="bg-rose-50 border border-rose-200 text-rose-800 px-4 py-4 rounded-xl mb-6 shadow-sm flex items-start gap-3">
          <span className="text-lg">❌</span>
          <div>
            <p className="font-semibold">Notification Error</p>
            <p className="text-sm opacity-90">{errorMessage}</p>
          </div>
        </div>
      )}

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-6 border-b border-gray-50 bg-gray-50/50">
          <h3 className="font-semibold text-gray-800">Notification Composer</h3>
          <p className="text-xs text-gray-400 mt-0.5">Define your audience and compose your alert message below.</p>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Target Selection */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">
              Recipient Audience
            </label>
            <div className="grid grid-cols-3 gap-3">
              {[
                { id: 'all', label: 'All Users', icon: '📣' },
                { id: 'user', label: 'Specific User', icon: '👤' },
                { id: 'game', label: 'Game Players', icon: '🎮' },
              ].map((opt) => (
                <button
                  key={opt.id}
                  type="button"
                  onClick={() => {
                    setTarget(opt.id as any);
                    setSuccessMessage('');
                    setErrorMessage('');
                  }}
                  className={`flex flex-col items-center justify-center p-4 rounded-xl border-2 transition-all cursor-pointer ${
                    target === opt.id
                      ? 'border-indigo-600 bg-indigo-50/50 text-indigo-700 font-medium'
                      : 'border-gray-200 hover:border-gray-300 text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  <span className="text-2xl mb-1">{opt.icon}</span>
                  <span className="text-sm">{opt.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* User Selection Search Panel */}
          {target === 'user' && (
            <div className="space-y-3 p-4 bg-gray-50 rounded-xl border border-gray-100 animate-fadeIn">
              <label className="block text-sm font-medium text-gray-700">
                Select Recipient User
              </label>

              {selectedUser ? (
                <div className="flex items-center justify-between p-3 bg-white rounded-lg border border-indigo-100 shadow-sm">
                  <div className="flex items-center gap-3">
                    <span className="text-xl">👤</span>
                    <div>
                      <div className="font-medium text-gray-800">{selectedUser.displayName}</div>
                      <div className="text-xs text-gray-500">{selectedUser.email}</div>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedUser(null);
                      setUserSearch('');
                      setUsers([]);
                    }}
                    className="text-xs font-semibold text-rose-600 hover:text-rose-700 transition-colors"
                  >
                    Change User
                  </button>
                </div>
              ) : (
                <div className="relative">
                  <input
                    type="text"
                    placeholder="Search user by display name, email, or mobile..."
                    value={userSearch}
                    onChange={(e) => setUserSearch(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-sm"
                  />
                  {searchingUsers && (
                    <div className="absolute right-3 top-2.5 text-xs text-gray-400">Searching...</div>
                  )}

                  {users.length > 0 && (
                    <div className="absolute left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-10 max-h-60 overflow-y-auto divide-y divide-gray-100">
                      {users.map((u) => (
                        <div
                          key={u.id}
                          onClick={() => {
                            setSelectedUser(u);
                            setUsers([]);
                          }}
                          className="px-4 py-2 hover:bg-indigo-50/50 cursor-pointer flex justify-between items-center transition-colors"
                        >
                          <div>
                            <div className="text-sm font-medium text-gray-800">{u.displayName}</div>
                            <div className="text-xs text-gray-400">{u.email}</div>
                          </div>
                          <span className="text-xs text-gray-400 font-mono">{u.mobile}</span>
                        </div>
                      ))}
                    </div>
                  )}

                  {userSearch && !searchingUsers && users.length === 0 && (
                    <div className="absolute left-0 right-0 mt-1 p-3 bg-white border border-gray-200 rounded-lg text-center text-xs text-gray-500 shadow-lg">
                      No matching users found.
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Game Selection Panel */}
          {target === 'game' && (
            <div className="space-y-3 p-4 bg-gray-50 rounded-xl border border-gray-100 animate-fadeIn">
              <label className="block text-sm font-medium text-gray-700">
                Select Active Game
              </label>

              {loadingGames ? (
                <div className="text-xs text-gray-500">Loading games...</div>
              ) : games.length === 0 ? (
                <div className="text-sm text-gray-500 p-2 bg-white rounded border border-gray-200 text-center">
                  No active games with ticket holders found.
                </div>
              ) : (
                <select
                  value={selectedGameId}
                  onChange={(e) => setSelectedGameId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-sm text-gray-800"
                >
                  {games.map((g) => (
                    <option key={g.id} value={g.id}>
                      {g.gameName} — {new Date(g.scheduledStartTime).toLocaleString('en-IN', {
                        day: 'numeric',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}{' '}
                      ({g.soldTicketCount} tickets sold)
                    </option>
                  ))}
                </select>
              )}
            </div>
          )}

          {/* Message Content */}
          <div className="space-y-4">
            <div>
              <label htmlFor="notif-title" className="block text-sm font-medium text-gray-700 mb-1">
                Notification Title
              </label>
              <input
                id="notif-title"
                type="text"
                maxLength={200}
                placeholder="Enter custom title (e.g. Server Maintenance Notice)"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-sm"
                required
              />
            </div>

            <div>
              <label htmlFor="notif-body" className="block text-sm font-medium text-gray-700 mb-1">
                Notification Body Message
              </label>
              <textarea
                id="notif-body"
                rows={4}
                placeholder="Type your push notification message body here..."
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-sm resize-none"
                required
              />
            </div>
          </div>

          {/* Action button */}
          <div className="pt-2 border-t border-gray-50 flex justify-end">
            <button
              type="submit"
              disabled={
                submitting ||
                (target === 'user' && !selectedUser) ||
                (target === 'game' && !selectedGameId)
              }
              className="w-full sm:w-auto px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl shadow-md hover:shadow-lg disabled:bg-gray-300 disabled:shadow-none disabled:cursor-not-allowed transition-all text-sm flex items-center justify-center gap-2 cursor-pointer"
            >
              {submitting ? (
                <>
                  <svg className="animate-spin h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                    <circle
                      className="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      strokeWidth="4"
                    />
                    <path
                      className="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    />
                  </svg>
                  <span>Sending Notification...</span>
                </>
              ) : (
                <>
                  <span>🚀</span>
                  <span>Send Notification</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
