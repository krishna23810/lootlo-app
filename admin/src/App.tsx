import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import GamesPage from './pages/GamesPage';
import CreateGamePage from './pages/CreateGamePage';
import UsersPage from './pages/UsersPage';
import LiveHostPage from './pages/LiveHostPage';
import NotificationsPage from './pages/NotificationsPage';

function App() {
  const isLoggedIn = !!localStorage.getItem('admin_token');

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={isLoggedIn ? <Layout /> : <Navigate to="/login" />}>
          <Route index element={<DashboardPage />} />
          <Route path="games" element={<GamesPage />} />
          <Route path="games/create" element={<CreateGamePage />} />
          <Route path="games/:gameId/host" element={<LiveHostPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="notifications" element={<NotificationsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
