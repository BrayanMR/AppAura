const express = require('express');
const router  = express.Router();
const { getAuth } = require('../config/firebase');

// ── Crear usuario ──────────────────────────────────────────────────────────────
// POST /api/auth/register
// Body: { email, password, displayName? }
router.post('/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;
    const user = await getAuth().createUser({ email, password, displayName });
    res.status(201).json({ uid: user.uid, email: user.email, displayName: user.displayName });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ── Obtener usuario por UID ────────────────────────────────────────────────────
// GET /api/auth/user/:uid
router.get('/user/:uid', async (req, res) => {
  try {
    const user = await getAuth().getUser(req.params.uid);
    res.json({ uid: user.uid, email: user.email, displayName: user.displayName, disabled: user.disabled });
  } catch (error) {
    res.status(404).json({ error: error.message });
  }
});

// ── Actualizar usuario ─────────────────────────────────────────────────────────
// PUT /api/auth/user/:uid
// Body: { displayName?, email?, password?, disabled? }
router.put('/user/:uid', async (req, res) => {
  try {
    const updated = await getAuth().updateUser(req.params.uid, req.body);
    res.json({ uid: updated.uid, email: updated.email, displayName: updated.displayName });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ── Eliminar usuario ───────────────────────────────────────────────────────────
// DELETE /api/auth/user/:uid
router.delete('/user/:uid', async (req, res) => {
  try {
    await getAuth().deleteUser(req.params.uid);
    res.json({ message: `Usuario ${req.params.uid} eliminado` });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ── Verificar ID Token ─────────────────────────────────────────────────────────
// POST /api/auth/verify-token
// Body: { idToken }
router.post('/verify-token', async (req, res) => {
  try {
    const { idToken } = req.body;
    const decoded = await getAuth().verifyIdToken(idToken);
    res.json({ uid: decoded.uid, email: decoded.email });
  } catch (error) {
    res.status(401).json({ error: 'Token inválido o expirado' });
  }
});

// ── Crear Custom Token ─────────────────────────────────────────────────────────
// POST /api/auth/custom-token
// Body: { uid, claims? }
router.post('/custom-token', async (req, res) => {
  try {
    const { uid, claims } = req.body;
    const token = await getAuth().createCustomToken(uid, claims);
    res.json({ customToken: token });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
