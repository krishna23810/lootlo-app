import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

export default function CreateGamePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [form, setForm] = useState({
    gameName: '',
    isFeatured: false,
    scheduledStartTime: '',
    ticketPriceCents: 5000,
    maxTicketCount: 100,
    maxTicketsPerUser: 6,
    commissionPercentage: 10,
    prizeConfig: {
      full_house: 40,
      top_line: 15,
      middle_line: 15,
      bottom_line: 15,
      early_five: 10,
      four_corners: 5,
    },
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    try {
      await api.post('/admin/games', {
        ...form,
        scheduledStartTime: new Date(form.scheduledStartTime).toISOString(),
      });
      setSuccess('Game created successfully!');
      setTimeout(() => navigate('/games'), 1500);
    } catch (err: any) {
      const msg = err.response?.data?.message || 'Failed to create game';
      const fields = err.response?.data?.fields;
      if (fields) {
        setError(`${msg}: ${Object.values(fields).join(', ')}`);
      } else {
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  };

  const totalPrize = Object.values(form.prizeConfig).reduce((a, b) => a + b, 0);

  return (
    <div className="max-w-2xl">
      <h2 className="text-2xl font-bold text-gray-800 mb-6">Create New Game</h2>

      {error && <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4">{error}</div>}
      {success && <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg mb-4">{success}</div>}

      <form onSubmit={handleSubmit} className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 space-y-6">
        {/* Game Name */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Game Name</label>
          <input
            type="text"
            value={form.gameName}
            onChange={(e) => setForm({ ...form, gameName: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            placeholder="e.g. Sunday Mega Housie"
            maxLength={100}
            required
          />
        </div>

        {/* Featured Toggle */}
        <div
          onClick={() => setForm({ ...form, isFeatured: !form.isFeatured })}
          className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all ${
            form.isFeatured
              ? 'border-amber-400 bg-amber-50'
              : 'border-gray-200 bg-gray-50 hover:border-gray-300'
          }`}
        >
          <div className={`w-10 h-10 rounded-full flex items-center justify-center text-xl ${
            form.isFeatured ? 'bg-amber-400' : 'bg-gray-200'
          }`}>
            ⭐
          </div>
          <div className="flex-1">
            <p className="font-semibold text-gray-800">Featured Game</p>
            <p className="text-xs text-gray-500">Show this game in the highlighted banner at the top of the app</p>
          </div>
          <div className={`w-12 h-6 rounded-full transition-colors relative ${
            form.isFeatured ? 'bg-amber-400' : 'bg-gray-300'
          }`}>
            <div className={`absolute top-1 w-4 h-4 rounded-full bg-white shadow transition-all ${
              form.isFeatured ? 'left-7' : 'left-1'
            }`} />
          </div>
        </div>

        {/* Start Time */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Scheduled Start Time</label>
          <input
            type="datetime-local"
            value={form.scheduledStartTime}
            onChange={(e) => setForm({ ...form, scheduledStartTime: e.target.value })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            required
          />
          <p className="text-xs text-gray-500 mt-1">Must be at least 30 minutes in the future</p>
        </div>

        {/* Ticket Price */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Ticket Price (₹)</label>
          <input
            type="number"
            value={form.ticketPriceCents / 100}
            onChange={(e) => setForm({ ...form, ticketPriceCents: Number(e.target.value) * 100 })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            min={1}
            required
          />
        </div>

        {/* Max Tickets */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Max Tickets (10-1000)</label>
          <input
            type="number"
            value={form.maxTicketCount}
            onChange={(e) => setForm({ ...form, maxTicketCount: Number(e.target.value) })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            min={10}
            max={1000}
            required
          />
        </div>

        {/* Max Tickets Per User */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Max Tickets Per User (1-10)</label>
          <input
            type="number"
            value={form.maxTicketsPerUser}
            onChange={(e) => setForm({ ...form, maxTicketsPerUser: Number(e.target.value) })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            min={1}
            max={10}
            required
          />
        </div>

        {/* Commission */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Commission % (1-30)</label>
          <input
            type="number"
            value={form.commissionPercentage}
            onChange={(e) => setForm({ ...form, commissionPercentage: Number(e.target.value) })}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            min={1}
            max={30}
            required
          />
        </div>

        {/* Prize Distribution */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Prize Distribution (must sum to 100%) — Current: <span className={totalPrize === 100 ? 'text-green-600' : 'text-red-600'}>{totalPrize}%</span>
          </label>
          <div className="grid grid-cols-2 gap-3">
            {Object.entries(form.prizeConfig).map(([key, value]) => (
              <div key={key} className="flex items-center gap-2">
                <label className="text-sm text-gray-600 w-28 capitalize">{key.replace(/_/g, ' ')}</label>
                <input
                  type="number"
                  value={value}
                  onChange={(e) => setForm({
                    ...form,
                    prizeConfig: { ...form.prizeConfig, [key]: Number(e.target.value) },
                  })}
                  className="w-20 px-2 py-1 border border-gray-300 rounded text-center"
                  min={0}
                  max={100}
                />
                <span className="text-xs text-gray-500">%</span>
              </div>
            ))}
          </div>
        </div>

        {/* Submit */}
        <button
          type="submit"
          disabled={loading || totalPrize !== 100}
          className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-lg font-semibold transition-colors disabled:opacity-50"
        >
          {loading ? 'Creating...' : 'Create Game'}
        </button>
      </form>
    </div>
  );
}
