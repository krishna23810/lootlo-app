import { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../api';

interface Game {
  id: string;
  gameName: string;
  state: 'upcoming' | 'live' | 'completed' | 'cancelled';
  ticketPriceCents: number;
  maxTicketCount: number;
  soldTicketCount: number;
  commissionPercentage: number;
  prizePoolCents: number;
  prizeConfig: {
    full_house: number;
    top_line: number;
    middle_line: number;
    bottom_line: number;
    early_five: number;
    four_corners: number;
  };
}

interface Claim {
  id: string;
  userId: string;
  displayName: string;
  pattern: string;
  status: 'pending' | 'valid' | 'invalid';
  prizeAmountCents: number;
  claimedAtPosition: number;
}

interface DrawEvent {
  number: number;
  position: number;
}

// ─── Zero-Dependency Socket.io Client over native WebSockets ─────────────────
class SimpleSocket {
  private ws: WebSocket | null = null;
  private listeners: { [event: string]: Function[] } = {};
  private shouldClose = false;

  constructor(url: string) {
    // Convert HTTP URL to WS URL
    const wsUrl = url.replace(/^http/, 'ws') + '/socket.io/?EIO=4&transport=websocket';
    this.ws = new WebSocket(wsUrl);

    this.ws.onmessage = (event) => {
      const data = event.data as string;
      if (data === '2') {
        this.ws?.send('3'); // Heartbeat response (Ping-Pong)
        return;
      }
      if (data.startsWith('40')) {
        const handlers = this.listeners['connect'] || [];
        handlers.forEach((cb) => cb());
        return;
      }
      if (data.startsWith('42')) {
        try {
          const parsed = JSON.parse(data.substring(2));
          const [eventName, payload] = parsed;
          const handlers = this.listeners[eventName] || [];
          handlers.forEach((cb) => cb(payload));
        } catch (e) {
          console.error('Failed to parse Socket.io message:', e);
        }
      }
    };

    this.ws.onopen = () => {
      if (this.shouldClose) {
        this.ws?.close();
        return;
      }
      this.ws?.send('40'); // Connect to Socket.io root namespace
    };
  }

  emit(event: string, ...args: any[]) {
    this.ws?.send(`42${JSON.stringify([event, ...args])}`);
  }

  on(event: string, callback: Function) {
    if (!this.listeners[event]) this.listeners[event] = [];
    this.listeners[event].push(callback);
  }

  close() {
    if (this.ws) {
      if (this.ws.readyState === WebSocket.CONNECTING) {
        this.shouldClose = true;
      } else {
        this.ws.close();
      }
    }
  }
}

export default function LiveHostPage() {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();

  const [game, setGame] = useState<Game | null>(null);
  const [drawnNumbers, setDrawnNumbers] = useState<DrawEvent[]>([]);
  const [claims, setClaims] = useState<Claim[]>([]);
  const [strikes, setStrikes] = useState<{ [userId: string]: number }>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Sockets
  const socketRef = useRef<SimpleSocket | null>(null);

  // WebRTC & Janus State
  const [mediaStream, setMediaStream] = useState<MediaStream | null>(null);
  const [janusState, setJanusState] = useState<'disconnected' | 'connecting' | 'streaming' | 'error'>('disconnected');
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const pcRef = useRef<RTCPeerConnection | null>(null);
  const janusSessionIdRef = useRef<number | null>(null);
  const janusHandleIdRef = useRef<number | null>(null);
  const keepaliveIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const JANUS_URL = 'http://localhost:8088/janus';

  useEffect(() => {
    fetchGameDetails();
    initSocketConnection();

    return () => {
      socketRef.current?.close();
      stopStreaming();
    };
  }, [gameId]);

  const fetchGameDetails = async () => {
    try {
      const res = await api.get(`/games/${gameId}`);
      setGame(res.data.data);

      // If game is live or completed, fetch already drawn numbers
      if (res.data.data.state !== 'upcoming') {
        const numbersRes = await api.get(`/tickets/mine?gameId=${gameId}`); // Dummy/Mine endpoint returns drawEvents
        if (numbersRes.data.data.length > 0) {
          const events = numbersRes.data.data[0].game.drawEvents as number[];
          setDrawnNumbers(events.map((n, idx) => ({ number: n, position: idx + 1 })));
        }
      }
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to load game details');
    } finally {
      setLoading(false);
    }
  };

  const initSocketConnection = () => {
    const wsBaseUrl = import.meta.env.VITE_WS_URL || 'http://localhost:3000';
    const socket = new SimpleSocket(wsBaseUrl);
    socketRef.current = socket;

    socket.on('connect', () => {
      socket.emit('join', `game:${gameId}`);
    });

    socket.on('game:draw_number', (data: { number: number; position: number }) => {
      setDrawnNumbers((prev) => {
        if (prev.some((d) => d.number === data.number)) return prev;
        return [...prev, data];
      });
    });

    socket.on('game:state_change', (data: { state: Game['state'] }) => {
      setGame((prev) => (prev ? { ...prev, state: data.state } : null));
    });

    socket.on('game:claim_validation', (data: {
      userId: string;
      displayName: string;
      pattern: string;
      status: 'valid' | 'invalid';
      prizeAmountCents: number;
    }) => {
      const newClaim: Claim = {
        id: Math.random().toString(),
        userId: data.userId,
        displayName: data.displayName,
        pattern: data.pattern,
        status: data.status,
        prizeAmountCents: data.prizeAmountCents,
        claimedAtPosition: drawnNumbers.length,
      };

      setClaims((prev) => [newClaim, ...prev]);

      if (data.status === 'invalid') {
        setStrikes((prev) => ({
          ...prev,
          [data.userId]: (prev[data.userId] || 0) + 1,
        }));
      }
    });
  };

  // ─── Janus WebRTC Publish Stream ───────────────────────────────────────────
  const startStreaming = async () => {
    setJanusState('connecting');
    try {
      // 1. Get webcam and mic stream
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 480, height: 360, frameRate: 15 },
        audio: true,
      });
      setMediaStream(stream);
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
      }

      // 2. Hash gameId to Janus Room ID
      let hash = 0;
      for (let i = 0; i < gameId!.length; i++) {
        hash = (hash << 5) - hash + gameId!.charCodeAt(i);
        hash |= 0;
      }
      const roomId = Math.abs(hash) % 100000000;

      // 3. Create Session on Janus Gateway
      const sessionRes = await fetch(JANUS_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'create',
          transaction: Math.random().toString(36).substring(7),
        }),
      });
      const sessionData = await sessionRes.json();
      const sessionId = sessionData.data.id;
      janusSessionIdRef.current = sessionId;

      // 4. Attach to VideoRoom plugin
      const attachRes = await fetch(`${JANUS_URL}/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'attach',
          plugin: 'janus.plugin.videoroom',
          transaction: Math.random().toString(36).substring(7),
        }),
      });
      const attachData = await attachRes.json();
      const handleId = attachData.data.id;
      janusHandleIdRef.current = handleId;

      // Helper: poll Janus long-poll endpoint until a condition is met
      const pollForEvent = async (
        sid: number,
        condition: (data: any) => boolean,
        label: string,
        maxAttempts = 30,
      ): Promise<any> => {
        let attempts = 0;
        for (let i = 0; i < maxAttempts * 3; i++) {
          try {
            const pollRes = await fetch(`${JANUS_URL}/${sid}?rid=${Date.now()}&maxev=1`);
            const pollData = await pollRes.json();
            console.log(`[Janus poll - ${label}] attempt ${attempts + 1}:`, pollData);
            
            // Skip keepalive messages — they don't count as real attempts
            if (pollData.janus === 'keepalive') {
              continue;
            }
            // Skip ack messages
            if (pollData.janus === 'ack') {
              continue;
            }
            
            attempts++;
            if (condition(pollData)) {
              return pollData;
            }
          } catch (e) {
            console.warn(`[Janus poll - ${label}] error:`, e);
            attempts++;
          }
          if (attempts >= maxAttempts) break;
          await new Promise((resolve) => setTimeout(resolve, 200));
        }
        return null;
      };

      // 4b. Create Room in Janus (in case it wasn't created by backend start event)
      const createRes = await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'message',
          transaction: Math.random().toString(36).substring(7),
          body: {
            request: 'create',
            room: roomId,
            description: `Lootlo Game Live Telecast ${gameId}`,
            publishers: 1,
            is_private: false,
          },
        }),
      });
      const createData = await createRes.json();
      console.log('[Janus] Room create POST response:', createData);
      // Room already existing (error_code 427) is fine

      // 5. Join Room as Publisher
      const joinRes = await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'message',
          transaction: Math.random().toString(36).substring(7),
          body: {
            request: 'join',
            room: roomId,
            ptype: 'publisher',
            id: 1,
            display: 'Host',
          },
        }),
      });
      const joinData = await joinRes.json();
      console.log('[Janus] Join POST response:', joinData);

      // Check if join was returned synchronously (some Janus versions do this)
      let joinedEvent: any = null;
      if (joinData.janus === 'success' && joinData.plugindata?.data?.videoroom === 'joined') {
        joinedEvent = joinData;
      } else if (joinData.janus === 'ack') {
        // Async mode: need to poll for the joined event
        joinedEvent = await pollForEvent(
          sessionId,
          (d) => d.janus === 'event' && d.plugindata?.data?.videoroom === 'joined',
          'join-room',
          20,
        );
      } else if (joinData.plugindata?.data?.videoroom === 'joined') {
        joinedEvent = joinData;
      }

      if (!joinedEvent) {
        throw new Error('Janus did not confirm room join. Cannot publish.');
      }
      console.log('Successfully joined room as publisher:', joinedEvent.plugindata?.data);

      // 6. Setup RTCPeerConnection
      const pc = new RTCPeerConnection({
        iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
      });
      pcRef.current = pc;

      // Register ICE Candidate Callback immediately to not miss early candidates
      pc.onicecandidate = async (ev) => {
        if (ev.candidate) {
          try {
            await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                janus: 'trickle',
                transaction: Math.random().toString(36).substring(7),
                candidate: {
                  candidate: ev.candidate.candidate,
                  sdpMid: ev.candidate.sdpMid,
                  sdpMLineIndex: ev.candidate.sdpMLineIndex,
                },
              }),
            });
          } catch (e) {
            console.error('Error trickling ICE candidate:', e);
          }
        }
      };

      // Add local media tracks to PeerConnection
      stream.getTracks().forEach((track) => pc.addTrack(track, stream));

      // Create WebRTC Offer
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      // 7. Publish WebRTC Offer to Janus VideoRoom
      const publishRes = await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'message',
          transaction: Math.random().toString(36).substring(7),
          body: {
            request: 'publish',
            audio: true,
            video: true,
          },
          jsep: {
            type: 'offer',
            sdp: offer.sdp,
          },
        }),
      });
      const publishData = await publishRes.json();
      console.log('[Janus] Publish POST response:', publishData);

      // 7b. Get the JSEP Answer — check if returned synchronously or need to poll
      let eventData: any = null;
      if (publishData.jsep) {
        // Synchronous response with JSEP answer
        eventData = publishData;
      } else if (publishData.janus === 'ack' || !publishData.jsep) {
        // Async mode: long-poll to retrieve the JSEP Answer from Janus
        eventData = await pollForEvent(
          sessionId,
          (d) => d.janus === 'event' && d.jsep,
          'publish-answer',
          25,
        );
      }

      if (!eventData || !eventData.jsep) {
        throw new Error('Janus did not return a JSEP answer for publisher configuration.');
      }

      // Set Janus SDP Answer
      await pc.setRemoteDescription(new RTCSessionDescription(eventData.jsep));

      // 7c. Signal end of ICE candidates (trickle complete)
      await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'trickle',
          transaction: Math.random().toString(36).substring(7),
          candidate: { completed: true },
        }),
      }).catch(() => {});

      // 8. Start keepalive loop to prevent Janus from destroying the session
      // Janus HTTP transport requires periodic long-poll or explicit keepalive
      keepaliveIntervalRef.current = setInterval(async () => {
        if (!janusSessionIdRef.current) return;
        try {
          await fetch(`${JANUS_URL}/${janusSessionIdRef.current}`, {
            method: 'GET',
          });
        } catch (e) {
          // Ignore keepalive errors
        }
      }, 15000); // Every 15 seconds (Janus default session timeout is 60s)

      setJanusState('streaming');
    } catch (err: any) {
      console.error('Janus streaming error:', err);
      setJanusState('error');
    }
  };

  const stopStreaming = () => {
    // Stop keepalive loop
    if (keepaliveIntervalRef.current) {
      clearInterval(keepaliveIntervalRef.current);
      keepaliveIntervalRef.current = null;
    }

    // Stop local camera tracks
    if (mediaStream) {
      mediaStream.getTracks().forEach((t) => t.stop());
      setMediaStream(null);
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }

    // Close peer connection
    if (pcRef.current) {
      pcRef.current.close();
      pcRef.current = null;
    }

    // Destroy session on Janus
    if (janusSessionIdRef.current) {
      const sessId = janusSessionIdRef.current;
      fetch(`${JANUS_URL}/${sessId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'destroy',
          transaction: Math.random().toString(36).substring(7),
        }),
      }).catch(() => {});
      janusSessionIdRef.current = null;
    }

    setJanusState('disconnected');
  };

  // ─── Game Management API calls ─────────────────────────────────────────────
  const startGame = async () => {
    try {
      await api.post(`/admin/games/${gameId}/start`);
      fetchGameDetails();
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to start game');
    }
  };

  const drawNextNumber = async () => {
    try {
      const res = await api.post(`/admin/games/${gameId}/draw`);
      const newD = res.data.data as DrawEvent;
      setDrawnNumbers((prev) => {
        if (prev.some((d) => d.number === newD.number)) return prev;
        return [...prev, newD];
      });
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to draw number');
    }
  };

  const endGame = async () => {
    if (!window.confirm('Are you sure you want to end this game session?')) return;
    try {
      await api.post(`/admin/games/${gameId}/end`);
      stopStreaming();
      fetchGameDetails();
      navigate('/games');
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to end game');
    }
  };

  const formatPatternName = (pattern: string) => {
    return pattern.replaceAll('_', ' ').toUpperCase();
  };

  if (loading) {
    return <div className="text-center py-12 text-gray-500">Loading game host session...</div>;
  }

  if (error || !game) {
    return (
      <div className="max-w-md mx-auto mt-12 bg-red-50 border border-red-200 text-red-700 px-6 py-4 rounded-xl">
        <h3 className="font-bold text-lg mb-2">Error loading session</h3>
        <p>{error || 'Game not found'}</p>
        <button onClick={() => navigate('/games')} className="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 font-semibold transition-colors">Go Back</button>
      </div>
    );
  }

  const latestDrawn = drawnNumbers[drawnNumbers.length - 1];

  return (
    <div className="max-w-6xl mx-auto p-6">
      {/* Header Info */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center bg-white p-6 rounded-2xl border border-gray-100 shadow-sm mb-6 gap-4">
        <div>
          <span className={`px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
            game.state === 'upcoming' ? 'bg-blue-100 text-blue-800' :
            game.state === 'live' ? 'bg-red-100 text-red-800 animate-pulse' :
            'bg-gray-100 text-gray-800'
          }`}>
            {game.state}
          </span>
          <h2 className="text-2xl font-extrabold text-gray-800 mt-2">{game.gameName}</h2>
          <p className="text-sm text-gray-400 mt-1">Game ID: <span className="font-mono">{game.id}</span></p>
        </div>

        <div className="flex gap-4">
          <div className="bg-gray-50 px-4 py-2 rounded-xl text-center">
            <p className="text-xs text-gray-400 font-semibold uppercase tracking-wider">Tickets Sold</p>
            <p className="text-lg font-bold text-gray-700">{game.soldTicketCount} / {game.maxTicketCount}</p>
          </div>
          <div className="bg-emerald-50 px-4 py-2 rounded-xl text-center border border-emerald-100">
            <p className="text-xs text-emerald-600 font-semibold uppercase tracking-wider">Prize Pool</p>
            <p className="text-lg font-bold text-emerald-700">₹{(game.prizePoolCents / 100).toFixed(0)}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left column: Video Stream + Controls */}
        <div className="space-y-6">
          {/* WebRTC Video Room Panel */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
              <span>📹</span> Live Telecast (Janus SFU)
            </h3>

            <div className="relative aspect-video bg-gray-900 rounded-xl overflow-hidden mb-4 border border-gray-800 flex items-center justify-center">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className="w-full h-full object-cover"
              />
              {!mediaStream && (
                <div className="absolute text-center text-gray-500 px-4">
                  <p className="text-sm font-semibold">Camera Feed Offline</p>
                  <p className="text-xs text-gray-600 mt-1">Start broadcasting to telecast live to players</p>
                </div>
              )}
              {janusState === 'streaming' && (
                <span className="absolute top-3 left-3 bg-red-600 text-white font-bold text-xs uppercase px-2 py-0.5 rounded shadow tracking-widest animate-pulse">
                  Live Stream
                </span>
              )}
            </div>

            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs font-semibold px-1 mb-2">
                <span className="text-gray-400">Stream Status:</span>
                <span className={`capitalize ${
                  janusState === 'streaming' ? 'text-red-600 font-bold' :
                  janusState === 'connecting' ? 'text-amber-600' :
                  janusState === 'error' ? 'text-red-700' : 'text-gray-500'
                }`}>
                  {janusState}
                </span>
              </div>

              {janusState === 'disconnected' || janusState === 'error' ? (
                <button
                  onClick={startStreaming}
                  className="w-full py-2.5 bg-indigo-600 text-white rounded-xl font-bold hover:bg-indigo-700 transition-colors shadow-sm"
                  disabled={game.state !== 'live'}
                >
                  Start Telecast
                </button>
              ) : (
                <button
                  onClick={stopStreaming}
                  className="w-full py-2.5 bg-gray-700 text-white rounded-xl font-bold hover:bg-gray-800 transition-colors"
                >
                  Stop Telecast
                </button>
              )}
            </div>
          </div>

          {/* Game State Operations */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <h3 className="text-lg font-bold text-gray-800 mb-4">Game Operations</h3>
            <div className="space-y-3">
              {game.state === 'upcoming' && (
                <button
                  onClick={startGame}
                  className="w-full py-3 bg-indigo-600 text-white rounded-xl font-bold text-base hover:bg-indigo-700 transition-colors shadow"
                >
                  🚀 Start Game Session
                </button>
              )}

              {game.state === 'live' && (
                <>
                  <div className="text-center py-6 bg-indigo-50 border border-indigo-100 rounded-xl mb-4">
                    <p className="text-xs text-indigo-500 font-bold uppercase tracking-widest">Latest Number Drawn</p>
                    <p className="text-6xl font-black text-indigo-700 mt-2 font-mono">
                      {latestDrawn ? latestDrawn.number.toString().padStart(2, '0') : '--'}
                    </p>
                    <p className="text-xs text-gray-400 mt-2">Drawn position: #{latestDrawn ? latestDrawn.position : 0}</p>
                  </div>

                  <button
                    onClick={drawNextNumber}
                    className="w-full py-4 bg-amber-500 text-white rounded-xl font-black text-lg hover:bg-amber-600 transition-colors shadow-md hover:scale-[1.01] active:scale-[0.99]"
                    disabled={drawnNumbers.length >= 90}
                  >
                    🎲 Draw Next Number
                  </button>

                  <button
                    onClick={endGame}
                    className="w-full py-3 mt-4 bg-gray-100 text-gray-700 rounded-xl font-bold text-sm hover:bg-gray-200 transition-colors border border-gray-200"
                  >
                    🏁 End Game Session
                  </button>
                </>
              )}

              {game.state === 'completed' && (
                <div className="text-center py-4 text-emerald-600 font-bold bg-emerald-50 rounded-xl">
                  Game Completed
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Center column: 1-90 Called Numbers Board */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-bold text-gray-800">Drawn Numbers Board</h3>
              <span className="text-sm font-semibold text-gray-400 bg-gray-50 px-3 py-1 rounded-full border border-gray-100">
                Called: {drawnNumbers.length} / 90
              </span>
            </div>

            <div className="grid grid-cols-10 gap-2.5">
              {Array.from({ length: 90 }, (_, i) => i + 1).map((num) => {
                const drawMatch = drawnNumbers.find((d) => d.number === num);
                const isDrawn = !!drawMatch;

                return (
                  <div
                    key={num}
                    className={`aspect-square rounded-xl border flex flex-col items-center justify-center relative transition-all ${
                      isDrawn
                        ? 'bg-indigo-600 border-indigo-600 text-white shadow-sm font-black'
                        : 'bg-white border-gray-100 text-gray-300 font-bold hover:border-gray-200'
                    }`}
                  >
                    <span className="text-base">{num.toString().padStart(2, '0')}</span>
                    {drawMatch && (
                      <span className="absolute bottom-1 text-[8px] opacity-80 font-mono">
                        #{drawMatch.position}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Bottom section: Live Claims Logger */}
          <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-sm">
            <h3 className="text-lg font-bold text-gray-800 mb-4">Live Claims Feed</h3>
            {claims.length === 0 ? (
              <div className="text-center py-8 text-gray-400 text-sm">
                No claim attempts submitted yet.
              </div>
            ) : (
              <div className="divide-y divide-gray-100 max-h-80 overflow-y-auto pr-2">
                {claims.map((claim) => (
                  <div key={claim.id} className="py-3 flex justify-between items-center gap-4">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-gray-800">{claim.displayName}</span>
                        <span className="text-xs text-gray-400 font-mono">(UID: {claim.userId.substring(0, 5)})</span>
                      </div>
                      <div className="flex items-center gap-3 mt-1">
                        <span className="text-xs font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded">
                          {formatPatternName(claim.pattern)}
                        </span>
                        <span className="text-xs text-gray-400">at roll #{claim.claimedAtPosition}</span>
                        {strikes[claim.userId] !== undefined && claim.status === 'invalid' && (
                          <span className="text-xs font-bold text-red-600 bg-red-50 px-1.5 py-0.5 rounded">
                            Strike: {strikes[claim.userId]}/5
                          </span>
                        )}
                      </div>
                    </div>

                    <div className="text-right">
                      <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
                        claim.status === 'valid' ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'
                      }`}>
                        {claim.status}
                      </span>
                      {claim.status === 'valid' && (
                        <p className="text-xs font-bold text-emerald-600 mt-1">+ ₹{(claim.prizeAmountCents / 100).toFixed(0)}</p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
