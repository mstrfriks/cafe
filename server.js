'use strict';

const express = require('express');
const http    = require('http');
const WebSocket = require('ws');
const path    = require('path');

const app    = express();
const server = http.createServer(app);
const wss    = new WebSocket.Server({ server });

app.use(express.static(path.join(__dirname, 'public')));
app.get('/service', (req, res) => res.sendFile(path.join(__dirname, 'public', 'service.html')));

const clients        = new Set();
const serviceClients = new Set();

let config = {
  rooms: ['101', '102', '103', '201', '202', '203', 'Terrasse', 'Bar'],
  drinks: [
    { name: 'Café',          emoji: '☕' },
    { name: 'Thé',           emoji: '🍵' },
    { name: 'Eau',           emoji: '💧' },
    { name: "Jus d'orange",  emoji: '🍊' },
  ],
};

wss.on('connection', (ws) => {
  clients.add(ws);
  ws.send(JSON.stringify({ type: 'config', rooms: config.rooms, drinks: config.drinks }));

  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data); } catch { return; }

    if (msg.type === 'register' && msg.role === 'service') {
      serviceClients.add(ws);
    }

    if (msg.type === 'update_config') {
      if (Array.isArray(msg.rooms))  config.rooms  = msg.rooms;
      if (Array.isArray(msg.drinks)) config.drinks = msg.drinks;
      const payload = JSON.stringify({ type: 'config', rooms: config.rooms, drinks: config.drinks });
      for (const c of clients) {
        if (c.readyState === WebSocket.OPEN) c.send(payload);
      }
    }

    if (msg.type === 'order') {
      const order = {
        type:  'order',
        room:  msg.room  || '',
        items: msg.items || [],
        time:  new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }),
      };
      for (const svc of serviceClients) {
        if (svc.readyState === WebSocket.OPEN) svc.send(JSON.stringify(order));
      }
    }

    if (msg.type === 'done') {
      const ack = { type: 'done', orderId: msg.orderId };
      for (const c of clients) {
        if (c.readyState === WebSocket.OPEN) c.send(JSON.stringify(ack));
      }
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    serviceClients.delete(ws);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Cafe server running at http://localhost:${PORT}`);
  console.log(`  Client : http://localhost:${PORT}/`);
  console.log(`  Service: http://localhost:${PORT}/service`);
});
