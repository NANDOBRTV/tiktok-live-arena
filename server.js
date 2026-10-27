const express = require("express");
const http = require("http");
const path = require("path");
const { WebSocketServer, WebSocket } = require("ws");
const { TikTokLiveConnection, WebcastEvent, ControlEvent } = require("tiktok-live-connector");

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/live-events" });
const PORT = Number(process.env.PORT || 3000);
let liveConnection = null;
let activeUsername = "";
let connecting = false;

app.use(express.static(path.join(__dirname, "public")));
app.get("/health", (_req, res) => res.json({ ok: true, service: "tiktok-live-arena", connected: Boolean(liveConnection), username: activeUsername || null }));

function broadcast(payload) {
  const data = JSON.stringify(payload);
  for (const client of wss.clients) {
    if (client.readyState === WebSocket.OPEN) client.send(data);
  }
}
function cleanText(value, max = 300) {
  return String(value ?? "").replace(/[<>]/g, "").slice(0, max);
}
function emit(type, data = {}) {
  broadcast({ type, at: Date.now(), ...data });
}
async function disconnectLive() {
  if (!liveConnection) return;
  try { await liveConnection.disconnect(); } catch (_) {}
  liveConnection = null;
  activeUsername = "";
  connecting = false;
  emit("status", { status: "disconnected", message: "Conexão encerrada." });
}
async function connectLive(username) {
  const normalized = String(username || "").trim().replace(/^@/, "");
  if (!/^[a-zA-Z0-9._]{2,24}$/.test(normalized)) {
    emit("status", { status: "error", message: "Digite um @usuário válido do TikTok (sem senha)." });
    return;
  }
  if (connecting) {
    emit("status", { status: "connecting", message: "Já estamos tentando conectar." });
    return;
  }
  await disconnectLive();
  connecting = true;
  activeUsername = normalized;
  emit("status", { status: "connecting", message: "Conectando ao LIVE de @" + normalized + "…" });
  try {
    const connection = new TikTokLiveConnection(normalized, { enableExtendedGiftInfo: true });
    liveConnection = connection;
    connection.on(WebcastEvent.CHAT, data => emit("chat", {
      username: cleanText(data.uniqueId || data.nickname || "espectador", 60),
      comment: cleanText(data.comment || "", 200)
    }));
    connection.on(WebcastEvent.GIFT, data => emit("gift", {
      username: cleanText(data.uniqueId || data.nickname || "espectador", 60),
      giftName: cleanText(data.giftName || "presente", 80),
      repeatCount: Number(data.repeatCount || 1),
      diamondCount: Number(data.diamondCount || 0),
      giftId: data.giftId || null
    }));
    connection.on(WebcastEvent.LIKE, data => emit("like", {
      username: cleanText(data.uniqueId || data.nickname || "espectador", 60),
      likeCount: Number(data.likeCount || 1),
      totalLikeCount: Number(data.totalLikeCount || 0)
    }));
    connection.on(WebcastEvent.MEMBER, data => emit("member", {
      username: cleanText(data.uniqueId || data.nickname || "espectador", 60)
    }));
    connection.on(ControlEvent.ERROR, error => {
      emit("status", { status: "error", message: cleanText(error?.message || "Erro na conexão TikTok.", 200) });
    });
    connection.on(ControlEvent.DISCONNECTED, () => {
      liveConnection = null;
      connecting = false;
      emit("status", { status: "disconnected", message: "O conector foi desconectado do LIVE." });
    });
    await connection.connect();
    connecting = false;
    emit("status", { status: "connected", message: "Conectado ao LIVE de @" + normalized + "." });
  } catch (error) {
    liveConnection = null;
    connecting = false;
    emit("status", { status: "error", message: cleanText(error?.message || "Não foi possível conectar. Verifique se a LIVE está ativa.", 240) });
  }
}
wss.on("connection", socket => {
  socket.send(JSON.stringify({ type: "status", status: liveConnection ? "connected" : "disconnected", message: liveConnection ? "Conectado a @" + activeUsername : "Servidor pronto. Conecte uma LIVE ativa." }));
  socket.on("message", raw => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch (_) { return; }
    if (msg.action === "connect") connectLive(msg.username);
    if (msg.action === "disconnect") disconnectLive();
  });
});
server.listen(PORT, "0.0.0.0", () => console.log("TikTok LIVE Arena listening on " + PORT));
