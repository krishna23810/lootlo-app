import { useEffect, useState } from 'react';
import api from '../api';

interface Stats {
  totalUsers: number;
  totalGames: number;
  activeGames: number;
  totalRevenueCents: number;
  pendingWithdrawals: number;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/stats')
      .then(res => setStats(res.data.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-800 mb-6">Dashboard</h2>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Total Users"
          value={loading ? '...' : String(stats?.totalUsers ?? 0)}
          icon="👥"
          color="bg-blue-50 text-blue-700"
        />
        <StatCard
          title="Active Games"
          value={loading ? '...' : String(stats?.activeGames ?? 0)}
          icon="🎮"
          color="bg-green-50 text-green-700"
        />
        <StatCard
          title="Total Revenue"
          value={loading ? '...' : `₹${((stats?.totalRevenueCents ?? 0) / 100).toLocaleString()}`}
          icon="💰"
          color="bg-yellow-50 text-yellow-700"
        />
        <StatCard
          title="Pending Withdrawals"
          value={loading ? '...' : String(stats?.pendingWithdrawals ?? 0)}
          icon="⏳"
          color="bg-red-50 text-red-700"
        />
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
        <h3 className="text-lg font-semibold text-gray-800 mb-4">Quick Actions</h3>
        <div className="flex gap-4 flex-wrap">
          <a href="/games/create" className="px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium">
            + Create New Game
          </a>
          <a href="/games" className="px-6 py-3 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium">
            View All Games
          </a>
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, color }: { title: string; value: string; icon: string; color: string }) {
  return (
    <div className={`rounded-xl p-6 ${color} border border-gray-100`}>
      <div className="flex justify-between items-start">
        <div>
          <p className="text-sm font-medium opacity-70">{title}</p>
          <p className="text-2xl font-bold mt-1">{value}</p>
        </div>
        <span className="text-2xl">{icon}</span>
      </div>
    </div>
  );
}
