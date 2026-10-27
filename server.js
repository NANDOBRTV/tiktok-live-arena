const express = require("express");
const http = require("http");
const path = require("path");
const WebSocket = require("ws");

const app = express();
const server = http.createServer(app);
const clients = new WebSocket.Server({ server, path: "/live-events" });
const PORT = Number(process.env.PORT || 3000);
const API_BASE = "https://api.tik.tools";
const WS_BASE = "wss://api.tik.tools/";

let upstream = null;
let activeUsername = "";
let status = "disconnected";
let lastError = null;
let reconnectTimer = null;
let intentionalClose = false;
let attempt = 0;

app.use(express.static(path.join(__dirname, "public")));
app.get("/health", (_req, res) => {
  res.status(200).json({
    ok: true,
    service: "tiktok-live-arena",
    provider: "Tik.Tools",
    status,
    connected: status === "connected",
    username: activeUsername || null,
    configured: Boolean(process.env.TIKTOOLS_API_KEY),
    lastError
  });
});
app.get("/api/tiktok/status", (_req, res) => {
  res.status(200).json({
    provider: "Tik.Tools",
    status,
    connected: status === "connected",
    username: activeUsername || null,
    configured: Boolean(process.env.TIKTOOLS_API_KEY),
    lastError
  });
});

