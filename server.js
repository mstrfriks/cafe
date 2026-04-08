'use strict';

const express = require('express');
const http    = require('http');
const WebSocket = require('ws');
const path    = require('path');

const app    = express();
const server = http.createServer(app);
const wss    = new WebSocket.Server({ server });

app.use(express.static(path.join(__dirname, 'public')));

// Keep-alive : empêche Render free tier de s'endormir
const RENDER_URL = process.env.RENDER_EXTERNAL_URL || '';
if (RENDER_URL) {
  setInterval(() => { fetch(RENDER_URL).catch(() => {}); }, 10 * 60 * 1000);
}

const orders  = [];
let   nextId  = 1;
const sockets = new Set();

// ── ntfy push notification ────────────────────────────────────────────────────
// Set NTFY_TOPIC env var on Render.com (e.g. "cafe-maison-abc123")
const NTFY_TOPIC = process.env.NTFY_TOPIC || '';

function notifyService(order) {
  if (!NTFY_TOPIC) return;
  fetch(`https://ntfy.sh/${NTFY_TOPIC}`, {
    method:  'POST',
    headers: {
      'Title':    `☕ ${order.name}`,
      'Priority': 'high',
      'Tags':     'coffee',
    },
    body: order.drink,
  }).catch(() => {}); // silent — don't crash server if ntfy is unreachable
}

wss.on('connection', (ws) => {
  ws.role = null;
  sockets.add(ws);

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    // ── register ──────────────────────────────────────────────────────────────
    if (msg.type === 'register') {
      ws.role = msg.role;
      if (msg.role === 'service') {
        // Send current pending orders so the dashboard is accurate after reload
        send(ws, { type: 'orders', orders: orders.filter(o => o.status === 'pending') });
      }
      return;
    }

    // ── new order ─────────────────────────────────────────────────────────────
    if (msg.type === 'order') {
      const name  = String(msg.name  || '').trim().slice(0, 50);
      const drink = String(msg.drink || '').trim().slice(0, 50);
      if (!name || !drink) return;

      const order = { id: nextId++, name, drink, at: Date.now(), status: 'pending' };
      orders.push(order);
      // Keep memory bounded
      if (orders.length > 500) orders.splice(0, orders.length - 500);

      broadcast('service', { type: 'new_order', order });
      send(ws, { type: 'order_confirmed', orderId: order.id });
      notifyService(order);
      return;
    }

    // ── mark ready ────────────────────────────────────────────────────────────
    if (msg.type === 'ready') {
      const order = orders.find(o => o.id === msg.orderId && o.status === 'pending');
      if (!order) return;
      order.status = 'done';
      broadcast('client',  { type: 'order_ready',   orderId: order.id });
      broadcast('service', { type: 'order_removed', orderId: order.id });
    }
  });

  ws.on('close', () => sockets.delete(ws));
  ws.on('error', () => sockets.delete(ws));
});

function send(ws, msg) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
}

function broadcast(role, msg) {
  const data = JSON.stringify(msg);
  for (const ws of sockets) {
    if (ws.readyState === WebSocket.OPEN && ws.role === role) ws.send(data);
  }
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Café server → http://localhost:${PORT}`));
