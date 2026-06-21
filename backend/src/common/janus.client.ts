/**
 * Janus WebRTC Gateway client.
 * Handles room creation and destruction for the 'videoroom' plugin.
 */

const JANUS_URL = process.env.JANUS_URL || 'http://localhost:8088/janus';
const JANUS_SECRET = process.env.JANUS_SECRET || '';

/**
 * Deterministically maps a UUID string (gameId) into a positive 32-bit integer for Janus.
 * Janus VideoRoom plugin expects numeric IDs for rooms.
 */
export function getJanusRoomId(gameId: string): number {
  let hash = 0;
  for (let i = 0; i < gameId.length; i++) {
    hash = (hash << 5) - hash + gameId.charCodeAt(i);
    hash |= 0; // Convert to 32bit integer
  }
  // Guarantee a positive integer that fits in Janus
  return Math.abs(hash) % 100000000;
}

export const janusClient = {
  /**
   * Request Janus to create a new VideoRoom for this game.
   */
  async createRoom(gameId: string): Promise<number> {
    const roomId = getJanusRoomId(gameId);
    try {
      console.log(`[Janus] Creating videoroom ${roomId} for game ${gameId}`);
      
      // 1. Create Janus session
      const sessionRes = await fetch(JANUS_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'create',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      const sessionData = (await sessionRes.json()) as any;
      if (!sessionData || sessionData.janus !== 'success') {
        throw new Error(`Failed to create session: ${JSON.stringify(sessionData)}`);
      }
      const sessionId = sessionData.data.id;

      // 2. Attach VideoRoom plugin
      const attachRes = await fetch(`${JANUS_URL}/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'attach',
          plugin: 'janus.plugin.videoroom',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      const attachData = (await attachRes.json()) as any;
      if (!attachData || attachData.janus !== 'success') {
        throw new Error(`Failed to attach plugin: ${JSON.stringify(attachData)}`);
      }
      const handleId = attachData.data.id;

      // 3. Send create room request to plugin handle
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
            publishers: 1, // Only 1 publisher (the host)
            is_private: false,
          },
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      const createData = (await createRes.json()) as any;
      console.log(`[Janus] Room ${roomId} creation response:`, JSON.stringify(createData));

      // 4. Cleanup/Destroy Janus Session (rooms persist in the plugin until explicitly destroyed)
      await fetch(`${JANUS_URL}/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'destroy',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      }).catch((e) => console.error('[Janus] Session cleanup error:', e.message));

      return roomId;
    } catch (err: any) {
      console.warn(`[Janus] Offline/Error creating room ${roomId}: ${err.message}. Using fallback roomId.`);
      // Robust fallback: return roomId anyway so development/offline works without a running Janus instance
      return roomId;
    }
  },

  /**
   * Request Janus to destroy the VideoRoom after the game completes.
   */
  async destroyRoom(gameId: string): Promise<void> {
    const roomId = getJanusRoomId(gameId);
    try {
      console.log(`[Janus] Destroying videoroom ${roomId} for game ${gameId}`);

      // 1. Create session
      const sessionRes = await fetch(JANUS_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'create',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      const sessionData = (await sessionRes.json()) as any;
      const sessionId = sessionData.data.id;

      // 2. Attach plugin
      const attachRes = await fetch(`${JANUS_URL}/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'attach',
          plugin: 'janus.plugin.videoroom',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      const attachData = (await attachRes.json()) as any;
      const handleId = attachData.data.id;

      // 3. Destroy room
      await fetch(`${JANUS_URL}/${sessionId}/${handleId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'message',
          transaction: Math.random().toString(36).substring(7),
          body: {
            request: 'destroy',
            room: roomId,
          },
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });

      // 4. Destroy session
      await fetch(`${JANUS_URL}/${sessionId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          janus: 'destroy',
          transaction: Math.random().toString(36).substring(7),
          ...(JANUS_SECRET && { admin_secret: JANUS_SECRET }),
        }),
      });
      console.log(`[Janus] Room ${roomId} successfully destroyed.`);
    } catch (err: any) {
      console.warn(`[Janus] Error destroying room ${roomId}: ${err.message}`);
    }
  }
};
