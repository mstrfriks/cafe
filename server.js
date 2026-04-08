'use strict';

const express = require('express');
const http    = require('http');
const WebSocket = require('ws');
const path    = require('path');

const app    = express();
const server = http.createServer(app);
const wss    = new WebSocket.Server({ server });

app.use(express.static(path.join(__dirname, 'public')));
app.get('/service', (req, res) => res.sendFile(path.join(__dirname, 'service.html')));

const RENDER_URL = process.env.RENDER_EXTERNAL_URL || '';
if (RENDER_URL) {
  setInterval(() => { fetch(RENDER_URL).catch(() => {}); }, 10 * 60 * 1000);
}

const orders  = [];
let   nextId  = 1;
const sockets = new Set();
let   sharedConfig = null; // pushed by service, forwarded to clients

const NTFY_TOPIC = process.env.NTFY_TOPIC || '';
const APP_URL    = process.env.RENDER_EXTERNAL_URL || '';
console.log('NTFY_TOPIC at startup:', NTFY_TOPIC || '(not set)');

function notifyService(order) {
  console.log('notifyService called, NTFY_TOPIC:', NTFY_TOPIC || '(not set)');
  if (!NTFY_TOPIC) return;
  fetch(`https://ntfy.sh/${NTFY_TOPIC}`, {
    method:  'POST',
    headers: {
      'Title':    `Cafe - ${order.name}`,
      'Priority': 'high',
      'Tags':     'coffee',
      'Actions':  `view, Ouvrir le dashboard, ${APP_URL}/service`,
    },
    body: order.drink,
  })
  .then(r => console.log('ntfy response:', r.status))
  .catch(e => console.error('ntfy error:', e.message));
}

wss.on('connection', (ws) => {
  ws.role = null;
  sockets.add(ws);

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.type === 'register') {
      ws.role = msg.role;
      if (msg.role === 'service') {
        send(ws, { type: 'orders', orders: orders.filter(o => o.status === 'pending') });
      }
      if (msg.role === 'client' && sharedConfig) {
        send(ws, { type: 'config', config: sharedConfig });
      }
      return;
    }

    if (msg.type === 'update_config') {
      if (ws.role !== 'service') return;
      sharedConfig = msg.config;
      broadcast('client', { type: 'config', config: sharedConfig });
      return;
    }

    if (msg.type === 'order') {
      const name  = String(msg.name  || '').trim().slice(0, 50);
      const drink = String(msg.drink || '').trim().slice(0, 200);
      if (!name || !drink) return;

      const order = { id: nextId++, name, drink, at: Date.now(), status: 'pending' };
      orders.push(order);
      if (orders.length > 500) orders.splice(0, orders.length - 500);

      broadcast('service', { type: 'new_order', order });
      send(ws, { type: 'order_confirmed', orderId: order.id });
      notifyService(order);
      return;
    }

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
