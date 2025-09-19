import express from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'

export default (User) => {
  const router = express.Router()

  router.post('/signup', async (req, res) => {
    try {
      const { name, email, password, role } = req.body
      if (!email || !password) return res.status(400).json({ error: 'email and password required' })
      const existing = await User.findOne({ email })
      if (existing) return res.status(409).json({ error: 'email already in use' })
      const passwordHash = await bcrypt.hash(password, 10)
      const user = await User.create({ name, email, passwordHash, role })
      const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET || 'dev-secret', {
        expiresIn: '7d',
      })
      res.status(201).json({ token, user: { id: user._id, name: user.name, email: user.email, role: user.role } })
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'internal_error' })
    }
  })

  router.post('/login', async (req, res) => {
    try {
      const { email, password } = req.body
      if (!email || !password) return res.status(400).json({ error: 'email and password required' })
      const user = await User.findOne({ email })
      if (!user) return res.status(401).json({ error: 'invalid_credentials' })
      const ok = await bcrypt.compare(password, user.passwordHash)
      if (!ok) return res.status(401).json({ error: 'invalid_credentials' })
      const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET || 'dev-secret', {
        expiresIn: '7d',
      })
      res.json({ token, user: { id: user._id, name: user.name, email: user.email, role: user.role } })
    } catch (err) {
      console.error(err)
      res.status(500).json({ error: 'internal_error' })
    }
  })

  return router
}


