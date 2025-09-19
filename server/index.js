import 'dotenv/config'
import express from 'express'
import mongoose from 'mongoose'
import cors from 'cors'
import createAuthRouter from './routes/auth.js'

const app = express()
app.use(cors())
app.use(express.json())

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/metro_docs_hub'
const PORT = process.env.PORT || 5175

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('MongoDB connected')
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err.message)
    process.exit(1)
  })

// Models
const userSchema = new mongoose.Schema(
  {
    name: { type: String },
    email: { type: String, unique: true, required: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ['admin', 'employee'], default: 'employee' },
  },
  { timestamps: true }
)
const User = mongoose.model('User', userSchema)

// Routes
app.get('/health', (_req, res) => res.json({ ok: true }))

const authRouter = createAuthRouter(User)
app.use('/auth', authRouter)

app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}`)
})