function cleanText(value, max = 300) {
  return String(value ?? "").replace(/[<>]/g, "").slice(0, max);
}
function broadcast(payload) {
  const raw = JSON.stringify({ at: Date.now(), ...payload });
  for (const client of clients.clients) {
    if (client.readyState === WebSocket.OPEN) client.send(raw);
  }
}
function setStatus(next, message, error = null) {
  status = next;
  lastError = error ? cleanText(error, 240) : null;
  broadcast({ type: "status", status: next, message: cleanText(message || next, 240), error: lastError });
}
function clearReconnect() {
  if (reconnectTimer) clearTimeout(reconnectTimer);
  reconnectTimer = null;
}
function stopUpstream() {
  intentionalClose = true;
  clearReconnect();
  if (upstream) {
    const old = upstream;
    upstream = null;
    try { old.close(1000, "Client requested disconnect"); } catch (_) {}
  }
  activeUsername = "";
  attempt = 0;
  setStatus("disconnected", "Conexão Tik.Tools encerrada.");
}
function scheduleReconnect() {
  if (intentionalClose || !activeUsername || !process.env.TIKTOOLS_API_KEY || reconnectTimer) return;
  const delay = Math.min(30000, 2000 * Math.pow(2, Math.min(attempt, 4)));
  attempt += 1;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectLive(activeUsername, true);
  }, delay);
}
function normalizeUser(data) {
  const user = data.user || data.author || {};
  return cleanText(user.uniqueId || user.unique_id || data.user_unique_id || user.nickname || "espectador", 60);
}
function forwardEvent(message) {
  const event = String(message.event || message.type || "").toLowerCase();
  const data = message.data || message;
  const username = normalizeUser(data);
  if (event === "roominfo" || event === "room_info" || event === "heartbeat" || event === "pong") return;

  if (event === "chat" || event === "comment") {
    broadcast({ type: "chat", username, comment: cleanText(data.comment || data.text || "", 200) });
  } else if (event === "gift") {
    const gift = data.gift || data;
    broadcast({
      type: "gift", username,
      giftName: cleanText(gift.giftName || gift.gift_name || gift.name || "presente", 80),
      repeatCount: Number(gift.repeatCount || gift.repeat_count || 1),
      diamondCount: Number(gift.diamondCount || gift.diamond_count || gift.diamonds || 0),
      giftId: gift.giftId || gift.gift_id || null
    });
  } else if (event === "like" || event === "likes") {
    broadcast({
      type: "like", username,
      likeCount: Number(data.likeCount || data.like_count || data.count || 1),
      totalLikeCount: Number(data.totalLikeCount || data.total_like_count || 0)
    });
  } else if (event === "member" || event === "join" || event === "entrance") {
    broadcast({ type: "member", username });
  } else if (event === "follow" || event === "social") {
    broadcast({ type: "member", username, action: "follow" });
  } else if (event === "share") {
    broadcast({ type: "share", username });
  } else {
    broadcast({ type: "liveEvent", event: cleanText(event || "unknown", 60), username, data });
  }
}
async function connectLive(username, isReconnect = false) {
  const normalized = String(username || "").trim().replace(/^@/, "");
  if (!/^[a-zA-Z0-9._]{2,24}$/.test(normalized)) {
    setStatus("error", "Digite um @usuário válido do TikTok (sem senha).", "invalid_username");
    return;
  }
  const apiKey = process.env.TIKTOOLS_API_KEY;
  if (!apiKey) {
    activeUsername = normalized;
    setStatus("error", "Falta configurar TIKTOOLS_API_KEY nas variáveis de ambiente do Render.", "missing_api_key");
    return;
  }
  intentionalClose = false;
  clearReconnect();
  if (upstream) {
    const old = upstream;
    upstream = null;
    try { old.close(1000, "Switching creator"); } catch (_) {}
  }
  activeUsername = normalized;
  setStatus("connecting", (isReconnect ? "Reconectando" : "Conectando") + " ao Tik.Tools para @" + normalized + "…");
  try {
    const url = new URL(WS_BASE);
    url.searchParams.set("uniqueId", normalized);
    url.searchParams.set("apiKey", apiKey);
    const ws = new WebSocket(url.toString());
    upstream = ws;
    ws.on("open", () => {
      if (upstream !== ws) return;
      attempt = 0;
      setStatus("connected", "WebSocket Tik.Tools conectado para @" + normalized + ".");
    });
    ws.on("message", raw => {
      if (upstream !== ws) return;
      try {
        const message = JSON.parse(raw.toString());
        if (message.event === "roomInfo") {
          broadcast({ type: "roomInfo", username: normalized, roomId: message.roomId || null });
          return;
        }
        forwardEvent(message);
      } catch (_) {
        broadcast({ type: "status", status, message: "Mensagem recebida do Tik.Tools não estava em JSON válido." });
      }
    });
    ws.on("error", error => {
      if (upstream !== ws) return;
      setStatus("error", "Erro no WebSocket Tik.Tools.", error && error.message);
    });
    ws.on("close", (code, reason) => {
      if (upstream !== ws) return;
      upstream = null;
      const why = cleanText(reason.toString() || ("código " + code), 180);
      setStatus("disconnected", "WebSocket Tik.Tools fechado (" + why + ").", "ws_close_" + code);
      scheduleReconnect();
    });
  } catch (error) {
    upstream = null;
    setStatus("error", "Não foi possível iniciar o WebSocket Tik.Tools.", error && error.message);
    scheduleReconnect();
  }
}
clients.on("connection", socket => {
  socket.send(JSON.stringify({
    type: "status", status,
    message: status === "connected" ? "Conectado a @" + activeUsername : "Servidor pronto. Configure TIKTOOLS_API_KEY e conecte uma LIVE ativa."
  }));
  socket.on("message", raw => {
    let message;
    try { message = JSON.parse(raw.toString()); } catch (_) { return; }
    if (message.action === "connect") connectLive(message.username);
    if (message.action === "disconnect") stopUpstream();
  });
});
server.listen(PORT, "0.0.0.0", () => {
  console.log("TikTok LIVE Arena listening on " + PORT);
  if (process.env.TIKTOOLS_API_KEY && process.env.TIKTOK_USERNAME) {
    connectLive(process.env.TIKTOK_USERNAME);
  } else if (!process.env.TIKTOOLS_API_KEY) {
    console.log("TIKTOOLS_API_KEY is not configured; Tik.Tools connection is disabled.");
  }
});
